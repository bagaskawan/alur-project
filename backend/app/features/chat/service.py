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

async def process_chat(user_id: str, message: str):
    """
    Main function called by API Endpoint.
    Manually handles tool calling loop to replace AgentExecutor.
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

        # C. SYSTEM PROMPT
        system_prompt = f"""You are ALUR, a personal productivity assistant for {user_name}.
        User Data: {persona_data}
        
        Tone: Relaxed, supportive, but firm regarding data.
        Your Task: Help the user organize their schedule, record tasks, and remind them of habits.
        IMPORTANT: If the user asks about schedules/tasks, DO NOT HALLUCINATE. Use the 'get_user_schedule' tool to check real data.
        """

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
