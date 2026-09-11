from fastapi import APIRouter, Query
from app.models.schemas import SuggestResponse
from app.services.suggestion import SuggestionService

router = APIRouter(prefix="/api/v1", tags=["suggest"])


@router.get("/suggest", response_model=SuggestResponse)
async def suggest(
    category: str = Query(min_length=1, max_length=80),
    brand: str = Query(default="", max_length=80),
    color: str = Query(default="", max_length=80),
):
    return SuggestResponse(cards=await SuggestionService().generate_cards(category, brand, color))
