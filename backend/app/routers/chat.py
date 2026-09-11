from contextlib import aclosing
import json
import logging

from fastapi import Depends, APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from app.core.base_api_client import ModelError
from app.core.dependencies import get_llm_client
from app.core.llm_client import LLMClient
from app.models.schemas import ChatRequest, ChatResponse
from app.services.chat import ChatService
from app.services.sessions import SessionError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["chat"])


@router.post("/chat", response_model=ChatResponse, response_model_exclude_none=True, response_model_by_alias=False)
async def chat(request: ChatRequest, llm_client: LLMClient = Depends(get_llm_client)):
    try:
        service = ChatService(llm_client=llm_client)
        result = await service.chat(
            request.message, request.session_id, request.current_product
        )
        return ChatResponse(**result)
    except SessionError as exc:
        logger.warning("session_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="服务暂时不可用，请稍后重试。")


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest, llm_client: LLMClient = Depends(get_llm_client)):
    """SSE 流式聊天：逐字返回 AI 回复。"""
    try:
        service = ChatService(llm_client=llm_client)

        # Read-only preflight reports broken sessions before SSE headers are sent.
        # The locked service reload remains authoritative for concurrent turns.
        if request.session_id is not None:
            service.store.load(request.session_id)

        async def event_generator():
            try:
                async with aclosing(service.chat_stream(
                    request.message, request.session_id, request.current_product
                )) as source:
                    async for chunk in source:
                        yield f"data: {chunk}\n\n"
            except (SessionError, ModelError) as exc:
                logger.warning("chat_stream_failed code=%s", exc.code)
                # Legacy-compatible terminal failure; typed error/end protocol is Phase 1C.
                payload = {"done": True, "error": str(exc), "reply": "", "action": "none", "action_data": {}}
                yield "data: " + json.dumps(payload, ensure_ascii=False) + "\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
        )
    except SessionError as exc:
        logger.warning("session_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="服务暂时不可用，请稍后重试。")
