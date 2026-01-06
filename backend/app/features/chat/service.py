from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage, ToolMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from app.core.config import settings
from app.features.chat.tools import get_user_schedule, update_task_schedule, create_new_task
from app.models.all_models import Profile, ChatMessage, SenderType
from sqlmodel import select
from app.core.database import get_session # Dependency injection helper
from sqlalchemy.orm import sessionmaker
from sqlmodel.ext.asyncio.session import AsyncSession
from app.core.database import engine
import uuid
import json

# Setup Model & Tools
llm = ChatGroq(
    temperature=0.3, # Slightly creative but tool-compliant
    model_name=settings.GROQ_MODEL,
    api_key=settings.GROQ_API_KEY
)

# Bind Tools to LLM
tools = [get_user_schedule, update_task_schedule, create_new_task]
tool_map = {t.name: t for t in tools}
llm_with_tools = llm.bind_tools(tools)

def get_system_prompt(mode: str, user_name: str, persona_data: dict, current_stage: str = None) -> str:
    """
    Returns the appropriate system prompt based on the chat mode.
    Each mode defines a different "persona" for the AI.
    """
    
    if mode == "ONBOARDING":
        # Define valid options for each stage
        valid_options = {
            "energy_profile": "MORNING_LARK (pagi), NIGHT_OWL (malam), FLEXIBLE (keduanya/fleksibel)",
            "motivation_drivers": "GOAL (tujuan/target), REWARD (hadiah/bonus), SOCIAL (teman/lingkungan), GROWTH (belajar/berkembang)",
            "challenge_response": "FIGHTER (langsung hajar), STRATEGIC (susun strategi), COLLABORATOR (minta bantuan), ADAPTIVE (lihat situasi)",
            "learning_style": "VISUAL (gambar/video), AUDITORY (suara/podcast), KINESTHETIC (praktek), READING_WRITING (baca/tulis)",
            "behavior_type": "INTROVERT (sendiri), EXTROVERT (ramai), AMBIVERT (tergantung)",
        }
        
        options_description = valid_options.get(current_stage, "Jawab pertanyaan user saja.")
        
        return f"""Kamu adalah ALUR, asisten produktivitas.

KONTEKS ONBOARDING:
- Stage Saat Ini: '{current_stage}'
- Opsi Valid: {options_description}

TUGASMU:
Analisa pesan user dan tentukan apakah jawabannya VALID untuk stage ini.
Boleh memilih LEBIH DARI SATU value jika user memang menjawab keduanya (misal: "pagi dan malam" -> ["MORNING_LARK", "NIGHT_OWL"]).

OUTPUT HARUS FORMAT JSON (Tanpa markdown):
{{
  "is_valid_answer": boolean,
  "extracted_data": string | list[string], // VALUE dari Opsi Valid. Bisa satu string atau list strings jika multiple.
  "reasoning": string,
  "reply": string
}}

LOGIKA REPLY:
1. JIKA is_valid_answer = TRUE:
   - [BRIDGING] Buat transisi HALUS ke pertanyaan berikutnya. Contoh:
     * "Keren, fleksibel pagi-malam! Nah, soal motivasi..."
     * "Mantap, visual learner ya. Btw, kamu recharge gimana?"
   - [WAJIB] Beri jarak 1 BARIS KOSONG (ENTER) antara pujian dan pertanyaan.
   - JANGAN tanya "Lanjut ya?", "Next?", atau konfirmasi tidak penting.
   - JANGAN mengulang jawaban user ("Oke kamu pilih A..."). Langsung ke pertanyaan baru.
2. JIKA is_valid_answer = FALSE:
   - JIKA user menjawab "SEMUANYA", "ALL", "KEDUANYA", atau sejenisnya:
     - VALID! Masukkan SEMUA opsi yang relevan ke `extracted_data`.
   - JIKA user benar-benar bingung/ngawur:
     - Jelaskan singkat & tanya ulang.
     - [PENTING] JANGAN Ulangi list opsi lengkap jika sudah ada di chat sebelumnya. Cukup tanya: "Mana yang paling pas?" atau "Bingung yang mana?"

FORMATTING:
- Gunakan list bullet (-) jika menyebutkan opsi pilihan.
- Pastikan ada jarak antar paragraf.

[LARANGAN KERAS]:
- JANGAN PERNAH tulis raw value seperti "VISUAL", "AUDITORY", "MORNING_LARK" di dalam "reply".
- Gunakan bahasa manusia: "lewat gambar/video", "di pagi hari", bukan "VISUAL", "MORNING_LARK".

GAYA BAHASA:
- Santai, friendly, max 2 kalimat intro/outro.
- Hemat kata. Jangan basa-basi.
"""

    elif mode == "GOALS_SETUP":
        return f"""You are ALUR, acting as a Strategic Goal Consultant for {user_name}.
User Profile: {persona_data}

Your Goal: Help the user define and break down their long-term goals into actionable steps.

CONSULTATION FLOW:
1. Ask about their main goal or dream they want to achieve.
2. Help them clarify WHY this goal matters to them (motivation anchor).
3. Break the big goal into 2-3 milestone sub-goals.
4. For each milestone, suggest 1-2 concrete first steps (tasks).
5. Offer to create these tasks using the 'create_new_task' tool.

RULES:
- Be visionary and encouraging. Think big, but plan practically.
- Use the Socratic method: ask guiding questions, don't just dictate.
- When ready to create tasks, use the 'create_new_task' tool with appropriate dates.
- Respond in the SAME LANGUAGE the user uses for input.
"""

    else:  # DAILY (Default)
        return f"""You are ALUR, a personal productivity assistant for {user_name}.
User Profile: {persona_data}

Tone: Relaxed, supportive, but firm regarding data accuracy.
Your Task: Help the user organize their schedule, record tasks, and remind them of habits.

CAPABILITIES:
- Check schedule: Use 'get_user_schedule' tool to see real tasks.
- Reschedule tasks: Use 'update_task_schedule' tool to move tasks.
- Create new tasks: Use 'create_new_task' tool when user wants to add something.

RULES:
- If user asks about schedules/tasks, ALWAYS use tools. DO NOT HALLUCINATE data.
- Be conversational and friendly, like a helpful buddy.
- Respond in the SAME LANGUAGE the user uses for input.
"""


async def process_chat(user_id: str, message: str, mode: str = "DAILY", current_stage: str = None):
    """
    Main function called by API Endpoint.
    Manually handles tool calling loop to replace AgentExecutor.
    Mode determines which "persona" the AI adopts.
    """
    # 1. Open Logic-Specific DB Session
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        # A. CONTEXT AWARENESS: Fetch User Profile
        try:
            uuid_user_id = uuid.UUID(user_id)
        except ValueError:
            return "Error: Invalid User ID format."

        profile = await session.get(Profile, uuid_user_id)
        user_name = profile.full_name if profile else "Friend"
        persona_data = profile.personalization_data if profile else {}
        
        # B. MEMORY: Fetch last 5 chats from DB
        history_stmt = select(ChatMessage).where(ChatMessage.user_id == uuid_user_id).order_by(ChatMessage.created_at.desc()).limit(5)
        history_result = await session.exec(history_stmt)
        db_history = history_result.all()
        
        # Convert DB history to LangChain format (reverse to chronological)
        chat_history = []
        for msg in reversed(db_history):
            if msg.sender == SenderType.USER.value:
                chat_history.append(HumanMessage(content=msg.content))
            else:
                chat_history.append(AIMessage(content=msg.content))

        # C. DYNAMIC SYSTEM PROMPT based on mode
        system_prompt = get_system_prompt(mode, user_name, persona_data, current_stage)

        # D. PREPARE MESSAGES
        messages = [SystemMessage(content=system_prompt)] + chat_history + [HumanMessage(content=message)]
        
        try:
            # First LLM Call
            response = await llm_with_tools.ainvoke(messages)
            
            # --- SPECIAL LOGIC FOR ONBOARDING (JSON HANDLING) ---
            if mode == "ONBOARDING":
                try:
                    # Parse JSON from AI response
                    content_str = response.content.strip()
                    # Remove markdown code blocks if present (e.g. ```json ... ```)
                    if content_str.startswith("```json"):
                         content_str = content_str[7:]
                    if content_str.endswith("```"):
                         content_str = content_str[:-3]
                    
                    if not content_str:
                        raise ValueError("Empty JSON response from AI")

                    parsed_response = json.loads(content_str.strip())
                    
                    # Log for debugging
                    print(f"🧠 AI THINKING (JSON): {parsed_response}")
                    
                    ai_reply = parsed_response.get("reply", "...")
                    
                    # IF VALID: Save data to DB immediately
                    if parsed_response.get('is_valid_answer') and parsed_response.get('extracted_data') and current_stage:
                        data_value = parsed_response['extracted_data']
                        
                        # Init persona_data if None
                        if not persona_data:
                            persona_data = {}
                            
                        # Update specific field
                        # Note: We store as list to match existing format or string?
                        # Using list for consistency with previous schema
                        if isinstance(data_value, list):
                             persona_data[current_stage] = data_value
                        else:
                             persona_data[current_stage] = [data_value]
                        
                        profile.personalization_data = persona_data
                        session.add(profile)
                        await session.commit()
                        await session.refresh(profile)
                        print(f"✅ SAVED TO DB: {current_stage} = {data_value}")

                    # Return the full JSON to frontend
                    # But first, save chat log (flattened)
                    
                except json.JSONDecodeError:
                    print(f"❌ JSON PARSE ERROR. Raw: {response.content}")
                    # Fallback
                    ai_reply = response.content
                    parsed_response = {
                        "is_valid_answer": False,
                        "reply": ai_reply,
                        "extracted_data": None
                    }
                
                # Save Chat Log (User & AI Reply only)
                user_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.USER.value, content=message)
                session.add(user_msg_db)
                
                ai_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.AI.value, content=ai_reply)
                session.add(ai_msg_db)
                await session.commit()
                
                return parsed_response

            # --- STANDARD LOGIC FOR OTHER MODES (DAILY, ETC) ---
            
            # Check for tool calls
            if response.tool_calls:
                print(f"🛠️ AI requested tools: {response.tool_calls}")
                messages.append(response) # Add assistant message with tool calls
                
                for tool_call in response.tool_calls:
                    tool_name = tool_call["name"]
                    tool_args = tool_call["args"]
                    
                    if tool_name in tool_map:
                        print(f"Running tool: {tool_name}")
                        # Execute tool
                        tool_result = await tool_map[tool_name].ainvoke(tool_args)
                        messages.append(ToolMessage(content=str(tool_result), tool_call_id=tool_call["id"]))
                    else:
                        messages.append(ToolMessage(content=f"Error: Tool {tool_name} not found", tool_call_id=tool_call["id"]))
                
                # Second LLM Call (Generates final response based on tool outputs)
                response = await llm_with_tools.ainvoke(messages)
            
            ai_reply = response.content
            
        except Exception as e:
            print(f"❌ AI Error: {e}")
            ai_reply = "Maaf, otak saya sedang loading lama. Coba lagi ya? (System Error)"
        
        # F. SAVE NEW CHAT TO DB
        user_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.USER.value, content=message)
        session.add(user_msg_db)
        
        ai_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.AI.value, content=ai_reply)
        session.add(ai_msg_db)
        
        await session.commit()
        
        # G. DEBUG PRINT - Show collected data in terminal
        print("\n" + "="*60)
        print(f"📝 CHAT DEBUG [{mode}]")
        print(f"   User: {user_name} (ID: {user_id})")
        print(f"   Message: {message}")
        print(f"   AI Reply: {ai_reply[:100]}..." if len(ai_reply) > 100 else f"   AI Reply: {ai_reply}")
        print(f"   Persona Data from DB: {persona_data}")
        print("="*60 + "\n")
        
        return ai_reply
