import pytest

from app.services.trend import TrendService
from app.models.schemas import TrendResponse


def test_analyze_trend_rising():
    service = TrendService()
    history = [
        {"date": "2024-01-01", "price": 1000.0, "platform": "淘宝"},
        {"date": "2024-02-01", "price": 1100.0, "platform": "京东"},
    ]
    result = service.analyze_trend_sync("Test Product", history)
    assert isinstance(result, TrendResponse)
    assert result.trend == "上涨"
    assert "观望" in result.advice or "上涨" in result.advice


def test_analyze_trend_falling():
    service = TrendService()
    history = [
        {"date": "2024-01-01", "price": 1000.0, "platform": "淘宝"},
        {"date": "2024-02-01", "price": 900.0, "platform": "京东"},
    ]
    result = service.analyze_trend_sync("Test Product", history)
    assert result.trend == "下跌"


def test_analyze_trend_stable():
    service = TrendService()
    history = [
        {"date": "2024-01-01", "price": 1000.0, "platform": "淘宝"},
        {"date": "2024-02-01", "price": 1005.0, "platform": "京东"},
    ]
    result = service.analyze_trend_sync("Test Product", history)
    assert result.trend == "平稳"


def test_analyze_trend_empty():
    service = TrendService()
    result = service.analyze_trend_sync("Test Product", [])
    assert result.trend == "暂无数据"
    assert result.confidence == 0.0
