from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.core.vlm_client import VLMClient
from app.models.schemas import RecognizeResponse


class RecognitionService:
    def __init__(
        self,
        vlm_client: VLMClient | None = None,
        llm_client: LLMClient | None = None,
    ):
        self.vlm_client = vlm_client or VLMClient()
        self.llm_client = llm_client or LLMClient()

    async def recognize(self, image_base64: str) -> RecognizeResponse:
        description = await self.vlm_client.describe_image(image_base64)
        prompt = PromptEngine.recognize(description)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages)
        return RecognizeResponse(
            name=result.get("name", ""),
            brand=result.get("brand", ""),
            category=result.get("category", ""),
            color=result.get("color", ""),
            material=result.get("material", ""),
            style=result.get("style", ""),
        )
