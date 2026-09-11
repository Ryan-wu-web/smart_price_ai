import logging

from fastapi import APIRouter, Depends, HTTPException

from app.core.base_api_client import ModelError
from app.core.dependencies import get_llm_client, get_vlm_client
from app.core.llm_client import LLMClient
from app.core.vlm_client import VLMClient

from app.models.schemas import RecognizeRequest, RecognizeResponse, RecognizeMultiResponse
from app.services.recognition import InvalidImageError, RecognitionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["recognize"])


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize(
    request: RecognizeRequest,
    llm_client: LLMClient = Depends(get_llm_client),
    vlm_client: VLMClient = Depends(get_vlm_client),
):
    try:
        service = RecognitionService(vlm_client=vlm_client, llm_client=llm_client)
        return await service.recognize(request.image_base64)
    except InvalidImageError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None
    except ModelError as exc:
        logger.warning("recognition_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("recognition_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="识别暂时失败，请稍后重试。")


@router.post("/recognize/multi", response_model=RecognizeMultiResponse)
async def recognize_multi(
    request: RecognizeRequest,
    llm_client: LLMClient = Depends(get_llm_client),
    vlm_client: VLMClient = Depends(get_vlm_client),
):
    try:
        service = RecognitionService(vlm_client=vlm_client, llm_client=llm_client)
        return await service.recognize_multiple(request.image_base64)
    except InvalidImageError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None
    except ModelError as exc:
        logger.warning("recognition_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("recognition_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="识别暂时失败，请稍后重试。")
