from typing import Any

from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine


class FilteringService:
    def __init__(self, llm_client: LLMClient | None = None):
        self.llm_client = llm_client or LLMClient()

    async def parse_filter(self, query_text: str) -> dict[str, Any]:
        prompt = PromptEngine.filter_parse(query_text)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages)
        if not isinstance(result, dict):
            return {}
        return result
