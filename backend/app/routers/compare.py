import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import CompareQuery, CompareResponse
from app.services.comparison import ComparisonService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["compare"])


@router.get("/compare", response_model=CompareResponse)
async def compare(
    category: str,
    brand: str | None = None,
    color: str | None = None,
    sort_by: str | None = None,
    filter_mode: str | None = None,
):
    logger.info(f"[compare API] params: category={category}, brand={brand}, color={color}, sort_by={sort_by}, filter_mode={filter_mode}")
    try:
        query = CompareQuery(category=category, brand=brand, color=color, sort_by=sort_by, filter_mode=filter_mode)
        service = ComparisonService()
        products = service.compare(query)
        logger.info(f"[compare API] returning {len(products)} products")
        return CompareResponse(products=products)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"compare failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
