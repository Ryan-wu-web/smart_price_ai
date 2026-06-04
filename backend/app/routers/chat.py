import logging

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

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


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    """SSE 流式聊天：逐字返回 AI 回复。"""
    try:
        service = ChatService()

        async def event_generator():
            async for chunk in service.chat_stream(
                request.message, request.session_id, request.current_product
            ):
                # 确保 chunk 中没有换行符，保护 SSE 单行格式
                safe_chunk = chunk.replace("\n", " ").replace("\r", "")
                yield f"data: {safe_chunk}\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
        )
    except Exception as e:
        logger.error(f"chat stream failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
