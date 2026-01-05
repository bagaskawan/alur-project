from langchain_core.tools import tool
from sqlmodel import select
from app.core.database import engine
from sqlalchemy.orm import sessionmaker
from sqlmodel.ext.asyncio.session import AsyncSession
from app.models.all_models import Task, ItemStatus
from datetime import datetime

# Helper to create session inside Tool (IMPORTANT!)
# We cannot pass session from outside because LangChain serializes tools
async def get_session_context():
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    return async_session()

@tool
async def get_user_schedule(user_id: str):
    """
    Get the list of active tasks (TODO/IN_PROGRESS) for the user today.
    Use this tool if the user asks 'What is my schedule?' or 'What tasks are pending?'.
    """
    print(f"🛠️ TOOL CALLED: get_user_schedule for {user_id}")
    
    async with await get_session_context() as session:
        # Query Real Task Table
        statement = select(Task).where(
            Task.user_id == user_id,
            Task.status.in_([ItemStatus.TODO, ItemStatus.IN_PROGRESS])
        )
        result = await session.exec(statement)
        tasks = result.all()
        
        if not tasks:
            return "No active tasks at the moment. Schedule is clear."
        
        # Format output for AI readability
        report = "User Task List:\n"
        for t in tasks:
            date_str = t.scheduled_date.strftime("%Y-%m-%d") if t.scheduled_date else "No Date"
            report += f"- [ID: {t.id}] {t.title} (Schedule: {date_str}, Status: {t.status.value})\n"
        
        return report

@tool
async def update_task_schedule(task_id: str, new_date: str):
    """
    Change the schedule date (reschedule) of a task by its ID.
    new_date format must be YYYY-MM-DD.
    """
    print(f"🛠️ TOOL CALLED: update_task_schedule id={task_id} to {new_date}")
    
    try:
        parsed_date = datetime.strptime(new_date, "%Y-%m-%d")
    except ValueError:
        return "Error: Wrong date format. Use YYYY-MM-DD."

    async with await get_session_context() as session:
        # Find Task
        task = await session.get(Task, task_id)
        if not task:
            return f"Error: Task with ID {task_id} not found."
        
        # Update
        task.scheduled_date = parsed_date
        session.add(task)
        await session.commit()
        await session.refresh(task)
        
        return f"Success! Task '{task.title}' successfully moved to {new_date}."
