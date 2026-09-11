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
        """Read complete upstream SSE frames; malformed or truncated streams fail closed."""
        data_lines = []
        frame_chars = 0
        stopped = False
        async with aclosing(self._post_stream(messages, temperature, max_tokens)) as source:
            async for line in source:
                if line != "":
                    if line.startswith("data:"):
                        value = line[5:]
                        if value.startswith(" "):
                            value = value[1:]
                        data_lines.append(value)
                        frame_chars += len(value)
                        if frame_chars > 128000:
                            raise ModelOutputError("模型响应过长，请重试。")
                    continue
                if not data_lines:
                    continue
                data = "\n".join(data_lines)
                data_lines = []
                frame_chars = 0
                if data == "[DONE]":
                    if not stopped:
                        raise ModelOutputError("模型回复未正常完成，本轮未保存，请重试。")
                    return
                try:
                    chunk = json.loads(data, parse_constant=self._reject_constant)
                    if not isinstance(chunk, dict) or "error" in chunk:
                        raise ValueError("Provider error")
                    choices = chunk["choices"]
                    if not isinstance(choices, list):
                        raise ValueError("Invalid choices")
                    if not choices and isinstance(chunk.get("usage"), dict):
                        continue
                    if len(choices) != 1:
                        raise ValueError("Invalid choice count")
                    choice = choices[0]
                    if choice.get("index", 0) != 0 or stopped:
                        raise ValueError("Unexpected choice")
                    delta = choice["delta"]
                    if not isinstance(delta, dict) or delta.get("tool_calls") or delta.get("function_call"):
                        raise ValueError("Unsupported tool call")
                    content = delta.get("content")
                    if content is not None and not isinstance(content, str):
                        raise ValueError("Invalid content")
                    finish = choice.get("finish_reason")
                    if finish not in (None, "stop"):
                        raise ValueError("Incomplete or unsupported completion")
                    stopped = finish == "stop"
                except (ValueError, KeyError, TypeError, AttributeError):
                    raise ModelOutputError("模型流式响应无效或未完成，本轮未保存，请重试。") from None
                if content:
                    yield content
        raise ModelOutputError("模型连接提前结束，本轮未保存，请重试。")
