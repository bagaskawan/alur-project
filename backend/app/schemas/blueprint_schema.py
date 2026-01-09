from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import date

# 1. Level Terkecil: Task di dalam kartu
class BlueprintTaskItem(BaseModel):
    title: str
    estimated_duration: int = 60  # Default 60 menit
    energy_required: str = "MEDIUM"

# 2. Level Menengah: Phase/Pillar (Kartu yang di-swipe)
class BlueprintPhase(BaseModel):
    phase_name: str       # Contoh: "Bulan 1: Fondasi"
    focus: str            # Contoh: "Belajar Syntax Python"
    tasks: List[BlueprintTaskItem]

# 3. Level Teratas: Payload Utama dari Frontend
class BlueprintCreateRequest(BaseModel):
    user_id: str
    main_goal_title: str  # Contoh: "Menjadi AI Engineer" (Hasil Final Negosiasi)
    strategy_method: str  # Contoh: "PROJECT_180", "SPRINT_MODE"
    strategy_details: Optional[Dict[str, Any]] = None # [BARU] Metadata strategi
    start_date: date
    end_date: date
    phases: List[BlueprintPhase]
