import base64
import hashlib
import io
import json
import os
import time

from PIL import Image

from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.core.vlm_client import VLMClient
from app.models.schemas import RecognizeResponse, RecognizedObject, RecognizeMultiResponse

MAX_IMAGE_WIDTH = 800
JPEG_QUALITY = 85
CACHE_DIR = "data/cache/recognition"
CACHE_TTL_SECONDS = 7 * 24 * 3600  # 7 天


class RecognitionService:
    def __init__(
        self,
        vlm_client: VLMClient | None = None,
        llm_client: LLMClient | None = None,
    ):
        self.vlm_client = vlm_client or VLMClient()
        self.llm_client = llm_client or LLMClient()

    @staticmethod
    def _cache_key(image_base64: str) -> str:
        return hashlib.md5(image_base64.encode("utf-8")).hexdigest()

    @staticmethod
    def _load_from_cache(image_base64: str) -> RecognizeResponse | None:
        try:
            key = RecognitionService._cache_key(image_base64)
            path = os.path.join(CACHE_DIR, f"{key}.json")
            if not os.path.exists(path):
                return None
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if time.time() - data.get("timestamp", 0) > CACHE_TTL_SECONDS:
                os.remove(path)
                return None
            return RecognizeResponse(**data["result"])
        except Exception:
            return None

    @staticmethod
    def _save_to_cache(image_base64: str, result: RecognizeResponse) -> None:
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            key = RecognitionService._cache_key(image_base64)
            path = os.path.join(CACHE_DIR, f"{key}.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(
                    {"timestamp": time.time(), "result": result.model_dump()},
                    f,
                    ensure_ascii=False,
                )
        except Exception:
            pass

    @staticmethod
    def _compress_image(image_base64: str) -> str:
        """将图片压缩到最大宽度 MAX_IMAGE_WIDTH，返回新的 base64。"""
        try:
            raw = base64.b64decode(image_base64)
            img = Image.open(io.BytesIO(raw))
            # 转换为 RGB（去除透明通道）
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            w, h = img.size
            if w > MAX_IMAGE_WIDTH:
                ratio = MAX_IMAGE_WIDTH / w
                new_size = (MAX_IMAGE_WIDTH, int(h * ratio))
                img = img.resize(new_size, Image.LANCZOS)
            buffer = io.BytesIO()
            img.save(buffer, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            return base64.b64encode(buffer.getvalue()).decode("utf-8")
        except Exception:
            # 压缩失败时返回原图
            return image_base64

    async def recognize(self, image_base64: str) -> RecognizeResponse:
        """单次调用主路径，失败时 fallback 到两阶段。"""
        # 检查缓存
        cached = self._load_from_cache(image_base64)
        if cached:
            return cached

        image_base64 = self._compress_image(image_base64)
        # 主路径：直接调用 LLM，传入图片 + 识别 Prompt
        prompt = (
            "你是一位专业的商品识别专家。请观察图片中的商品，"
            "直接以 JSON 格式输出：name（商品名称）、brand（品牌，未知为空字符串）、"
            "category（品类）、color（主色调）、material（材质）、style（款式）。\n\n"
            "约束：\n"
            "- 如果无法识别品牌，brand 设为空字符串\n"
            "- category 必须是具体品类\n"
            "- 只输出 JSON，不要任何解释\n\n"
            "示例：\n"
            '{"name": "Nike Air Force 1 白色 42码", "brand": "Nike", "category": "运动鞋", "color": "纯白色", "material": "皮革", "style": "低帮板鞋"}'
        )
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}},
                ],
            }
        ]

        try:
            result = await self.llm_client.chat_json(messages, temperature=0.3)
            parsed = self._parse_recognize_result(result)
            self._save_to_cache(image_base64, parsed)
            return parsed
        except Exception:
            # Fallback：两阶段识别
            parsed = await self._recognize_two_stage(image_base64)
            self._save_to_cache(image_base64, parsed)
            return parsed

    async def _recognize_two_stage(self, image_base64: str) -> RecognizeResponse:
        """原始两阶段识别作为 fallback。"""
        description = await self.vlm_client.describe_image(image_base64)
        prompt = PromptEngine.recognize(description)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages, temperature=0.3)
        return self._parse_recognize_result(result)

    def _parse_recognize_result(self, result: dict) -> RecognizeResponse:
        return RecognizeResponse(
            name=result.get("name", ""),
            brand=result.get("brand", ""),
            category=result.get("category", ""),
            color=result.get("color", ""),
            material=result.get("material", ""),
            style=result.get("style", ""),
        )

    async def recognize_multiple(self, image_base64: str) -> RecognizeMultiResponse:
        """多目标识别：识别图中所有商品。"""
        image_base64 = self._compress_image(image_base64)
        prompt = (
            "你是一位专业的商品识别专家。请观察图片，识别图中所有独立的商品。\n"
            "对每件商品，输出以下字段：\n"
            "- name：商品名称\n"
            "- brand：品牌（无法识别写空字符串）\n"
            "- category：品类\n"
            "- color：主色调\n"
            "- bbox：检测框位置，格式为 {\"x\": 0-1, \"y\": 0-1, \"w\": 0-1, \"h\": 0-1}\n\n"
            "约束：\n"
            "- 只输出 JSON 数组，不要任何解释文字\n"
            "- 如果图中没有商品，输出空数组 []\n"
            "- x,y 是检测框左上角坐标，w,h 是宽度和高度（相对图片的归一化坐标 0-1）\n\n"
            "示例：\n"
            '[{"name": "怡宝纯净水 2.08L", "brand": "怡宝", "category": "饮料", "color": "透明", "bbox": {"x": 0.15, "y": 0.2, "w": 0.4, "h": 0.5}}]'
        )
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}},
                ],
            }
        ]

        try:
            result = await self.llm_client.chat_json(messages, temperature=0.3)
            if not isinstance(result, list):
                return RecognizeMultiResponse(objects=[])

            objects = []
            for item in result:
                if not isinstance(item, dict):
                    continue
                bbox = item.get("bbox", {})
                if isinstance(bbox, list) and len(bbox) >= 4:
                    bbox = {"x": bbox[0], "y": bbox[1], "w": bbox[2], "h": bbox[3]}
                elif not isinstance(bbox, dict):
                    bbox = {}
                objects.append(
                    RecognizedObject(
                        name=item.get("name", "未知商品"),
                        brand=item.get("brand", ""),
                        category=item.get("category", "未知"),
                        color=item.get("color", ""),
                        bbox=bbox,
                    )
                )
            return RecognizeMultiResponse(objects=objects)
        except Exception:
            return RecognizeMultiResponse(objects=[])
