from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

import httpx
from pydantic import BaseModel, Field, ValidationError

from app.config import settings


class ModelError(RuntimeError):
    """Safe public error; never contains provider responses or credentials."""

    code = "model_unavailable"
    status_code = 502


class ModelTimeoutError(ModelError):
    code = "model_timeout"
    status_code = 504


class ModelHTTPError(ModelError):
    code = "model_http_error"


class ModelOutputError(ModelError):
    code = "model_output_invalid"


class _Message(BaseModel):
    content: str = Field(min_length=1)


class _Choice(BaseModel):
    message: _Message


class _Completion(BaseModel):
    choices: list[_Choice] = Field(min_length=1)


def create_http_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=httpx.Timeout(
            settings.model_read_timeout_seconds,
            connect=settings.model_connect_timeout_seconds,
            write=settings.model_write_timeout_seconds,
            pool=settings.model_pool_timeout_seconds,
        ),
        limits=httpx.Limits(
            max_connections=settings.model_max_connections,
            max_keepalive_connections=settings.model_max_connections,
        ),
        follow_redirects=False,
    )


class BaseAPIClient:
    def __init__(
        self, api_key: str | None = None, endpoint: str | None = None,
        *, client: httpx.AsyncClient | None = None,
    ):
        self.api_key = api_key if api_key is not None else settings.volcengine_api_key
        self.endpoint = endpoint if endpoint is not None else settings.volcengine_endpoint
        self._client = client
        self._owns_client = client is None
        self._closed = False

    def _http(self) -> httpx.AsyncClient:
        if self._closed:
            raise RuntimeError("Model client is closed")
        if self._client is None:
            self._client = create_http_client()
        return self._client

    async def aclose(self) -> None:
        if self._owns_client and self._client is not None:
            await self._client.aclose()
        self._closed = True

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        await self.aclose()

    def _build_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}

    def _build_payload(self, messages: list[dict[str, Any]], temperature: float, max_tokens: int) -> dict[str, Any]:
        return {"model": settings.volcengine_model, "messages": messages,
                "temperature": temperature, "max_tokens": max_tokens}

    @staticmethod
    @asynccontextmanager
    async def _safe_transport() -> AsyncIterator[None]:
        try:
            yield
        except httpx.TimeoutException:
            raise ModelTimeoutError("模型响应超时，请稍后重试。") from None
        except httpx.HTTPStatusError:
            raise ModelHTTPError("模型服务暂时不可用，请稍后重试。") from None
        except httpx.RequestError:
            raise ModelError("暂时无法连接模型服务，请稍后重试。") from None

    async def _post(self, messages: list[dict[str, Any]], temperature: float, max_tokens: int) -> dict[str, Any]:
        async with self._safe_transport():
            response = await self._http().post(
                self.endpoint, headers=self._build_headers(),
                json=self._build_payload(messages, temperature, max_tokens),
            )
            response.raise_for_status()
            try:
                data = response.json()
                if not isinstance(data, dict):
                    raise ValueError
                return data
            except ValueError:
                raise ModelOutputError("模型返回了无法读取的响应，请重试。") from None

    async def _post_stream(self, messages: list[dict[str, Any]], temperature: float, max_tokens: int):
        payload = self._build_payload(messages, temperature, max_tokens)
        payload["stream"] = True
        async with self._safe_transport():
            async with self._http().stream(
                "POST", self.endpoint, headers=self._build_headers(), json=payload,
            ) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    yield line

    async def chat(self, messages: list[dict[str, Any]], temperature: float = 0.7, max_tokens: int = 2048) -> str:
        data = await self._post(messages, temperature, max_tokens)
        try:
            return _Completion.model_validate(data).choices[0].message.content
        except ValidationError:
            raise ModelOutputError("模型未返回有效文本，请重试。") from None
