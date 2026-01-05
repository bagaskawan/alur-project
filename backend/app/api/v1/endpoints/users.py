from fastapi import APIRouter, Depends, HTTPException
from app.core.database import get_session
from sqlmodel.ext.asyncio.session import AsyncSession
from app.models.all_models import Profile
from app.core.deps import get_current_user
from pydantic import BaseModel
from typing import Dict, Any

router = APIRouter()

class ProfileUpdate(BaseModel):
    personalization_data: Dict[str, Any] # JSONB dari Frontend/AI

@router.put("/profile")
async def update_profile(
    data: ProfileUpdate,
    session: AsyncSession = Depends(get_session),
    user_id: str = Depends(get_current_user)
):
    # Cari Profile
    profile = await session.get(Profile, user_id)
    if not profile:
        # Harusnya profile otomatis dibuat via Trigger Supabase saat register,
        # tapi kalau belum ada, kita buat manual (defensive coding)
        profile = Profile(id=user_id, personalization_data=data.personalization_data)
        session.add(profile)
    else:
        # Update data
        profile.personalization_data = data.personalization_data
        session.add(profile)
        
    await session.commit()
    await session.refresh(profile)
    return {"status": "success", "profile": profile}
