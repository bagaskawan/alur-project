from fastapi import APIRouter, Depends, HTTPException
from sqlmodel.ext.asyncio.session import AsyncSession
from app.core.database import get_session
from app.models.all_models import Goal, Task, GrowthCycle, Profile
from app.schemas.blueprint_schema import BlueprintCreateRequest
import uuid

router = APIRouter()

@router.post("/blueprint/save")
async def save_blueprint_structure(
    request: BlueprintCreateRequest,
    session: AsyncSession = Depends(get_session)
):
    """
    Menyimpan hasil Blueprint AI ke dalam struktur database:
    GrowthCycle -> Main Goal -> Sub Goals (Phases) -> Tasks
    Transaction Atomic: Jika satu gagal, semua batal.
    """
    try:
        user_uuid = uuid.UUID(request.user_id)

        # 1. CREATE GROWTH CYCLE (Wadah Utama)
        # Menandai periode strategi
        new_cycle = GrowthCycle(
            user_id=user_uuid,
            title=f"{request.strategy_method}: {request.main_goal_title}",
            type=request.strategy_method, # [MODIFIED] Now simple string
            start_date=request.start_date,
            end_date=request.end_date,
            is_active=True,
            theme=request.main_goal_title
        )
        session.add(new_cycle)
        await session.flush() # Flush untuk mendapatkan ID cycle

        # 2. CREATE MAIN GOAL (North Star)
        main_goal = Goal(
            user_id=user_uuid,
            cycle_id=new_cycle.id, # Link ke Cycle
            title=request.main_goal_title,
            priority="MAIN_QUEST", # Custom String for priority
            status="IN_PROGRESS",
            progress=0,
            
            # [BARU] Simpan metadata strategi
            framework_type=request.strategy_method, 
            framework_data=request.strategy_details or {} # Data JSON grid/plan
        )
        session.add(main_goal)
        await session.flush() # Flush untuk mendapatkan ID main_goal

        # 3. LOOP PHASES -> CREATE SUB-GOALS
        for phase in request.phases:
            sub_goal = Goal(
                user_id=user_uuid,
                cycle_id=new_cycle.id,
                parent_goal_id=main_goal.id, # Link ke Goal Utama
                title=phase.phase_name,
                description=phase.focus,
                priority="SIDE_QUEST",
                status="IN_PROGRESS"
            )
            session.add(sub_goal)
            await session.flush() # Flush untuk mendapatkan ID sub_goal

            # 4. LOOP TASKS -> CREATE TASKS
            for task_item in phase.tasks:
                new_task = Task(
                    user_id=user_uuid,
                    goal_id=sub_goal.id, # Link ke Sub-Goal (Phase)
                    title=task_item.title,
                    estimated_duration=task_item.estimated_duration,
                    energy_required=task_item.energy_required,
                    status="TODO",
                    is_atomized=False
                )
                session.add(new_task)

        # 5. COMMIT TRANSACTION (Simpan Permanen)
        await session.commit()
        
        return {
            "status": "success", 
            "message": "Blueprint integrated successfully",
            "data": {
                "cycle_id": str(new_cycle.id),
                "main_goal_id": str(main_goal.id)
            }
        }

    except Exception as e:
        await session.rollback() # CRITICAL: Rollback on error
        print(f"❌ Database Save Error: {e}")
        # Return 500 error to frontend
        raise HTTPException(status_code=500, detail=str(e))

from sqlmodel import select

@router.get("/current")
async def get_current_goal(
    user_id: str,
    session: AsyncSession = Depends(get_session)
):
    try:
        user_uuid = uuid.UUID(user_id)
        
        # 1. Cari Cycle Aktif
        statement = select(GrowthCycle).where(
            GrowthCycle.user_id == user_uuid,
            GrowthCycle.is_active == True
        )
        result = await session.exec(statement)
        active_cycle = result.first()
        
        if not active_cycle:
            return {"has_active_plan": False}
            
        # 2. Cari Main Goal
        goal_statement = select(Goal).where(
            Goal.cycle_id == active_cycle.id,
            Goal.priority == "MAIN_QUEST"
        )
        goal_result = await session.exec(goal_statement)
        main_goal = goal_result.first()
        
        if not main_goal:
             return {"has_active_plan": False}
             
        return {
            "has_active_plan": True,
            "cycle": active_cycle,
            "main_goal": {
                "title": main_goal.title,
                "progress": main_goal.progress,
                "framework_type": main_goal.framework_type
            }
        }
    except Exception as e:
        print(f"Error fetching current goal: {e}")
        raise HTTPException(status_code=500, detail=str(e))
