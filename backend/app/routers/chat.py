from contextlib import aclosing
import json
import logging

from fastapi import Depends, APIRouter, HTTPException, Request
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
async def chat(request: ChatRequest, http_request: Request, llm_client: LLMClient = Depends(get_llm_client)):
    try:
        service = ChatService(llm_client=llm_client,
            catalog=getattr(http_request.app.state, "product_catalog", None),
            retriever=getattr(http_request.app.state, "product_retriever", None))
        result = await service.chat(
            request.message, request.session_id, request.current_product, request.shopping
        )
        return ChatResponse(**result)
    except SessionError as exc:
        logger.warning("session_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except ModelError as exc:
        logger.warning("model_request_failed code=%s", exc.code)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except TimeoutError:
        raise HTTPException(status_code=504, detail="等待购物决策超时，本轮未保存，请稍后重试。") from None
    except HTTPException:
        raise
    except Exception as e:
        logger.error("request_failed type=%s", type(e).__name__)
        raise HTTPException(status_code=500, detail="服务暂时不可用，请稍后重试。")


@router.post("/chat/stream")
async def chat_stream(request: ChatRequest, http_request: Request, llm_client: LLMClient = Depends(get_llm_client)):
    """SSE v1：状态、文本增量、结构结果、错误及结束事件。"""
    try:
        service = ChatService(llm_client=llm_client,
            catalog=getattr(http_request.app.state, "product_catalog", None),
            retriever=getattr(http_request.app.state, "product_retriever", None))

        # Read-only preflight reports broken sessions before SSE headers are sent.
        # The locked service reload remains authoritative for concurrent turns.
        if request.session_id is not None:
            service.store.load(request.session_id)

        async def event_generator():
            async with aclosing(service.chat_stream(
                request.message, request.session_id, request.current_product, request.shopping
            )) as source:
                async for chunk in source:
                    payload = json.loads(chunk)
                    yield f"event: {payload['type']}\nid: {payload['seq']}\ndata: {chunk}\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
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


@router.get("/chat/sessions/{session_id}")
def read_shopping_session(session_id: str):
    """Local single-user resume; opaque session ID is not production authentication."""
    from app.models.schemas import validate_session_id
    from app.services.sessions import SessionStore
    from app.services import chat as chat_module
    try:
        validate_session_id(session_id)
        store = SessionStore(chat_module.SESSION_DIR)
        if not store.path(session_id).exists():
            raise HTTPException(status_code=404, detail="会话不存在，请开始新对话。")
        state = store.load(session_id)
        return {"session_id": session_id, "workflow": state.workflow,
                "current_product": state.current_product, "summary": state.summary,
                "messages": state.messages[-20:]}
    except SessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from None
    except ValueError:
        raise HTTPException(status_code=422, detail="会话 ID 格式无效。") from None
