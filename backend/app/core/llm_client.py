from contextlib import aclosing
import json
import logging
import re
from typing import Any

from pydantic import TypeAdapter, ValidationError

from app.config import settings
from app.core.base_api_client import BaseAPIClient, ModelOutputError

logger = logging.getLogger(__name__)


class LLMClient(BaseAPIClient):
    async def chat_json(
        self, messages: list[dict[str, Any]], temperature: float = 0.3,
        max_tokens: int = 2048, *, response_model: Any = None,
    ) -> Any:
        """Validate JSON; at most one repair by default, never retry transport errors.

        Without a schema, preserve the historical dict/list return value.
        With a schema, return its validated Pydantic value.
        """
        adapter = TypeAdapter(response_model if response_model is not None else dict[str, Any] | list[Any])
        prompt = list(messages)
        for attempt in range(settings.model_json_repair_attempts + 1):
            # Transport/envelope errors intentionally stay outside the repair loop.
            content = await self.chat(prompt, temperature=temperature, max_tokens=max_tokens)
            try:
                text = content.strip()
                fence = re.fullmatch(r"```(?:json)?\s*\n?(.*?)\s*```", text, re.DOTALL | re.IGNORECASE)
                if fence:
                    text = fence.group(1)
                return adapter.validate_python(json.loads(text, parse_constant=self._reject_constant))
            except (ValueError, ValidationError, TypeError):
                logger.warning("model_json_validation_failed attempt=%d", attempt + 1)
                if attempt == settings.model_json_repair_attempts:
                    raise ModelOutputError("模型输出格式不符合要求，请重试或补充描述。") from None
                # Do not echo untrusted model output or validation input into logs/prompts.
                prompt = [*messages, {"role": "user", "content": (
                    "上次输出未通过结构校验。请依据原始输入重新生成，不要编造未知属性。"
                    "只输出符合以下 JSON Schema 的 JSON，不要代码围栏或解释："
                    + json.dumps(adapter.json_schema(), ensure_ascii=False)
                )}]
        raise AssertionError("unreachable")

    @staticmethod
    def _reject_constant(value: str):
        raise ValueError("Non-finite JSON number")

    async def chat_stream(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ):
        """
        流式聊天：yield 每一块的文本内容。
        解析火山引擎 SSE 格式：data: {...}
        """
        async with aclosing(self._post_stream(messages, temperature, max_tokens)) as source:
            async for line in source:
                if not line.startswith("data: "):
                    continue
                data = line[6:]  # 去掉 "data: " 前缀
                if data == "[DONE]":
                    break
                try:
                    chunk = json.loads(data)
                    content = (
                        chunk.get("choices", [{}])[0]
                        .get("delta", {})
                        .get("content", "")
                    )
                    if content:
                        yield content
                except (json.JSONDecodeError, IndexError, KeyError):
                    continue
