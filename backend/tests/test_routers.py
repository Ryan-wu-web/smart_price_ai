import pytest
from unittest.mock import patch, AsyncMock


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_compare(client):
    response = client.get("/api/v1/compare?category=鞋&sort_by=price")
    assert response.status_code == 200
    data = response.json()
    assert "products" in data
    assert isinstance(data["products"], list)
    assert data["products"] == sorted(data["products"], key=lambda p: p["price"])


def test_trend(client):
    response = client.get("/api/v1/trend/mock-0")
    assert response.status_code == 200
    data = response.json()
    assert "trend" in data
    assert "advice" in data
    assert "confidence" in data


def test_filter(client):
    with patch("app.routers.filter.FilteringService") as MockService:
        instance = MockService.return_value
        instance.parse_filter = AsyncMock(return_value={"price_max": 500})
        response = client.post("/api/v1/filter", json={"query_text": "500元以下"})
        assert response.status_code == 200
        data = response.json()
        assert data["filters"]["price_max"] == 500


def test_chat(client):
    with patch("app.routers.chat.ChatService") as MockService:
        instance = MockService.return_value
        instance.chat = AsyncMock(return_value={
            "reply": "你好",
            "action": "none",
            "action_data": {},
            "session_id": "test-session-123",
        })
        response = client.post("/api/v1/chat", json={"message": "你好"})
        assert response.status_code == 200
        data = response.json()
        assert data["reply"] == "你好"
        assert data["session_id"] == "test-session-123"


def test_suggest(client):
    with patch("app.routers.suggest.SuggestionService") as MockService:
        instance = MockService.return_value
        instance.generate_cards = AsyncMock(return_value=[
            {"type": "lowest_price", "title": "最低价", "description": "全网最低"},
        ])
        response = client.get("/api/v1/suggest?category=鞋&brand=Nike&color=白色")
        assert response.status_code == 200
        data = response.json()
        assert len(data["cards"]) == 1
        assert data["cards"][0]["type"] == "lowest_price"


def test_report(client):
    with patch("app.routers.report.ReportService") as MockService:
        instance = MockService.return_value
        instance.generate_report = AsyncMock(return_value={
            "summary": "测试报告",
            "pros": ["好"],
            "cons": ["贵"],
            "recommendation": "可以买",
        })
        response = client.post("/api/v1/report", json={
            "product_name": "Test",
            "best_choice": {"name": "Test", "platform": "京东", "price": 100},
            "alternatives": [],
        })
        assert response.status_code == 200
        data = response.json()
        assert data["summary"] == "测试报告"


def test_recognize(client):
    with patch("app.routers.recognize.RecognitionService") as MockService:
        instance = MockService.return_value
        instance.recognize = AsyncMock(return_value={
            "name": "Nike Air Max",
            "brand": "Nike",
            "category": "鞋",
            "color": "白色",
            "material": "网面",
            "style": "运动",
        })
        response = client.post("/api/v1/recognize", json={"image_base64": "fake"})
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Nike Air Max"
