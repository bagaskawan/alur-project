from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.features.chat.service import process_chat

router = APIRouter()

from app.core.deps import get_current_user
from fastapi import Depends

class ChatRequest(BaseModel):
    message: str

@router.post("/send")
async def send_message(request: ChatRequest, user_id: str = Depends(get_current_user)):
    try:
        response = await process_chat(user_id, request.message)
        return {"reply": response}
    except Exception as e:
        # Log error in production
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
