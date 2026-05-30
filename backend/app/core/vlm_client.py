from typing import Optional

from app.core.base_api_client import BaseAPIClient


class VLMClient(BaseAPIClient):
    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        super().__init__(api_key=api_key, endpoint=endpoint)

    async def describe_image(
        self,
        image_base64: str,
        prompt: str = (
            "你是一位专业的商品识别专家。请观察图片并提取以下信息，按固定格式输出：\n\n"
            "品牌：（如果能识别出品牌logo或文字，填写品牌名；否则写'未知'）\n"
            "品类：（如运动鞋、手机、口红等，必须填写）\n"
            "颜色：（主色调，如纯白色、黑色、红色等）\n"
            "材质：（如皮革、棉、金属、塑料等，无法识别写'未知'）\n"
            "款式：（如低帮板鞋、连衣裙、无线耳机等）\n\n"
            "约束：\n"
            "- 每个字段单独一行，格式严格为'字段名：内容'\n"
            "- 如果无法识别某个字段，明确写'未知'，不要猜测\n"
            "- 不要输出任何解释性文字，只输出上述5行\n\n"
            "示例1（完整识别）：\n"
            "品牌：Nike\n"
            "品类：运动鞋\n"
            "颜色：纯白色\n"
            "材质：皮革\n"
            "款式：低帮板鞋\n\n"
            "示例2（部分未知）：\n"
            "品牌：未知\n"
            "品类：手提包\n"
            "颜色：黑色\n"
            "材质：未知\n"
            "款式：单肩包"
        ),
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
