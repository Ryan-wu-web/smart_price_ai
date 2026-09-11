import logging

from fastapi import Depends, APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from app.core.base_api_client import ModelError
from app.core.dependencies import get_llm_client
from app.core.llm_client import LLMClient
from app.models.schemas import ChatRequest, ChatResponse
from app.services.chat import ChatService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["chat"])


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, llm_client: LLMClient = Depends(get_llm_client)):
    try:
        service = ChatService(llm_client=llm_client)
        result = await service.chat(
            request.message, request.session_id, request.current_product
        )
        return ChatResponse(**result)
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest, llm_client: LLMClient = Depends(get_llm_client)):
    """SSE 流式聊天：逐字返回 AI 回复。"""
    try:
        service = ChatService(llm_client=llm_client)

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
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="Internal server error")
