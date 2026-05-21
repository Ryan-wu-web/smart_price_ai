from fastapi import APIRouter, HTTPException

from app.models.schemas import RecognizeRequest, RecognizeResponse
from app.services.recognition import RecognitionService

router = APIRouter(prefix="/api/v1", tags=["recognize"])


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize(request: RecognizeRequest):
    try:
        service = RecognitionService()
        return await service.recognize(request.image_base64)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
