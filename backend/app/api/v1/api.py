from fastapi import APIRouter

api_router = APIRouter()

from app.api.v1.endpoints import chat

# api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
