from fastapi import APIRouter, HTTPException

from app.models.schemas import CompareQuery, CompareResponse
from app.services.comparison import ComparisonService

router = APIRouter(prefix="/api/v1", tags=["compare"])


@router.get("/compare", response_model=CompareResponse)
async def compare(
    category: str,
    brand: str | None = None,
    color: str | None = None,
    sort_by: str | None = None,
):
    try:
        query = CompareQuery(category=category, brand=brand, color=color, sort_by=sort_by)
        service = ComparisonService()
        products = service.compare(query)
        return CompareResponse(products=products)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
