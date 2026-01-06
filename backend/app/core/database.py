from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Setup Engine
# echo=True berguna buat debugging (lihat query SQL di terminal)
# Only create engine if DATABASE_URL is set to avoid errors during initial setup if env is missing
if settings.DATABASE_URL:
    # Supabase uses pgbouncer which doesn't support prepared statements
    # We must disable statement cache for compatibility
    engine = create_async_engine(
        settings.ASYNC_DATABASE_URL, 
        echo=False, 
        future=True,
        connect_args={"statement_cache_size": 0}  # Disable prepared statements for pgbouncer
    )
else:
    engine = None
    print("WARNING: DATABASE_URL not found in settings. Database connection will fail.")

# Dependency Injection untuk FastAPI
async def get_session() -> AsyncSession:
    if engine is None:
        raise RuntimeError("Database engine is not initialized. Check DATABASE_URL.")
        
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with async_session() as session:
        yield session
