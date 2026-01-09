from fastapi import APIRouter, Depends, HTTPException
from app.core.database import get_session
from sqlmodel.ext.asyncio.session import AsyncSession
from app.models.all_models import Profile
from app.core.deps import get_current_user
from pydantic import BaseModel
from typing import Dict, Any, Optional

router = APIRouter()

from datetime import datetime

class ProfileUpdate(BaseModel):
    personalization_data: Optional[Dict[str, Any]] = None
    work_start_time: Optional[str] = None # Format "HH:MM"
    work_end_time: Optional[str] = None
    ai_persona: Optional[str] = None
    preferred_language: Optional[str] = None

@router.get("/profile")
async def get_profile(
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    profile = await session.get(Profile, user_id)
    if not profile:
        # Create default if missing
        profile = Profile(id=user_id)
        session.add(profile)
        await session.commit()
    return profile

@router.put("/profile")
async def update_profile(
    data: ProfileUpdate,
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    # Cari Profile
    profile = await session.get(Profile, user_id)
    if not profile:
        profile = Profile(id=user_id)
        session.add(profile)
    
    # Update fields if provided
    if data.personalization_data is not None:
        profile.personalization_data = data.personalization_data
        
    if data.ai_persona is not None:
        profile.ai_persona = data.ai_persona
        
    if data.preferred_language is not None:
        profile.preferred_language = data.preferred_language
        
    if data.work_start_time is not None:
        try:
             # Parse "09:00" -> time object
             t = datetime.strptime(data.work_start_time, "%H:%M").time()
             profile.work_start_time = t
        except ValueError:
            pass # Ignore invalid format
            
    if data.work_end_time is not None:
        try:
             t = datetime.strptime(data.work_end_time, "%H:%M").time()
             profile.work_end_time = t
        except ValueError:
            pass

    session.add(profile)
    await session.commit()
    await session.refresh(profile)
    return {"status": "success", "profile": profile}


# ============================================================
# Personality Profile - Partial Update
# ============================================================

from typing import List

class PersonalityFieldUpdate(BaseModel):
    """Schema untuk update satu field personality saja"""
    field: str  # "energy_profile", "motivation_drivers", etc.
    value: List[str]  # ["NIGHT_OWL"]

# Valid fields dan options untuk validasi
PERSONALITY_OPTIONS = {
    "energy_profile": ["MORNING_LARK", "NIGHT_OWL", "FLEXIBLE"],
    "motivation_drivers": ["GOAL_ORIENTED", "REWARD_DRIVEN", "SOCIAL_DRIVEN", "GROWTH_FOCUSED"],
    "challenge_response": ["FIGHTER", "STRATEGIC", "COLLABORATOR", "ADAPTIVE"],
    "learning_style": ["VISUAL", "AUDITORY", "KINESTHETIC", "READING_WRITING"],
    "behavior_type": ["INTROVERT", "EXTROVERT", "AMBIVERT"],
}

@router.patch("/profile/personality")
async def update_personality_field(
    data: PersonalityFieldUpdate,
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    """
    Update satu field personality tanpa menghapus field lainnya.
    
    Contoh request:
    {
        "field": "energy_profile",
        "value": ["NIGHT_OWL"]
    }
    
    Ini akan update HANYA energy_profile, field lain tetap.
    """
    # Validasi field name
    if data.field not in PERSONALITY_OPTIONS:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid field: {data.field}. Valid fields: {list(PERSONALITY_OPTIONS.keys())}"
        )
    
    # Validasi value
    valid_options = PERSONALITY_OPTIONS[data.field]
    for val in data.value:
        if val not in valid_options:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid value '{val}' for {data.field}. Valid options: {valid_options}"
            )
    
    # Get or create profile
    profile = await session.get(Profile, user_id)
    if not profile:
        profile = Profile(id=user_id)
        session.add(profile)
    
    # Get existing personalization_data or create empty dict
    # IMPORTANT: Create a COPY to ensure ORM detects the change
    # If we modify in place, SQLModel might not detect the update
    current_data = profile.personalization_data 
    if current_data:
        existing_data = dict(current_data)
    else:
        existing_data = {}
    
    # Merge - update only the specified field
    existing_data[data.field] = data.value
    
    # Save back (assigning new dict object triggers change detection)
    profile.personalization_data = existing_data
    
    session.add(profile)
    await session.commit()
    await session.refresh(profile)
    
    return {
        "status": "success", 
        "field": data.field,
        "value": data.value,
        "personalization_data": profile.personalization_data
    }
