from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage, ToolMessage
from app.core.config import settings
from app.features.chat.tools import get_user_schedule, update_task_schedule, create_new_task
from app.models.all_models import Profile, ChatMessage, SenderType
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


def get_system_prompt(mode: str, user_name: str, persona_data: dict, current_stage: str = None, language: str = "id") -> str:
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
        Rules: Be visionary but practical. Help break big goals into tasks using 'create_new_task'.
        Respond in the SAME LANGUAGE the user uses.
        """
    elif mode == "GOAL_ENHANCE":
        return f"""You are an Expert Goal Editor using the SMART method (Specific, Measurable, Achievable, Relevant, Time-bound).
        
        YOUR TASK:
        Rewrite the user's rough goal input into a clear, inspiring, and actionable "North Star" statement.
        
        RULES:
        1. DO NOT chat or ask questions.
        2. JUST return the rewritten sentence. Nothing else.
        3. Make it sound ambitious but realistic.
        4. Detect the user's language (Indonesian/English) and output in the SAME language.
        
        Example Input: "Pengen kaya"
        Example Output: "Mencapai kebebasan finansial dengan tabungan 100 juta pertama dalam 2 tahun melalui bisnis sampingan."
        
        Example Input: "Lose weight"
        Example Output: "Lose 5kg in 3 months by maintaining a consistent workout routine and healthy diet."
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
    system_prompt = get_system_prompt(mode, user_name, persona_data, current_stage, user_language)
    messages = [SystemMessage(content=system_prompt)] + chat_history + [HumanMessage(content=message)]
    
    final_response_dict = {}
    ai_reply = ""

    try:
        # First LLM Call
        response = await llm_with_tools.ainvoke(messages)
        
        # --- MODE: ONBOARDING ---
        if mode == "ONBOARDING":
            try:
                content_str = response.content.strip().replace("```json", "").replace("```", "").strip()
                start_idx = content_str.find("{")
                end_idx = content_str.rfind("}") + 1
                if start_idx != -1 and end_idx > start_idx:
                    content_str = content_str[start_idx:end_idx]
                
                if not content_str or content_str == "{}":
                    raise ValueError("Empty JSON")

                parsed_response = json.loads(content_str)
                print(f"🧠 AI THINKING (JSON): {parsed_response}")
                ai_reply = parsed_response.get("reply", "...")
                
                # DO NOT save to DB here - let frontend accumulate and save at the end
                # Backend only validates and returns extracted_data
                if parsed_response.get('is_valid_answer') and parsed_response.get('extracted_data') and current_stage:
                    data_value = parsed_response['extracted_data']
                    print(f"📦 EXTRACTED (not saved yet): {current_stage} = {data_value}")

                final_response_dict = parsed_response

            except (json.JSONDecodeError, ValueError) as e:
                print(f"❌ JSON ERROR: {response.content}")
                ai_reply = response.content  # Fallback to raw text
                final_response_dict = {
                    "is_valid_answer": False,
                    "reply": ai_reply,
                    "extracted_data": None
                }
            
        # --- MODE: DAILY / GOALS ---
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
