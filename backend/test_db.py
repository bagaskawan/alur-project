import asyncio
from sqlalchemy import text
from app.core.database import engine

async def check_db_connection():
    try:
        print("🔄 Mencoba menghubungi Supabase...")
        
        # Kita buka koneksi manual
        async with engine.connect() as conn:
            # Jalankan query paling ringan: "SELECT 1"
            result = await conn.execute(text("SELECT 1"))
            print(f"✅ KONEKSI SUKSES! Database merespon: {result.scalar()}")
            
    except Exception as e:
        print("❌ KONEKSI GAGAL!")
        print(f"Error Detail: {e}")
    finally:
        # Tutup mesin agar tidak menggantung
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(check_db_connection())