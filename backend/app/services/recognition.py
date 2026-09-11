import base64
import binascii
import hashlib
import io
import json
import logging
import os
from pathlib import Path
import tempfile
import time

from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import ValidationError

from app.config import settings
from app.core.base_api_client import ModelOutputError
from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.core.vlm_client import VLMClient
from app.models.schemas import RecognizeResponse, RecognizedObject, RecognizeMultiResponse

logger = logging.getLogger(__name__)
MAX_IMAGE_WIDTH = 600
MAX_IMAGE_PIXELS = 20_000_000
JPEG_QUALITY = 75
CACHE_DIR = "data/cache/recognition"
CACHE_TTL_SECONDS = 7 * 24 * 3600
# Bump when prompts, output schemas or preprocessing semantics change.
CACHE_VERSION = "recognition-v2"


class InvalidImageError(ValueError):
    pass


class RecognitionService:
    def __init__(self, vlm_client: VLMClient | None = None, llm_client: LLMClient | None = None):
        self.vlm_client = vlm_client or VLMClient()
        self.llm_client = llm_client or LLMClient()

    @staticmethod
    def _decode_image(image_base64: str) -> bytes:
        try:
            return base64.b64decode(image_base64, validate=True)
        except (binascii.Error, ValueError):
            raise InvalidImageError("图片编码无效，请重新选择或拍摄图片。") from None

    def _cache_key(self, raw: bytes, mode: str) -> str:
        # Do not use dHash: different images (e.g. solid black/white) can collide.
        # Hash original bytes, not lossy JPEG output, to avoid compression aliases.
        identity = json.dumps([
            CACHE_VERSION, mode, settings.volcengine_model,
            self.llm_client.endpoint, getattr(self.vlm_client, "endpoint", ""),
            MAX_IMAGE_WIDTH, JPEG_QUALITY, hashlib.sha256(raw).hexdigest(),
        ], ensure_ascii=False)
        return hashlib.sha256(identity.encode("utf-8")).hexdigest()

    @staticmethod
    def _load_from_cache(cache_key: str, mode: str):
        try:
            data = json.loads((Path(CACHE_DIR) / f"{cache_key}.json").read_text(encoding="utf-8"))
            if not isinstance(data, dict) or data.get("version") != CACHE_VERSION or data.get("mode") != mode:
                return None
            timestamp = data["timestamp"]
            if type(timestamp) not in (int, float) or not 0 <= time.time() - timestamp <= CACHE_TTL_SECONDS:
                return None
            schema = RecognizeResponse if mode == "single" else RecognizeMultiResponse
            return schema.model_validate(data["result"])
        except (OSError, ValueError, KeyError, TypeError, ValidationError):
            return None

    @staticmethod
    def _save_to_cache(cache_key: str, mode: str, result) -> None:
        temporary = None
        try:
            directory = Path(CACHE_DIR)
            directory.mkdir(parents=True, exist_ok=True)
            # Same directory ensures atomic replacement; readers never see partial JSON.
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=directory, suffix=".tmp", delete=False) as handle:
                temporary = Path(handle.name)
                json.dump({"version": CACHE_VERSION, "mode": mode, "timestamp": time.time(),
                           "result": result.model_dump()}, handle, ensure_ascii=False, allow_nan=False)
            os.replace(temporary, directory / f"{cache_key}.json")
        except (OSError, ValueError):
            # Cache failure is not an identification failure. Do not log image data.
            logger.warning("recognition_cache_write_failed mode=%s", mode)
        finally:
            if temporary is not None:
                try:
                    temporary.unlink(missing_ok=True)
                except OSError:
                    logger.warning("recognition_cache_temp_cleanup_failed")

    @staticmethod
    def _compress_image(image_base64: str) -> str:
        raw = RecognitionService._decode_image(image_base64)
        try:
            with Image.open(io.BytesIO(raw)) as source:
                if source.width * source.height > MAX_IMAGE_PIXELS:
                    raise InvalidImageError("图片尺寸过大，请缩小后重试。")
                # Honor phone orientation before removing EXIF and converting to JPEG.
                img = ImageOps.exif_transpose(source).convert("RGB")
                img.thumbnail((MAX_IMAGE_WIDTH, MAX_IMAGE_WIDTH), Image.Resampling.LANCZOS)
                buffer = io.BytesIO()
                img.save(buffer, format="JPEG", quality=JPEG_QUALITY, optimize=True)
                return base64.b64encode(buffer.getvalue()).decode("ascii")
        except InvalidImageError:
            raise
        except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError):
            raise InvalidImageError("无法读取图片，请使用有效的照片重试。") from None

    async def recognize(self, image_base64: str) -> RecognizeResponse:
        cache_key = self._cache_key(self._decode_image(image_base64), "single")
        image_base64 = self._compress_image(image_base64)
        cached = self._load_from_cache(cache_key, "single")
        if cached is not None:
            return cached

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
            parsed = await self.llm_client.chat_json(messages, temperature=0.3, response_model=RecognizeResponse)
        except ModelOutputError:
            # Preserve the original two-stage fallback only for invalid model output.
            # Timeouts/auth/network failures must not trigger extra expensive calls.
            logger.warning("recognition_two_stage_fallback reason=model_output_invalid")
            parsed = await self._recognize_two_stage(image_base64)
        self._save_to_cache(cache_key, "single", parsed)
        return parsed

    async def _recognize_two_stage(self, image_base64: str) -> RecognizeResponse:
        description = await self.vlm_client.describe_image(image_base64)
        messages = [{"role": "user", "content": PromptEngine.recognize(description)}]
        return await self.llm_client.chat_json(messages, temperature=0.3, response_model=RecognizeResponse)

    async def recognize_multiple(self, image_base64: str) -> RecognizeMultiResponse:
        cache_key = self._cache_key(self._decode_image(image_base64), "multi")
        image_base64 = self._compress_image(image_base64)
        cached = self._load_from_cache(cache_key, "multi")
        if cached is not None:
            return cached

        prompt = (
            "你是一位专业的商品识别专家。请观察图片，识别图中所有独立的商品。\n"
            "对每件商品，输出以下字段：\n"
            "- name：商品名称\n"
            "- brand：品牌（无法识别写空字符串）\n"
            "- category：品类\n"
            "- color：主色调\n"
            "- center：商品在图中的大致中心点位置，格式为 {\"x\": 0-1, \"y\": 0-1}\n\n"
            "约束：\n"
            "- 只输出 JSON 数组，不要任何解释文字\n"
            "- 如果图中没有商品，输出空数组 []\n"
            "- x,y 是商品大致中心点坐标（相对图片的归一化坐标 0-1，左上角为 0,0）\n"
            "- 中心点只需大致准确，不需要精确到像素\n\n"
            "示例：\n"
            '[{"name": "怡宝纯净水 2.08L", "brand": "怡宝", "category": "饮料", "color": "透明", "center": {"x": 0.35, "y": 0.45}}]'
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

        objects = await self.llm_client.chat_json(messages, temperature=0.3, response_model=list[RecognizedObject])
        result = RecognizeMultiResponse(objects=objects)
        self._save_to_cache(cache_key, "multi", result)
        return result
