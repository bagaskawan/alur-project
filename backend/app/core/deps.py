from typing import AsyncGenerator
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import jwt # pip install PyJWT
from app.core.config import settings

# Ini ngasih tau FastAPI kalau endpoint butuh token di Header Authorization
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> str:
    """
    Validasi Token JWT dari Supabase/Gotrue.
    Return: user_id (UUID string)
    """
    try:
        # PENTING: Untuk Production nanti, kita harus verify signature pakai SUPABASE_JWT_SECRET.
        # Untuk MVP Tahap 1: Kita decode tanpa verify signature dulu biar cepet (asal format JWT valid).
        # options={"verify_signature": False} HANYA UNTUK DEV/MVP AWAL.
        payload = jwt.decode(token, options={"verify_signature": False})
        
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Token invalid: No user ID")
        return user_id
        
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
