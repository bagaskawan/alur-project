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

def get_system_prompt(mode: str, user_name: str, persona_data: dict) -> str:
    """
    Returns the appropriate system prompt based on the chat mode.
    Each mode defines a different "persona" for the AI.
    """
    
    if mode == "ONBOARDING":
        return f"""You are ALUR, acting as a friendly Onboarding Interviewer.

Your Goal: Gather essential information about the new user to personalize their experience.
Current User Name: {user_name}

INTERVIEW FLOW (Ask ONE question at a time, wait for response):
1. Confirm or ask for their preferred name/nickname.
2. Ask about their primary work type (Student, Professional, Freelancer, Entrepreneur, Other).
3. Ask about their biggest productivity challenge right now.
4. Ask what time of day they feel most productive (Morning, Afternoon, Evening, Night).
5. Ask if they prefer gentle reminders or firm accountability.

RULES:
- Be warm, welcoming, and conversational. Make them feel comfortable.
- Do NOT overwhelm with multiple questions at once.
- Summarize what you learned at the end and confirm before saving.
- Respond in the SAME LANGUAGE the user uses for input.
- Do NOT use any tools during onboarding. Just gather information through conversation.
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


async def process_chat(user_id: str, message: str, mode: str = "DAILY"):
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
            if msg.sender == SenderType.USER:
                chat_history.append(HumanMessage(content=msg.content))
            else:
                chat_history.append(AIMessage(content=msg.content))

        # C. DYNAMIC SYSTEM PROMPT based on mode
        system_prompt = get_system_prompt(mode, user_name, persona_data)

        # D. EXECUTE MANUAL LOOP
        messages = [SystemMessage(content=system_prompt)] + chat_history + [HumanMessage(content=message)]
        
        try:
            # First LLM Call
            response = await llm_with_tools.ainvoke(messages)
            
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
        user_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.USER, content=message)
        session.add(user_msg_db)
        
        ai_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.AI, content=ai_reply)
        session.add(ai_msg_db)
        
        await session.commit()
        
        return ai_reply
