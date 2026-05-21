import pytest
from unittest.mock import AsyncMock

from app.services.report import ReportService
from app.models.schemas import ReportResponse


@pytest.mark.asyncio
async def test_generate_report_success():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "summary": "值得购买",
        "pros": ["质量好", "价格合理"],
        "cons": ["颜色选择少"],
        "recommendation": "推荐购买",
    }

    service = ReportService(llm_client=mock_llm)
    result = await service.generate_report(
        product_name="iPhone 15",
        best_choice={"name": "iPhone 15", "platform": "京东", "price": 5999, "rating": 4.9},
        alternatives=[
            {"name": "iPhone 14", "platform": "淘宝", "price": 4999, "rating": 4.8},
        ],
    )

    assert isinstance(result, ReportResponse)
    assert result.summary == "值得购买"
    assert result.recommendation == "推荐购买"
    mock_llm.chat_json.assert_awaited_once()
