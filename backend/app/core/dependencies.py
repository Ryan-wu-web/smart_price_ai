from fastapi import Request

from app.core.llm_client import LLMClient
from app.core.vlm_client import VLMClient


def get_llm_client(request: Request) -> LLMClient:
    return LLMClient(client=request.app.state.model_http)


def get_vlm_client(request: Request) -> VLMClient:
    return VLMClient(client=request.app.state.model_http)
