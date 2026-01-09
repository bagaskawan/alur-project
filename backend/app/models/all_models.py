import uuid
from datetime import datetime, time
from typing import Optional, List, Dict, Any
from sqlmodel import SQLModel, Field, Column
from sqlalchemy import Enum, text
from sqlalchemy.dialects.postgresql import JSONB
import enum

# --- ENUMS (Harus sama persis dengan di Supabase) ---
class ItemStatus(str, enum.Enum):
    TODO = "TODO"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"
    SNOOZED = "SNOOZED"
    SKIPPED = "SKIPPED"
    ARCHIVED = "ARCHIVED"

class EnergyLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"

class SenderType(str, enum.Enum):
    USER = "USER"
    AI = "AI"

# --- MODEL: TASKS ---
class Task(SQLModel, table=True):
    __tablename__ = "tasks"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="profiles.id", nullable=False)
    goal_id: Optional[uuid.UUID] = Field(default=None, foreign_key="goals.id")
    
    title: str
    description: Optional[str] = None
    
    # Use String instead of Enum for Supabase compatibility
    status: str = Field(default="TODO")
    energy_required: str = Field(default="MEDIUM")
    
    scheduled_date: Optional[datetime] = None
    estimated_duration: Optional[int] = None # Dalam menit
    is_atomized: bool = Field(default=False)
    
    due_date: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

# --- MODEL: CHAT MESSAGES ---
class ChatMessage(SQLModel, table=True):
    __tablename__ = "chat_messages"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="profiles.id", nullable=False)
    
    # Menggunakan String bukan Enum agar kompatibel dengan Supabase
    # Validasi tetap bisa dilakukan di level Python dengan SenderType enum
    sender: str = Field(default="USER")  # "USER" atau "AI"
    content: str
    
    related_task_id: Optional[uuid.UUID] = Field(default=None, foreign_key="tasks.id")
    is_onboarding: bool = Field(default=False)
    
    created_at: datetime = Field(default_factory=datetime.utcnow)


# --- MODEL: GOALS ---
class Goal(SQLModel, table=True):
    __tablename__ = "goals"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="profiles.id", nullable=False)
    
    cycle_id: Optional[uuid.UUID] = Field(default=None, foreign_key="growth_cycles.id")
    
    title: str
    description: Optional[str] = None
    
    # Use String instead of Enum for Supabase compatibility
    status: str = Field(default="IN_PROGRESS")
    priority: str = Field(default="MAIN_QUEST") # MAIN_QUEST, SIDE_QUEST
    progress: int = Field(default=0)
    
    parent_goal_id: Optional[uuid.UUID] = Field(default=None, foreign_key="goals.id")
    
    # [BARU] Menampung strategi apapun (Harada, WOOP, dll)
    framework_type: Optional[str] = Field(default=None) 
    
    # Gunakan sa_column untuk JSONB agar performa tinggi di Postgres
    framework_data: Dict[str, Any] = Field(default={}, sa_column=Column(JSONB))
    
    created_at: datetime = Field(default_factory=datetime.utcnow)

# --- MODEL: PROFILES (Update yang kemarin biar lengkap) ---
class Profile(SQLModel, table=True):
    __tablename__ = "profiles"

    id: uuid.UUID = Field(primary_key=True)
    email: Optional[str] = None
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    
    ai_persona: str = Field(default="FRIENDLY")
    work_start_time: Optional[time] = Field(default=None) # Default handled by DB or app
    work_end_time: Optional[time] = Field(default=None)
    
    preferred_language: str = Field(default="id")  # 'id' = Indonesian, 'en' = English
    # JSONB field untuk personalisasi
    personalization_data: Dict[str, Any] = Field(default={}, sa_column=Column(JSONB))


# --- MODEL: GROWTH CYCLE ---
class GrowthCycle(SQLModel, table=True):
    __tablename__ = "growth_cycles"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="profiles.id", nullable=False)
    
    title: str
    # [UBAH] Jadi TEXT biasa agar fleksibel (Anti-Crash 500)
    type: Optional[str] = Field(default=None)
    theme: Optional[str] = None
    
    start_date: datetime 
    end_date: datetime
    
    is_active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

