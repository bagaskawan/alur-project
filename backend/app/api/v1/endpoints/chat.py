from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.features.chat.service import process_chat

router = APIRouter()

class ChatRequest(BaseModel):
    user_id: str
    message: str

@router.post("/send")
async def send_message(request: ChatRequest):
    try:
        response = await process_chat(request.user_id, request.message)
        return {"reply": response}
    except Exception as e:
        # Log error in production
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
