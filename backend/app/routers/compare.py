from fastapi import APIRouter, HTTPException

from app.models.schemas import CompareQuery, CompareResponse
from app.services.comparison import ComparisonService

router = APIRouter(prefix="/api/v1", tags=["compare"])


import logging

logger = logging.getLogger(__name__)

@router.get("/compare", response_model=CompareResponse)
async def compare(
    category: str,
    brand: str | None = None,
    color: str | None = None,
    sort_by: str | None = None,
):
    logger.info(f"[compare API] params: category={category}, brand={brand}, color={color}, sort_by={sort_by}")
    try:
        query = CompareQuery(category=category, brand=brand, color=color, sort_by=sort_by)
        service = ComparisonService()
        products = service.compare(query)
        logger.info(f"[compare API] returning {len(products)} products")
        return CompareResponse(products=products)
    except Exception as e:
        logger.error(f"[compare API] error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
