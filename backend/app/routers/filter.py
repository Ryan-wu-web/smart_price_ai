import logging

from fastapi import Depends, APIRouter, HTTPException

from app.core.base_api_client import ModelError
from app.core.dependencies import get_llm_client
from app.core.llm_client import LLMClient
from app.models.schemas import FilterRequest, FilterResponse
from app.services.filtering import FilteringService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["filter"])


@router.post("/filter", response_model=FilterResponse)
async def filter(request: FilterRequest, llm_client: LLMClient = Depends(get_llm_client)):
    try:
        service = FilteringService(llm_client=llm_client)
        filters = await service.parse_filter(request.query_text)
        return FilterResponse(filters=filters)
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="Internal server error")
