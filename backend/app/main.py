from fastapi import FastAPI
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": f"{settings.PROJECT_NAME} is Running with Groq Speed! 🚀 (Model: {settings.GROQ_MODEL})"}

from app.api.v1.api import api_router
app.include_router(api_router, prefix=settings.API_V1_STR)
