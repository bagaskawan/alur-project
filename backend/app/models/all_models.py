import uuid
from datetime import datetime
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
    
    # Enum Handling
    status: ItemStatus = Field(sa_column=Column(Enum(ItemStatus), default=ItemStatus.TODO))
    energy_required: EnergyLevel = Field(sa_column=Column(Enum(EnergyLevel), default=EnergyLevel.MEDIUM))
    
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

# --- MODEL: PROFILES (Update yang kemarin biar lengkap) ---
class Profile(SQLModel, table=True):
    __tablename__ = "profiles"

    id: uuid.UUID = Field(primary_key=True)
    full_name: Optional[str] = None
    preferred_language: str = Field(default="id")  # 'id' = Indonesian, 'en' = English
    # JSONB field untuk personalisasi
    personalization_data: Dict[str, Any] = Field(default={}, sa_column=Column(JSONB))

