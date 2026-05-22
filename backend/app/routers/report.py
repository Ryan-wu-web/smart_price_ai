import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import ReportRequest, ReportResponse
from app.services.report import ReportService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["report"])


@router.post("/report", response_model=ReportResponse)
async def report(request: ReportRequest):
    try:
        service = ReportService()
        return await service.generate_report(
            request.product_name, request.best_choice, request.alternatives
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"report failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
