import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import RecognizeRequest, RecognizeResponse
from app.services.recognition import RecognitionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["recognize"])


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize(request: RecognizeRequest):
    try:
        service = RecognitionService()
        return await service.recognize(request.image_base64)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"recognize failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
