from typing import Optional, List
from sqlmodel import SQLModel, Field, Column
from sqlalchemy import Enum, text
from sqlalchemy.dialects.postgresql import JSONB
import uuid
from datetime import datetime
import enum

# --- ENUMS (Harus sama persis dengan SQL) ---
class BehaviorType(str, enum.Enum):
    PLANNER = "PLANNER"
    PROCRASTINATOR = "PROCRASTINATOR"
    # ... tambahkan lainnya

class CycleType(str, enum.Enum):
    SPRINT = "SPRINT"
    PROJECT_180 = "PROJECT_180"
    MARATHON = "MARATHON"

class ItemStatus(str, enum.Enum):
    TODO = "TODO"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"
    # ...

# --- MODELS ---

# 1. Profile Model
class Profile(SQLModel, table=True):
    __tablename__ = "profiles"

    id: uuid.UUID = Field(primary_key=True)
    email: Optional[str] = None
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    
    # JSONB Field untuk Personalization Data
    # Kita pakai sa_column untuk mendefinisikan tipe data spesifik PostgreSQL
    personalization_data: dict = Field(default={}, sa_column=Column(JSONB))
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

# 2. Growth Cycle Model
class GrowthCycle(SQLModel, table=True):
    __tablename__ = "growth_cycles"
    
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(foreign_key="profiles.id")
    title: str
    
    # Handling Enum di Postgres
    type: CycleType = Field(sa_column=Column(Enum(CycleType)))
    
    start_date: datetime
    end_date: datetime
    is_active: bool = True
    theme: Optional[str] = None
