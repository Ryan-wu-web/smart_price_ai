from fastapi import APIRouter, HTTPException, Query

from app.models.schemas import SuggestResponse
from app.services.suggestion import SuggestionService

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
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
