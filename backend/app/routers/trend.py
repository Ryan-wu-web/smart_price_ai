from fastapi import APIRouter
from app.models.schemas import TrendResponse
from app.services.trend import TrendService

router = APIRouter(prefix="/api/v1", tags=["trend"])


@router.get("/trend/{product_id}", response_model=TrendResponse)
def trend(product_id: str):
    # Also safe for old client-generated IDs: no claim that the product exists.
    return TrendService().unavailable()
