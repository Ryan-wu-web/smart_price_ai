import logging

from fastapi import Depends, APIRouter, HTTPException, Query

from app.core.base_api_client import ModelError
from app.core.dependencies import get_llm_client
from app.core.llm_client import LLMClient
from app.models.schemas import SuggestResponse
from app.services.suggestion import SuggestionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["suggest"])


@router.get("/suggest", response_model=SuggestResponse)
async def suggest(
    category: str = Query(..., description="商品品类"),
    brand: str = Query(default="", description="品牌"),
    color: str = Query(default="", description="颜色"),
    llm_client: LLMClient = Depends(get_llm_client),
):
    try:
        service = SuggestionService(llm_client=llm_client)
        cards = await service.generate_cards(category, brand, color)
        return SuggestResponse(cards=cards)
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="Internal server error")
