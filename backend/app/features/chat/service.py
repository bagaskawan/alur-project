from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from app.core.config import settings
from app.features.chat.tools import get_user_schedule, update_task_schedule
from app.models.all_models import Profile, ChatMessage, SenderType
from sqlmodel import select
from app.core.database import get_session # Dependency injection helper
from sqlalchemy.orm import sessionmaker
from sqlmodel.ext.asyncio.session import AsyncSession
from app.core.database import engine
from langchain.agents import create_tool_calling_agent, AgentExecutor
import uuid

# Setup Model & Tools
llm = ChatGroq(
    temperature=0.3, # Slightly creative but tool-compliant
    model_name=settings.GROQ_MODEL,
    api_key=settings.GROQ_API_KEY
)

# Bind Tools to LLM
tools = [get_user_schedule, update_task_schedule]
llm_with_tools = llm.bind_tools(tools)

async def process_chat(user_id: str, message: str):
    """
    Main function called by API Endpoint.
    """
    # 1. Open Logic-Specific DB Session
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        # A. CONTEXT AWARENESS: Fetch User Profile
        # Ensure user_id is UUID
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

        # C. SYSTEM PROMPT (Character Brain) - English Version
        system_prompt = f"""You are ALUR, a personal productivity assistant for {user_name}.
        User Data: {persona_data}
        
        Tone: Relaxed, supportive, but firm regarding data.
        Your Task: Help the user organize their schedule, record tasks, and remind them of habits.
        IMPORTANT: If the user asks about schedules/tasks, DO NOT HALLUCINATE. Use the 'get_user_schedule' tool to check real data.
        """

        # D. ASSEMBLE PROMPT
        prompt = ChatPromptTemplate.from_messages([
            ("system", system_prompt),
            MessagesPlaceholder(variable_name="history"),
            ("human", "{input}"),
            MessagesPlaceholder(variable_name="agent_scratchpad"),
        ])
        
        # E. EXECUTE CHAIN (Use Tool Calling Agent)
        agent = create_tool_calling_agent(llm, tools, prompt)
        agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
        
        # "Run" Agent
        # Note: We pass 'input' (user message) and 'history'.
        # The agent will call tools if needed.
        response = await agent_executor.ainvoke({
            "input": message,
            "history": chat_history
        })
        
        ai_reply = response["output"]
        
        # F. SAVE NEW CHAT TO DB (Persistent Memory)
        # Save User Message
        user_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.USER, content=message)
        session.add(user_msg_db)
        
        # Save AI Message
        ai_msg_db = ChatMessage(user_id=uuid_user_id, sender=SenderType.AI, content=ai_reply)
        session.add(ai_msg_db)
        
        await session.commit()
        
        return ai_reply
