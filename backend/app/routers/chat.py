import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import ChatRequest, ChatResponse
from app.services.chat import ChatService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["chat"])


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        service = ChatService()
        result = await service.chat(
            request.message, request.session_id, request.current_product
        )
        return ChatResponse(**result)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"chat failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
