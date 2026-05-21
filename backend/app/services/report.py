from typing import Any

from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.models.schemas import ReportResponse


class ReportService:
    def __init__(self, llm_client: LLMClient | None = None):
        self.llm_client = llm_client or LLMClient()

    async def generate_report(
        self, product_name: str, best_choice: dict[str, Any], alternatives: list[dict[str, Any]]
    ) -> ReportResponse:
        prompt = PromptEngine.report_generation(product_name, best_choice, alternatives)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages)
        return ReportResponse(
            summary=result.get("summary", ""),
            pros=result.get("pros", []),
            cons=result.get("cons", []),
            recommendation=result.get("recommendation", ""),
        )
