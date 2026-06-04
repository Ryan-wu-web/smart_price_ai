"""
性能优化测试：验证连接池复用和图片压缩参数调整。
"""

import base64
import io

import pytest
from PIL import Image
from unittest.mock import AsyncMock, patch

from app.core.base_api_client import BaseAPIClient
from app.services.recognition import RecognitionService, MAX_IMAGE_WIDTH, JPEG_QUALITY


def test_base_api_client_has_reusable_client():
    """
    连接池复用：BaseAPIClient 实例应持有一个 httpx.AsyncClient，
    避免每次请求都新建连接。
    """
    client = BaseAPIClient()
    assert hasattr(client, "_client")
    assert client._client is not None


@pytest.mark.asyncio
async def test_base_api_client_reuses_same_client_on_multiple_calls():
    """
    验证多次调用 chat() 时，使用的是同一个 httpx.AsyncClient 实例。
    """
    client = BaseAPIClient()
    original_client = client._client

    with patch.object(
        client._client, "post", new_callable=AsyncMock
    ) as mock_post:
        mock_response = AsyncMock()
        mock_response.raise_for_status = AsyncMock()
        # httpx.Response.json() 是同步方法
        mock_response.json = lambda: {
            "choices": [{"message": {"content": "test reply"}}]
        }
        mock_post.return_value = mock_response

        # 第一次调用
        result1 = await client.chat([{"role": "user", "content": "hi"}])
        # 第二次调用
        result2 = await client.chat([{"role": "user", "content": "hi again"}])

        assert result1 == "test reply"
        assert result2 == "test reply"
        # 两次调用都使用了同一个 client 实例
        assert client._client is original_client
        assert mock_post.await_count == 2


def test_compress_image_uses_correct_max_width_and_quality():
    """
    图片压缩参数验证：确认 MAX_IMAGE_WIDTH 和 JPEG_QUALITY 的当前值。
    如果未来调整这些值，此测试会失败，提醒开发者检查前端/后端的兼容性。
    """
    # 这些值决定了图片压缩后的质量和大小
    assert MAX_IMAGE_WIDTH == 600, f"期望 MAX_IMAGE_WIDTH=600（优化传输速度），实际={MAX_IMAGE_WIDTH}"
    assert JPEG_QUALITY == 75, f"期望 JPEG_QUALITY=75（平衡质量与大小），实际={JPEG_QUALITY}"


def test_compress_image_respects_max_width():
    """
    验证 _compress_image 将超大图片压缩到指定最大宽度。
    """
    # 生成一张 1200x900 的图片
    img = Image.new("RGB", (1200, 900), (255, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=95)
    base64_img = base64.b64encode(buf.getvalue()).decode("utf-8")

    compressed = RecognitionService._compress_image(base64_img)

    # 解码压缩后的图片，验证宽度
    raw = base64.b64decode(compressed)
    compressed_img = Image.open(io.BytesIO(raw))

    assert compressed_img.size[0] <= MAX_IMAGE_WIDTH, (
        f"压缩后宽度 {compressed_img.size[0]} 超过了 MAX_IMAGE_WIDTH={MAX_IMAGE_WIDTH}"
    )
