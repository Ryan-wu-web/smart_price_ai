from fastapi import APIRouter, HTTPException

from app.models.schemas import ReportRequest, ReportResponse
from app.services.report import ReportService

router = APIRouter(prefix="/api/v1", tags=["report"])


@router.post("/report", response_model=ReportResponse)
async def report(request: ReportRequest):
    try:
        service = ReportService()
        return await service.generate_report(
            request.product_name, request.best_choice, request.alternatives
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
