import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import FilterRequest, FilterResponse
from app.services.filtering import FilteringService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["filter"])


@router.post("/filter", response_model=FilterResponse)
async def filter(request: FilterRequest):
    try:
        service = FilteringService()
        filters = await service.parse_filter(request.query_text)
        return FilterResponse(filters=filters)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"filter failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
