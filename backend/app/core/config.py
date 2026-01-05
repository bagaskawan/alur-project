from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "ALUR API"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str
    
    # AI
    GROQ_API_KEY: str
    # Model yang direkomendasikan untuk Groq: 
    # - llama3-70b-8192 (Pintar, Stabil)
    # - llama3-8b-8192 (Super Cepat)
    # - mixtral-8x7b-32768 (Context Window Besar)
    GROQ_MODEL: str = "openai/gpt-oss-120b" 

    @property
    def ASYNC_DATABASE_URL(self) -> str:
        if self.DATABASE_URL and self.DATABASE_URL.startswith("postgresql://"):
            return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
        return self.DATABASE_URL

    class Config:
        env_file = ".env"
        extra = "ignore" # Allow extra fields in .env

settings = Settings()
