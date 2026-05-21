from fastapi import APIRouter, HTTPException

from app.models.schemas import TrendResponse
from app.services.trend import TrendService

router = APIRouter(prefix="/api/v1", tags=["trend"])


@router.get("/trend/{product_id}", response_model=TrendResponse)
async def trend(product_id: str):
    try:
        service = TrendService()
        # Mock history data based on product_id
        history = [
            {"date": "2024-01-01", "price": 1000.0, "platform": "淘宝"},
            {"date": "2024-02-01", "price": 950.0, "platform": "京东"},
            {"date": "2024-03-01", "price": 900.0, "platform": "天猫"},
        ]
        return service.analyze_trend_sync(product_id, history)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
