from typing import Optional

import httpx

from app.config import settings


class VLMClient:
    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        self.api_key = api_key or settings.volcengine_api_key
        self.endpoint = endpoint or settings.volcengine_endpoint

    async def describe_image(
        self,
        image_base64: str,
        prompt: str = "请详细描述这张图片中的物品，包括品牌、品类、颜色、材质、款式等关键信息。",
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> str:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
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
        payload = {
            "model": settings.volcengine_model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(self.endpoint, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
