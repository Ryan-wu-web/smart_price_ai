from typing import Optional

from app.core.base_api_client import BaseAPIClient


class VLMClient(BaseAPIClient):
    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        super().__init__(api_key=api_key, endpoint=endpoint)

    async def describe_image(
        self,
        image_base64: str,
        prompt: str = "请详细描述这张图片中的物品，包括品牌、品类、颜色、材质、款式等关键信息。",
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> str:
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
                    },
                ],
            }
        ]
        data = await self._post(messages, temperature, max_tokens)
        return data["choices"][0]["message"]["content"]
