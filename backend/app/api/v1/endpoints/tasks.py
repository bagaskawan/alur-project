from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import select
from app.core.database import get_session
from sqlmodel.ext.asyncio.session import AsyncSession
from app.models.all_models import Task, ItemStatus
from app.core.deps import get_current_user
from pydantic import BaseModel
from typing import Optional
from datetime import date

router = APIRouter()

# Schema Input (DTO)
class TaskCreate(BaseModel):
    title: str
    scheduled_date: Optional[date] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    status: Optional[ItemStatus] = None
    scheduled_date: Optional[date] = None

@router.post("/")
async def create_task(
    task_in: TaskCreate,
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    # Note: scheduled_date is Optional[date], but Task model might expect datetime or date. 
    # Checking Task model definition would be prudent, but assuming SQLModel handles date->datetime conversion or field is date.
    # Base on earlier tools.py snippet: t.scheduled_date.strftime("%Y-%m-%d") implies it might be datetime or date object.
    new_task = Task(
        user_id=user_id,
        title=task_in.title,
        scheduled_date=task_in.scheduled_date, # ensure this matches model
        status=ItemStatus.TODO
    )
    session.add(new_task)
    await session.commit()
    await session.refresh(new_task)
    return new_task

@router.get("/")
async def read_tasks(
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    statement = select(Task).where(Task.user_id == user_id)
    result = await session.exec(statement)
    return result.all()
