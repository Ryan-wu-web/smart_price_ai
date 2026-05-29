import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import TrendResponse
from app.services.trend import TrendService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["trend"])


@router.get("/trend/{product_id}", response_model=TrendResponse)
async def trend(product_id: str):
    try:
        service = TrendService()
        # 使用 product_id 的 hash 生成稳定基准价格（500-1500）
        base_price = 500 + (hash(product_id) % 1000)
        history = service._generate_mock_history(product_id, float(base_price))
        return service.analyze_trend_sync(product_id, history)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"trend failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
