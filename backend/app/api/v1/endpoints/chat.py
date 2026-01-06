from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, Literal
from app.features.chat.service import process_chat
from app.core.deps import get_current_user

router = APIRouter()

# Mode types for AI "persona switching"
ChatMode = Literal["ONBOARDING", "GOALS_SETUP", "DAILY"]

class ChatRequest(BaseModel):
    message: str
    mode: Optional[ChatMode] = "DAILY"  # Default to daily assistant
    current_stage: Optional[str] = None # For onboarding context

@router.post("/send")
async def send_message(request: ChatRequest, user_id: str = Depends(get_current_user)):
    try:
        response = await process_chat(user_id, request.message, request.mode, request.current_stage)
        # Check if response is a dict (JSON), otherwise return as string in 'reply'
        if isinstance(response, dict):
            return response
        return {"reply": response}
    except Exception as e:
        # Log error in production
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
