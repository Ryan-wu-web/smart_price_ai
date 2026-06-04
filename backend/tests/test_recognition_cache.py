"""
缓存复现测试：暴露 recognition.py 中缓存失效的双重 bug。

Bug 1: 同一请求内，_load_from_cache 用原始 base64 查，_save_to_cache 用压缩后 base64 存，
       key 永远不一致 → 缓存存不上、查不到。
Bug 2: 重新拍照时，新图片的 base64 完全不同（EXIF 差异），MD5 不同 → 跨请求缓存不命中。
"""

import base64
import io
import shutil

import pytest
from PIL import Image
from unittest.mock import AsyncMock

from app.services.recognition import RecognitionService, CACHE_DIR


@pytest.fixture(autouse=True)
def clear_recognition_cache():
    """每个测试前清除识别缓存。"""
    shutil.rmtree(CACHE_DIR, ignore_errors=True)
    yield


def _make_base64(size: tuple[int, int], color: tuple[int, int, int]) -> str:
    """生成一个纯色的 JPEG base64 图片。"""
    img = Image.new("RGB", size, color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return base64.b64encode(buf.getvalue()).decode("utf-8")


@pytest.mark.asyncio
async def test_cache_hit_on_same_compressed_content():
    """
    Bug 1 复现：两次调用 recognize() 传入**内容相同但尺寸不同**的图片，
    由于压缩后会变成同一尺寸，理应命中缓存。

    当前代码的问题：
    - 第1次：_load_from_cache(原始b64_1) → miss → compress → LLM → _save_to_cache(压缩后b64_1)
    - 第2次：_load_from_cache(原始b64_2) → miss（原始b64_2 ≠ 原始b64_1，也≠ 压缩后b64_1）

    预期（修复后）：
    - 两次都先压缩，压缩后的内容相同 → 同一感知哈希 → 第2次命中缓存
    """
    img_a = _make_base64((1200, 900), (255, 0, 0))   # 大尺寸红色
    img_b = _make_base64((1600, 1200), (255, 0, 0))  # 更大尺寸红色（内容相同）

    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "name": "红色方块",
        "brand": "",
        "category": "测试品",
        "color": "红色",
        "material": "",
        "style": "",
    }

    service = RecognitionService(vlm_client=AsyncMock(), llm_client=mock_llm)

    # 第1次调用
    result1 = await service.recognize(img_a)
    assert result1.name == "红色方块"
    assert mock_llm.chat_json.await_count == 1  # 第1次必须走 LLM

    # 第2次调用 —— 传入不同 base64 但内容相同的图片
    result2 = await service.recognize(img_b)
    assert result2.name == "红色方块"

    # 🔴 这是失败断言：当前代码下，第2次仍然会调用 LLM（缓存未命中）
    # 修复后应该：mock_llm.chat_json.await_count 仍为 1
    assert mock_llm.chat_json.await_count == 1, (
        f"缓存未命中！第2次调用仍走了 LLM，"
        f"说明 cache key 未基于图片内容计算。实际调用次数={mock_llm.chat_json.await_count}"
    )


@pytest.mark.asyncio
async def test_cache_key_consistency_within_single_request():
    """
    Bug 1 深度复现：验证同一请求内，查缓存和存缓存用的是同一个 key。

    当前代码的问题（recognition.py 第 86-125 行）：
    - 第89行: _load_from_cache(image_base64)          ← 原始 base64
    - 第93行: image_base64 = _compress_image(...)     ← 变量被覆盖
    - 第119行: _save_to_cache(image_base64, ...)       ← 压缩后的 base64

    这意味着即使第1次调用，存的 key 和查的 key 也不同！
    """
    img = _make_base64((1200, 900), (0, 255, 0))

    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "name": "绿色方块",
        "brand": "",
        "category": "测试品",
        "color": "绿色",
        "material": "",
        "style": "",
    }

    service = RecognitionService(vlm_client=AsyncMock(), llm_client=mock_llm)

    # 第1次：应该走 LLM，结果存入缓存
    await service.recognize(img)
    assert mock_llm.chat_json.await_count == 1

    # 第2次：用**完全相同的 base64** 再调用一次
    # 如果同一请求内 key 一致，这次应该命中缓存
    await service.recognize(img)

    # 🔴 当前代码下这个断言也会失败，因为存的 key ≠ 查的 key
    assert mock_llm.chat_json.await_count == 1, (
        f"同一请求内 cache key 不一致！"
        f"第1次存的 key 和第2次查的 key 不同。实际调用次数={mock_llm.chat_json.await_count}"
    )
