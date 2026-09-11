"""Additive recommendation API; legacy chat is deliberately not redirected yet."""
import logging

from fastapi import APIRouter, HTTPException, Request

from app.models.recommendations import RecommendationRequest, RecommendationResponse
from app.routers.knowledge import CatalogDependency
from app.services.recommendations import ProductRecommender

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/recommendations", tags=["sample-recommendations"])


@router.post("", response_model=RecommendationResponse)
def recommend(body: RecommendationRequest, request: Request, catalog: CatalogDependency):
    try:
        return ProductRecommender(catalog, getattr(request.app.state, "product_retriever", None)).recommend(body)
    except Exception as exc:
        logger.error("recommendation_failed type=%s", type(exc).__name__)
        raise HTTPException(status_code=503, detail={
            "code": "RECOMMENDATION_UNAVAILABLE",
            "message": "样例推荐暂时不可用，请稍后重试；未修改你的条件。",
        }) from None
