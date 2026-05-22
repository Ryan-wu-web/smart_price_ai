import json
from typing import Any, Optional

from app.core.base_api_client import BaseAPIClient


class LLMClient(BaseAPIClient):
    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        super().__init__(api_key=api_key, endpoint=endpoint)

    async def chat_json(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.3,
        max_tokens: int = 2048,
    ) -> dict[str, Any]:
        content = await self.chat(messages, temperature=temperature, max_tokens=max_tokens)
        text = content.strip()
        if text.startswith("```"):
            lines = text.splitlines()
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            text = "\n".join(lines).strip()
        return json.loads(text)
