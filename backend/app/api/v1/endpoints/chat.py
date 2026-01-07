from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, Literal
from app.features.chat.service import process_chat
from app.core.deps import get_current_user
from app.core.database import get_session  # Import session dependency
from sqlmodel.ext.asyncio.session import AsyncSession

router = APIRouter()

# Mode types for AI "persona switching"
ChatMode = Literal["ONBOARDING", "GOALS_SETUP", "GOAL_ENHANCE", "GOAL_RELATIONSHIP_CHECK", "STRATEGY_ADVISOR", "BLUEPRINT_GENERATOR", "DAILY"]

class ChatRequest(BaseModel):
    message: str
    mode: Optional[ChatMode] = "DAILY"  # Default to daily assistant
    current_stage: Optional[str] = None # For onboarding context

@router.post("/send")
async def send_message(
    request: ChatRequest, 
    user_id: str = Depends(get_current_user),
    session: AsyncSession = Depends(get_session)  # Inject session
):
    try:
        # Pass session as first argument
        response = await process_chat(
            session=session,
            user_id=user_id, 
            message=request.message, 
            mode=request.mode, 
            current_stage=request.current_stage
        )
        return response  # Service now always returns dict
    except Exception as e:
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

