import logging

from fastapi import APIRouter, HTTPException, Query

from app.models.schemas import SuggestResponse
from app.services.suggestion import SuggestionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["suggest"])


@router.get("/suggest", response_model=SuggestResponse)
async def suggest(
    category: str = Query(..., description="商品品类"),
    brand: str = Query(default="", description="品牌"),
    color: str = Query(default="", description="颜色"),
):
    try:
        service = SuggestionService()
        cards = await service.generate_cards(category, brand, color)
        return SuggestResponse(cards=cards)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"suggest failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
