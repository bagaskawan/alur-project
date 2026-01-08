from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage, ToolMessage
from app.core.config import settings
from app.features.chat.tools import get_user_schedule, update_task_schedule, create_new_task
from app.models.all_models import Profile, ChatMessage, SenderType, Goal, ItemStatus
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession
import uuid
import json
import copy  # Import copy for safe JSON update

# Setup Model & Tools
llm = ChatGroq(
    temperature=0.3,
    model_name=settings.GROQ_MODEL,
    api_key=settings.GROQ_API_KEY
)

# Bind Tools to LLM
tools = [get_user_schedule, update_task_schedule, create_new_task]
tool_map = {t.name: t for t in tools}
llm_with_tools = llm.bind_tools(tools)


def get_system_prompt(mode: str, user_name: str, persona_data: dict, current_stage: str = None, language: str = "id", message: str = "") -> str:
    """
    Returns the appropriate system prompt based on the chat mode.
    Language: 'id' = Indonesian, 'en' = English
    """
    if mode == "ONBOARDING":
        # Bilingual knowledge base - questions are descriptive, no option listing
        knowledge_base = {
            "energy_profile": {
                "options": ["MORNING_LARK", "NIGHT_OWL", "FLEXIBLE"],
                "definitions": """
                - MORNING_LARK: Prefers morning, early riser, productive before noon.
                - NIGHT_OWL: Prefers night, late worker, productive after sunset.
                - FLEXIBLE: No strong preference, can work anytime, adaptable.
                """,
                "next_question": {
                    "id": "Nah, sekarang soal motivasi. Setiap orang punya 'bahan bakar' yang berbeda buat produktif. Ada yang butuh target jelas, ada yang suka dikasih reward, ada yang semangat kalau kerja bareng tim, atau ada yang suka ngerasa berkembang. Kamu yang mana?",
                    "en": "Now about motivation. Everyone has different 'fuel' to stay productive. Some need clear targets, others love rewards, some thrive in teams, and some are driven by personal growth. Which one resonates with you?"
                }
            },
            "motivation_drivers": {
                "options": ["GOAL_ORIENTED", "REWARD_DRIVEN", "SOCIAL_DRIVEN", "GROWTH_FOCUSED"],
                "definitions": """
                - GOAL_ORIENTED: Motivated by targets, achievements, completing objectives.
                - REWARD_DRIVEN: Motivated by incentives, bonuses, recognition, money.
                - SOCIAL_DRIVEN: Motivated by teamwork, friends, social validation.
                - GROWTH_FOCUSED: Motivated by learning, self-improvement, skill development.
                """,
                "next_question": {
                    "id": "Sip! Kalau lagi ngadepin masalah atau tantangan berat, kamu biasanya gimana? Langsung gas, mikir strategi dulu, cari bantuan, atau ngikutin arus aja?",
                    "en": "Got it! When facing tough challenges or problems, what's your usual approach? Do you dive right in, strategize first, seek help, or go with the flow?"
                }
            },
            "challenge_response": {
                "options": ["FIGHTER", "STRATEGIC", "COLLABORATOR", "ADAPTIVE"],
                "definitions": """
                - FIGHTER: Attacks problems head-on, direct action, doesn't back down.
                - STRATEGIC: Plans carefully, thinks before acting, analyzes options.
                - COLLABORATOR: Seeks help, teamwork, prefers group problem-solving.
                - ADAPTIVE: Goes with the flow, adjusts approach based on situation.
                """,
                "next_question": {
                    "id": "Oke, sekarang soal cara belajar. Waktu kamu mau paham sesuatu yang baru, lebih gampang lewat mana? Nonton video, dengerin penjelasan, langsung praktek, atau baca-baca sendiri?",
                    "en": "Alright, now about learning style. When you want to understand something new, what works best for you? Watching videos, listening to explanations, hands-on practice, or reading on your own?"
                }
            },
            "learning_style": {
                "options": ["VISUAL", "AUDITORY", "KINESTHETIC", "READING_WRITING"],
                "definitions": """
                - VISUAL: Learns through images, diagrams, videos, charts, watching.
                - AUDITORY: Learns through listening, podcasts, discussions, verbal explanation.
                - KINESTHETIC: Learns through doing, practice, hands-on experience, movement, simulation.
                - READING_WRITING: Learns through reading books, articles, taking notes, writing.
                """,
                "next_question": {
                    "id": "Terakhir nih! Setelah seharian aktivitas, kamu biasanya recharge energi gimana? Lebih nyaman sendirian, atau justru butuh ketemu orang-orang?",
                    "en": "Last one! After a long day, how do you usually recharge? Do you prefer being alone, or do you need to be around people?"
                }
            },
            "behavior_type": {
                "options": ["INTROVERT", "EXTROVERT", "AMBIVERT"],
                "definitions": """
                - INTROVERT: Prefers solitude, quiet environments, drained by crowds.
                - EXTROVERT: Prefers crowds, social settings, energized by people.
                - AMBIVERT: Mix of both, depends on mood or situation.
                """,
                "next_question": {
                    "id": "Mantap! Kamu sudah siap. Tap 'Mulai' untuk memulai perjalanan produktivitasmu!",
                    "en": "Perfect! You're all set. Tap 'Get Started' to begin your productivity journey!"
                }
            },
        }
        
        stage_info = knowledge_base.get(current_stage, {})
        options_list = stage_info.get("options", [])
        definitions = stage_info.get("definitions", "")
        next_q_dict = stage_info.get("next_question", {})
        next_q = next_q_dict.get(language, next_q_dict.get("id", ""))
        example_option = options_list[0] if options_list else "EXAMPLE"
        
        lang_instruction = "Indonesian (Bahasa Indonesia)" if language == "id" else "English"
        
        return f"""You are a STRICT Onboarding Validator for the ALUR productivity app.

        CURRENT STAGE: '{current_stage}'
        VALID OPTIONS: {options_list}

        OPTION DEFINITIONS (use for semantic matching):
        {definitions}

        YOUR TASK:
        1. Analyze user's message and determine if it semantically matches any valid option(s).
        2. If user says "all", "everything", "both", "semuanya" -> extract ALL relevant options.
        3. If user's answer is semantically close to an option (e.g., "hands-on practice" = KINESTHETIC), mark as VALID.

        OUTPUT FORMAT (JSON ONLY, NO MARKDOWN, NO EXTRA TEXT):
        {{"is_valid_answer": true, "extracted_data": ["{example_option}"], "reply": "Great! Next question..."}}

        REPLY RULES:
        1. If VALID: Short praise (max 5 words) + NEWLINE + ask the next question: "{next_q}"
        2. If INVALID: Do NOT repeat the full option list. Just ask clarifying question.
        3. NEVER write raw codes like "VISUAL", "MORNING_LARK" in the reply. Use human language.
        4. ALWAYS respond in {lang_instruction}.

        CRITICAL:
        - Output ONLY valid JSON. No markdown blocks (```). No explanatory text before/after.
        """

    elif mode == "GOALS_SETUP":
        return f"""You are ALUR, acting as a Strategic Goal Consultant for {user_name}.
        User Profile: {persona_data}
        
        YOUR ROLE:
        - Help the user refine their goal and discuss strategy.
        - Be conversational, supportive, and intelligent.
        
        CRITICAL RULES:
        1. DETECT INTENT:
           - If user agrees to your proposal (e.g., "setuju", "boleh", "sikat", "gas", "ok"), set intent="AGREEMENT".
           - If user asks questions or provides new info, set intent="DISCUSSION".
        2. OUTPUT JSON ONLY:
           - You MUST return a JSON object. No raw text.
        
        OUTPUT FORMAT (JSON ONLY):
        {{
            "intent": "AGREEMENT" or "DISCUSSION",
            "reply": "Your conversational response here.",
            "options": ["Option 1", "Option 2"]
        }}

        [Agreed/AGREEMENT Scenario]
        - Respond with a SHORT bridging message (1-2 sentences).
        - Example: "Bagus! Blueprint strategimu sudah siap. Klik tombol di bawah untuk melihat rencana detailnya 🎯"
        - Options: ["Lihat Blueprint"] or []
        
        [Discussion/DISCUSSION Scenario]
        - Provide helpful advice or answer questions.
        - Be concise.
        - Options: Provide 2-3 short relevant follow-up options. Example: ["Setuju", "Ganti Strategi", "Tanya lagi"]
        """
    elif mode == "GOAL_ENHANCE":
        return f"""You are a SMART Goal Specialist (Specific, Measurable, Achievable, Relevant, Time-bound).
        
        YOUR TASK:
        Refine the user's input into a realistic, high-quality goal statement.
        
        CRITICAL REALITY CHECK:
        - If the goal is a CAREER CHANGE (e.g., "Become AI Engineer", "Doctor", "Senior Dev"), the timeline MUST be realistic (6 months - 2 years), not weeks.
        - If the goal is a HABIT (e.g., "Read books"), focus on frequency (daily/weekly).
        
        OUTPUT RULES:
        1. Return ONLY the rewritten sentence. No intro/outro.
        2. Detect the user's language (Indonesian/English) and output in the SAME language.
        
        Example Input: "Pengen jadi AI Engineer"
        Example Output: "Bekerja sebagai Junior AI Engineer dalam 12 bulan dengan menguasai Python, Machine Learning, dan membangun 3 portofolio proyek."
        
        Example Input: "Lose weight"
        Example Output: "Mencapai berat badan ideal 65kg dalam 4 bulan melalui olahraga rutin 3x seminggu dan defisit kalori."
        """


    # [BARU] 1. THE RELATIONSHIP DETECTOR (Cek Hubungan)
    elif mode == "GOAL_RELATIONSHIP_CHECK":
        # Kita butuh data goal lama user (North Star)
        existing_goals_summary = persona_data.get('active_goals_summary', 'No active goals')
        
        return f"""You are the 'Goal Integration Engine'.
        
        CONTEXT:
        The user has an existing North Star Goal: "{existing_goals_summary}".
        The user just input a NEW desire: "{current_stage}" (Using 'current_stage' to pass the Enhanced Goal).
        
        YOUR TASK:
        Analyze if this NEW desire is actually a SUB-SKILL or PILLAR of the Existing Goal, or completely unrelated.
        
        LOGIC EXAMPLES:
        - Existing: "Become AI Engineer". Input: "Learn English". 
          -> Result: RELATED (English is needed for reading AI papers). Suggestion: MERGE as Habit/Pillar.
        - Existing: "Lose 10kg". Input: "Learn Guitar".
          -> Result: UNRELATED. Suggestion: CREATE NEW GOAL.
        
        CRITICAL LANGUAGE RULE:
        - Detect the language of the NEW desire input.
        - ALL text fields ("reasoning", "merge_strategy") MUST be in the SAME LANGUAGE as the user input.
        - Exception: Technical terms can remain in English.

        OUTPUT JSON ONLY:
        {{
            "is_related": true/false,
            "relationship_score": 0-100,
            "reasoning": "Explanation in user's language",
            "recommendation": "MERGE" or "NEW",
            "merge_strategy": "If MERGE, explain how in user's language"
        }}
        """

    # [BARU] 2. STRATEGY ADVISOR (Pemilih Metode Dinamis)
    elif mode == "STRATEGY_ADVISOR":
        return f"""You are the Chief Strategy Officer for the ALUR app.
        
        USER CONTEXT:
        - Input Goal: "{message}"
        - User Constraints: Check if the user mentioned available hours/day in the message OR "current_stage" param.
        
        YOUR MISSION:
        Be a "Realistic Partner". Do not just say yes. Audit the goal. Do NOT blindly generate a plan. First, AUDIT the goal's feasibility based on the user's time constraint.
        
        LOGIC PROCESS (Execute Internally):
        1. CHECK TIME DATA: 
           - Is there a clear time commitment (e.g., "2 hours/day", "15 mins", "full time")?
           - IF NO TIME DATA -> Result: "ASK_TIME".
        
        2. IF TIME DATA EXISTS -> AUDIT FEASIBILITY:
           - Cost = Estimated hours needed for goal.
           - Budget = Available hours * Days.
           - IF (Cost > Budget * 1.5) -> Result: "NEGOTIATE" (Impossible/Burnout Risk).
           - IF (Cost <= Budget * 1.5) -> Result: "PROCEED" (Realistic/Tight).

        OUTPUT FORMAT (JSON ONLY):
        
        [SCENARIO A: NO TIME DATA]
        {{
            "action": "ASK_TIME",
            "reply": "Wah target menarik! Tapi biar strateginya pas, kamu bisa luangkan waktu berapa jam sehari buat ini?",
            "options": ["1 Jam", "2 Jam", "Full Time"]
        }}

        [SCENARIO B: IMPOSSIBLE / NEGOTIATION]
        {{
            "action": "NEGOTIATE",
            "reply": "Waduh, kalau cuma [User Time] kayaknya berat buat capai [Goal] dalam waktu segitu (Butuh ~[Cost] jam). \\n\\nGimana kalau kita scalling-down dulu: Fokus ke **[Scope Down Goal]**? Setuju?",
            "recommendation": {{
                "strategy_name": "Foundation Phase",
                "final_goal_title": "[Scope Down Goal]",
                "duration_text": "[Realistic Duration]"
            }},
            "options": ["Setuju (Scope Down)", "Tetap Paksakan", "Batal"]
        }}

        [SCENARIO C: REALISTIC / PROCEED]
        {{
            "action": "PROCEED",
            "reply": "Oke, masuk akal. Dengan [User Time], kita bisa pakai metode **[Method Name]** selama [Duration]. Siap lihat blueprint?",
            "recommendation": {{
                "strategy_name": "[Method Name]",
                "final_goal_title": "[Goal]",
                "duration_text": "[Duration]",
                "reasoning": "Strategy reasoning..."
            }},
            "options": ["Siap!", "Tanya Metode Lain"]
        }}

        CRITICAL:
        - Detect Language: Respond in the SAME language as User.
        - Tone: Conversational, empathetic but realistic.
        - "reply" field MUST be a string meant for a Chat Bubble.
        - "options" field MUST be a list of short strings (Max 3 words each).
        """

    # [BARU] 3. BLUEPRINT GENERATOR (Generate Detailed Phases)
    elif mode == "BLUEPRINT_GENERATOR":
        return f"""You are a Master Project Planner.
        
        USER GOAL: "{message}"
        TIME HORIZON: "{current_stage}" (e.g., "6 Bulan", "3 Months")
        
        YOUR TASK:
        Generate a DETAILED breakdown of the goal into monthly phases.
        
        CRITICAL INSTRUCTION FOR TITLE:
        - "goal_title" MUST be a very short summary (MAX 3 WORDS).
        - Example: "Menjadi AI Engineer", "Turun Berat Badan", "Buka Bisnis Kopi".
        - DO NOT put the full goal description in the title.
        
        CRITICAL LANGUAGE RULE:
        - Detect the language of the USER GOAL.
        - ALL text MUST be in the SAME LANGUAGE as the user input.
        - Exception: Technical terms can remain in English.
        
        OUTPUT JSON ONLY (No Markdown, No Explanations):
        {{
            "action": "SHOW_BLUEPRINT",
            "goal_title": "SHORT 2-3 WORDS SUMMARY",
            "time_horizon": "6 Bulan",
            "blueprint_data": [
                {{
                    "phase_name": "Bulan 1",
                    "focus": "Fundamental Python & Math",
                    "tasks": [
                        {{"title": "Selesaikan Course Python Basic", "duration": "10 jam"}},
                        {{"title": "Paham Aljabar Linear", "duration": "5 jam"}}
                    ]
                }},
                {{
                    "phase_name": "Bulan 2",
                    "focus": "Machine Learning Basics",
                    "tasks": [
                        {{"title": "Pelajari Scikit-Learn", "duration": "8 jam"}},
                        {{"title": "Buat 2 Mini Projects", "duration": "6 jam"}}
                    ]
                }}
                // Continue for all phases based on time_horizon
            ]
        }}
        """

    else:  # DAILY (Default)
        return f"""You are ALUR, a personal productivity assistant for {user_name}.
        User Profile: {persona_data}
        Tone: Relaxed, supportive, but firm regarding data accuracy.
        Capabilities: Check schedule (get_user_schedule), Reschedule (update_task_schedule), Create (create_new_task).
        Rules: ALWAYS use tools for data. Do not hallucinate. Respond in User's Language.
        """


# FIX 3: Accept `session` as argument (Dependency Injection)
async def process_chat(session: AsyncSession, user_id: str, message: str, mode: str = "DAILY", current_stage: str = None):
    """
    Main Logic. 
    Accepts 'session' from API Endpoint to reuse connection.
    """
    
    # A. Fetch Profile
    try:
        uuid_user_id = uuid.UUID(user_id)
    except ValueError:
        # FIX 1: Return dict consistently
        return {"reply": "Error: Invalid User ID format.", "is_valid_answer": False}

    profile = await session.get(Profile, uuid_user_id)
    user_name = profile.full_name if profile else "Friend"
    persona_data = profile.personalization_data if profile else {}
    user_language = profile.preferred_language if profile else "id"  # Default Indonesian
    
    # [GATEKEEPER LOGIC] Fetch Active Goals if Relationship Check
    if mode == "GOAL_RELATIONSHIP_CHECK":
        try:
            # Try to fetch active goals - wrapped in try-catch for database compatibility
            active_goals_stmt = select(Goal).where(Goal.user_id == uuid_user_id, Goal.status == "IN_PROGRESS")
            goals_result = await session.exec(active_goals_stmt)
            active_goals = goals_result.all()
            
            active_goals_text = "No active goals"
            if active_goals:
                active_goals_text = ", ".join([g.title for g in active_goals])
            
            # Inject into persona_data for the prompt
            persona_data['active_goals_summary'] = active_goals_text
        except Exception as goal_fetch_error:
            print(f"⚠️ Could not fetch goals (DB type mismatch?): {goal_fetch_error}")
            persona_data['active_goals_summary'] = "No active goals"

    
    # B. Fetch History
    history_stmt = select(ChatMessage).where(ChatMessage.user_id == uuid_user_id).order_by(ChatMessage.created_at.desc()).limit(5)
    history_result = await session.exec(history_stmt)
    db_history = history_result.all()
    
    chat_history = []
    for msg in reversed(db_history):
        if msg.sender == SenderType.USER.value:
            chat_history.append(HumanMessage(content=msg.content))
        else:
            chat_history.append(AIMessage(content=msg.content))

    # C. Prompt (with language)
    system_prompt = get_system_prompt(mode, user_name, persona_data, current_stage, user_language, message)
    messages = [SystemMessage(content=system_prompt)] + chat_history + [HumanMessage(content=message)]
    
    final_response_dict = {}
    ai_reply = ""

    try:
        # First LLM Call
        response = await llm_with_tools.ainvoke(messages)
        
        # [FIX] GROUP ALL MODES THAT REQUIRE JSON PARSING HERE
        json_modes = ["ONBOARDING", "STRATEGY_ADVISOR", "GOAL_RELATIONSHIP_CHECK", "BLUEPRINT_GENERATOR", "GOALS_SETUP"]
        
        if mode in json_modes:
            try:
                # 1. Cleaner: Markdown removal
                content_str = response.content.strip()
                if "```" in content_str:
                    content_str = content_str.replace("```json", "").replace("```", "")
                
                content_str = content_str.strip()
                
                # 2. Extract JSON block if surrounded by text
                start_idx = content_str.find("{")
                end_idx = content_str.rfind("}") + 1
                if start_idx != -1 and end_idx > start_idx:
                    content_str = content_str[start_idx:end_idx]
                
                if not content_str:
                    raise ValueError("Empty JSON string extracted")

                # 3. Parse
                parsed_response = json.loads(content_str)
                print(f"🧠 AI THINKING (JSON parsed in {mode}): {parsed_response}")

                # --- SPECIAL HANDLING PER MODE (IF NEEDED) ---

                # Mode: ONBOARDING
                if mode == "ONBOARDING":
                    ai_reply = parsed_response.get("reply", "...")
                    # Save logs logic for onboarding usually happens here or frontend triggers next
                    if parsed_response.get('is_valid_answer') and parsed_response.get('extracted_data') and current_stage:
                         # Just logging for now, similar to before
                         pass
                    final_response_dict = parsed_response
                
                # Mode: STRATEGY & RELATIONSHIP
                else:
                    # Frontend expects a stringified JSON in 'reply' for compatibility
                    # or it can consume the dict directly if updated.
                    # Based on User Request, we stick to the existing plan but robustly.
                    # Actually, if we return final_response_dict as Parsed Dict, frontend API service 
                    # usually returns 'data'. If `response.data` is the dict, then `response.data['reply']` is accessed.
                    # Re-reading goals_service.dart: 
                    # `String jsonStr = response.data['reply'] as String;`
                    # So 'reply' MUST be a STRING.
                    
                    final_response_dict = {
                        "reply": json.dumps(parsed_response), 
                        "mode": mode
                    }
                    ai_reply = f"[JSON Data for {mode}]"

            except (json.JSONDecodeError, ValueError) as e:
                print(f"❌ JSON ERROR in {mode}: {response.content}")
                
                # Fallback Logic
                error_fallback = {}
                if mode == "STRATEGY_ADVISOR":
                     error_fallback = {
                        "recommended_method": "Project 180", 
                        "why": "AI Output Error (Fallback).", 
                        "time_horizon": "6 Months"
                     }
                elif mode == "GOAL_RELATIONSHIP_CHECK":
                     error_fallback = {
                         "is_related": False,
                         "reasoning": "Fallback due to AI error."
                     }
                else:
                     error_fallback = {"reply": "Error processing request."}
                
                final_response_dict = {
                    "reply": json.dumps(error_fallback), 
                    "mode": mode
                }
                ai_reply = "Error generating proper JSON."

        # --- MODE: DAILY / GOALS (Standard Chat) ---
        else:
            # Tool Loop Logic
            if response.tool_calls:
                print(f"🛠️ AI requested tools: {response.tool_calls}")
                messages.append(response)
                
                for tool_call in response.tool_calls:
                    tool_name = tool_call["name"]
                    tool_args = tool_call["args"]
                    if tool_name in tool_map:
                        tool_result = await tool_map[tool_name].ainvoke(tool_args)
                        messages.append(ToolMessage(content=str(tool_result), tool_call_id=tool_call["id"]))
                    else:
                        messages.append(ToolMessage(content="Tool not found", tool_call_id=tool_call["id"]))
                
                # Second Call
                response = await llm_with_tools.ainvoke(messages)
            
            ai_reply = response.content
            # FIX 1: Standardize DAILY output to Dictionary too
            final_response_dict = {
                "reply": ai_reply,
                "mode": mode
            }
        
    except Exception as e:
        print(f"❌ AI Error: {e}")
        ai_reply = "Maaf, sistem sedang sibuk. Coba lagi nanti."
        final_response_dict = {"reply": ai_reply, "error": str(e)}
    
    # Save Chat Logs
    session.add(ChatMessage(user_id=uuid_user_id, sender=SenderType.USER.value, content=message))
    session.add(ChatMessage(user_id=uuid_user_id, sender=SenderType.AI.value, content=ai_reply))
    await session.commit()
    
    # Debug Print
    print("\n" + "="*60)
    print(f"📝 CHAT DEBUG [{mode}] Reply: {ai_reply[:50] if ai_reply else 'N/A'}...")
    print("="*60 + "\n")
    
    return final_response_dict
