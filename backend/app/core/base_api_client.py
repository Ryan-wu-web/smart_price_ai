from typing import Any, Optional

import httpx

from app.config import settings


class BaseAPIClient:
    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        self.api_key = api_key or settings.volcengine_api_key
        self.endpoint = endpoint or settings.volcengine_endpoint
        # 复用同一个 httpx.AsyncClient，避免每次请求新建 TCP 连接
        self._client = httpx.AsyncClient(timeout=60.0)

    def _build_headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    def _build_payload(
        self,
        messages: list[dict[str, Any]],
        temperature: float,
        max_tokens: int,
    ) -> dict[str, Any]:
        return {
            "model": settings.volcengine_model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

    async def _post(
        self,
        messages: list[dict[str, Any]],
        temperature: float,
        max_tokens: int,
    ) -> dict[str, Any]:
        headers = self._build_headers()
        payload = self._build_payload(messages, temperature, max_tokens)
        response = await self._client.post(self.endpoint, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()

    async def _post_stream(
        self,
        messages: list[dict[str, Any]],
        temperature: float,
        max_tokens: int,
    ):
        """流式 POST：yield 每一行 SSE 数据。"""
        headers = self._build_headers()
        payload = self._build_payload(messages, temperature, max_tokens)
        payload["stream"] = True
        async with self._client.stream(
            "POST", self.endpoint, headers=headers, json=payload
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                yield line

    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> str:
        data = await self._post(messages, temperature, max_tokens)
        return data["choices"][0]["message"]["content"]
