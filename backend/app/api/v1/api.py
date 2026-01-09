from fastapi import APIRouter

api_router = APIRouter()

from app.api.v1.endpoints import chat, users, tasks, goals
# api_router was already initialized above (line 3 in origin), but previous tool call might have messed it up. 
# based on previous diff: "from app.api.v1.endpoints import chat, users, tasks" was added, and "api_router = APIRouter()" was added again line 7.

# api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(goals.router, prefix="/goals", tags=["goals"])
