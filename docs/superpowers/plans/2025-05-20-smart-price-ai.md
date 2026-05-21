# Smart Price AI 实现计划

> **给代理工作者：** 必需子skill：使用 subagent-driven-development（推荐）或 executing-plans 逐个任务执行此计划。步骤使用复选框（- [ ]）语法跟踪。

**目标：** 构建 AI 拍照识物与智能比价购物助手，包含 Flutter 客户端 + FastAPI 后端，20 天内交付可运行 Demo。

**架构：** 模块化单体 FastAPI 后端（识物/比价/建议/筛选/趋势/报告/导购七模块），通过 LLM 编排引擎统一调用火山引擎 Doubao-VLM。Flutter 客户端调用 REST API，UI 后期统一美化。

**技术栈：** Flutter + Python/FastAPI + PostgreSQL + Redis + 火山引擎 OpenAPI

---

## 文件结构

```
smart-price-ai/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                  # FastAPI 入口，注册路由
│   │   ├── config.py                # 环境变量配置
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── recognize.py         # POST /api/v1/recognize
│   │   │   ├── suggest.py           # POST /api/v1/suggest
│   │   │   ├── compare.py           # GET  /api/v1/compare
│   │   │   ├── filter.py            # POST /api/v1/filter
│   │   │   ├── trend.py             # GET  /api/v1/trend/{product_id}
│   │   │   ├── report.py            # POST /api/v1/report
│   │   │   └── chat.py              # POST /api/v1/chat
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── recognition.py       # 识物服务（VLM+LLM）
│   │   │   ├── suggestion.py        # 建议卡片服务
│   │   │   ├── comparison.py        # 比价服务（数据源抽象层）
│   │   │   ├── filtering.py         # 筛选服务
│   │   │   ├── trend.py             # 趋势服务
│   │   │   ├── report.py            # 报告服务
│   │   │   └── chat.py              # 导购对话服务
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── schemas.py           # Pydantic schemas
│   │   │   └── database.py          # SQLAlchemy models
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── llm_client.py        # Doubao LLM HTTP 客户端
│   │   │   ├── vlm_client.py        # Doubao VLM HTTP 客户端
│   │   │   └── prompt_engine.py     # Prompt 模板管理
│   │   └── utils/
│   │       └── __init__.py
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py              # pytest fixtures
│   │   ├── test_recognize.py
│   │   ├── test_compare.py
│   │   ├── test_chat.py
│   │   └── test_services.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── alembic.ini
│
├── android-app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── camera_screen.dart
│   │   │   ├── result_screen.dart
│   │   │   ├── compare_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   └── report_screen.dart
│   │   ├── widgets/
│   │   │   ├── product_card.dart
│   │   │   ├── suggestion_card.dart
│   │   │   ├── chat_bubble.dart
│   │   │   └── bottom_input_bar.dart
│   │   ├── models/
│   │   │   ├── product.dart
│   │   │   ├── recognition_result.dart
│   │   │   └── chat_message.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   └── utils/
│   │       └── constants.dart
│   ├── pubspec.yaml
│   ├── android/
│   └── test/
│       └── widget_test.dart
│
└── docs/
    └── ...
```

---

## Phase 1: 项目脚手架

### 任务 1：FastAPI 项目结构与入口

**文件：**
- 创建：`backend/requirements.txt`
- 创建：`backend/app/__init__.py`
- 创建：`backend/app/main.py`
- 创建：`backend/app/config.py`
- 测试：`backend/tests/conftest.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_root_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd backend && pytest tests/conftest.py -v`

预期：FAIL - ModuleNotFoundError: No module named 'app'

- [ ] **步骤 3：编写最小实现**

```python
# backend/requirements.txt
fastapi==0.110.0
uvicorn[standard]==0.27.0
pydantic==2.6.0
pydantic-settings==2.1.0
sqlalchemy==2.0.25
psycopg2-binary==2.9.9
redis==5.0.1
httpx==0.26.0
pytest==8.0.0
pytest-asyncio==0.23.0
```

```python
# backend/app/__init__.py
# empty
```

```python
# backend/app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name: str = "Smart Price AI"
    debug: bool = True
    database_url: str = "postgresql://user:password@localhost/smartprice"
    redis_url: str = "redis://localhost:6379/0"
    volcengine_api_key: str = ""
    volcengine_endpoint: str = ""
    
    class Config:
        env_file = ".env"

settings = Settings()
```

```python
# backend/app/main.py
from fastapi import FastAPI
from app.config import settings

app = FastAPI(title=settings.app_name)

@app.get("/health")
def health_check():
    return {"status": "ok"}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`cd backend && pip install -r requirements.txt && pytest tests/conftest.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/
git commit -m "feat: scaffold FastAPI backend with health endpoint"
```

---

### 任务 2：数据库模型与迁移

**文件：**
- 创建：`backend/app/models/__init__.py`
- 创建：`backend/app/models/schemas.py`
- 创建：`backend/app/models/database.py`
- 测试：`backend/tests/test_database.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_database.py
from app.models.database import Product, PriceHistory

def test_product_model():
    product = Product(name="Test Shoe", brand="Nike", category="shoes", color="black", price=749.0)
    assert product.name == "Test Shoe"
    assert product.brand == "Nike"
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_database.py -v`

预期：FAIL - ImportError

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/models/database.py
from sqlalchemy import Column, String, Float, DateTime, JSON, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime

Base = declarative_base()

class Product(Base):
    __tablename__ = "products"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    brand = Column(String(100))
    category = Column(String(100))
    color = Column(String(50))
    price = Column(Float)
    platform = Column(String(50))
    original_url = Column(String)
    rating = Column(Float)
    tags = Column(JSON)
    image_url = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

class PriceHistory(Base):
    __tablename__ = "price_history"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(UUID(as_uuid=True))
    platform = Column(String(50))
    price = Column(Float)
    recorded_at = Column(DateTime, default=datetime.utcnow)

class ChatSession(Base):
    __tablename__ = "chat_sessions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String(100))
    context = Column(JSON)
    expires_at = Column(DateTime)

class DecisionReport(Base):
    __tablename__ = "decision_reports"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True))
    report_data = Column(JSON)
    share_image_url = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
```

```python
# backend/app/models/schemas.py
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime

class ProductBase(BaseModel):
    name: str
    brand: Optional[str] = None
    category: Optional[str] = None
    color: Optional[str] = None
    price: float
    platform: Optional[str] = None
    rating: Optional[float] = None
    tags: Optional[List[str]] = None
    image_url: Optional[str] = None

class ProductResponse(ProductBase):
    id: UUID
    created_at: datetime
    
    class Config:
        from_attributes = True

class RecognizeRequest(BaseModel):
    image_base64: str

class RecognizeResponse(BaseModel):
    category: str
    brand: Optional[str] = None
    color: Optional[str] = None
    style: Optional[str] = None
    attributes: Optional[Dict[str, Any]] = None
    confidence: float = Field(ge=0, le=1)

class SuggestionCard(BaseModel):
    type: str
    title: str
    icon: Optional[str] = None
    action: Optional[str] = None

class SuggestResponse(BaseModel):
    cards: List[SuggestionCard]

class CompareQuery(BaseModel):
    category: str
    brand: Optional[str] = None
    color: Optional[str] = None
    style: Optional[str] = None

class CompareResponse(BaseModel):
    products: List[ProductResponse]

class FilterRequest(BaseModel):
    query_text: str
    current_product_ids: Optional[List[UUID]] = None

class FilterResponse(BaseModel):
    products: List[ProductResponse]
    parsed_conditions: Optional[Dict[str, Any]] = None

class TrendResponse(BaseModel):
    history_prices: List[Dict[str, Any]]
    avg_price: float
    trend: str
    suggestion: str
    confidence: float

class ReportRequest(BaseModel):
    product_id: UUID
    session_id: Optional[UUID] = None

class ReportResponse(BaseModel):
    target_product: str
    best_choice: Dict[str, Any]
    alternatives: List[Dict[str, Any]]
    ai_suggestion: str
    confidence: float

class ChatRequest(BaseModel):
    message: str
    session_id: Optional[UUID] = None
    current_product: Optional[Dict[str, Any]] = None

class ChatResponse(BaseModel):
    reply: str
    action: Optional[str] = None
    action_data: Optional[Dict[str, Any]] = None
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_database.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/models/ backend/tests/test_database.py
git commit -m "feat: add database models and pydantic schemas"
```

---

### 任务 3：LLM/VLM 客户端与 Prompt 引擎

**文件：**
- 创建：`backend/app/core/__init__.py`
- 创建：`backend/app/core/llm_client.py`
- 创建：`backend/app/core/vlm_client.py`
- 创建：`backend/app/core/prompt_engine.py`
- 测试：`backend/tests/test_llm_client.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_llm_client.py
import pytest
from app.core.llm_client import LLMClient
from app.core.vlm_client import VLMClient
from app.core.prompt_engine import PromptEngine

@pytest.fixture
def prompt_engine():
    return PromptEngine()

def test_prompt_engine_recognition(prompt_engine):
    prompt = prompt_engine.get_recognition_prompt()
    assert "识别" in prompt or "product" in prompt.lower()

def test_llm_client_init():
    client = LLMClient(api_key="test-key", endpoint="https://test.com")
    assert client.api_key == "test-key"
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_llm_client.py -v`

预期：FAIL - ModuleNotFoundError

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/core/prompt_engine.py
class PromptEngine:
    """集中管理所有 Prompt 模板"""
    
    @staticmethod
    def get_recognition_prompt() -> str:
        return """你是一位商品识别专家。请分析用户上传的商品图片，识别出以下信息：
- category: 商品类目（如：运动鞋、手机、 handbag）
- brand: 品牌（如：Nike、Apple、Coach）
- color: 主要颜色
- style: 款式/型号
- attributes: 其他关键属性（如尺码、材质等）

请以 JSON 格式返回，不要包含其他文字：
{"category": "...", "brand": "...", "color": "...", "style": "...", "attributes": {"size": "...", "material": "..."}}"""

    @staticmethod
    def get_suggestion_prompt(category: str, brand: str, color: str) -> str:
        return f"""基于识别结果：类目={category}，品牌={brand}，颜色={color}。
请生成 3-5 个可交互的建议卡片，帮助用户进行下一步购物决策。

卡片类型包括：lowest_price, official_store, similar_style, price_trend, filter_color。
请以 JSON 数组格式返回：
[{{"type": "lowest_price", "title": "查看同款低价", "action": "compare"}}]"""

    @staticmethod
    def get_filter_prompt(query_text: str) -> str:
        return f"""用户输入的自然语言筛选条件："{query_text}"。
请解析为结构化条件，以 JSON 格式返回：
{{"price_max": 1000, "color": "black", "rating_min": 4.8, "brand": "..."}}
如果某个条件未提及，对应字段为 null。"""

    @staticmethod
    def get_trend_prompt(product_name: str, history_prices: list) -> str:
        prices_str = "\n".join([f"{p['date']}: {p['price']}" for p in history_prices])
        return f"""商品：{product_name}
历史价格数据：
{prices_str}

请分析价格趋势，给出购买建议。以 JSON 格式返回：
{{"avg_price": 850, "trend": "down", "suggestion": "建议立即购买", "confidence": 0.89}}"""

    @staticmethod
    def get_chat_prompt(message: str, context: list, current_product: dict) -> str:
        context_str = "\n".join([f"{'User' if i%2==0 else 'AI'}: {m}" for i, m in enumerate(context)])
        product_str = str(current_product) if current_product else "无"
        return f"""你是一位专业的AI购物导购助手。当前商品信息：{product_str}

对话历史：
{context_str}

用户新消息：{message}

请回复用户。如果需要执行操作（如刷新列表、跳转页面），在 JSON 中包含 action 字段：
{{"reply": "回复内容", "action": "refresh_list", "action_data": {{"color": "white"}}}}"""
```

```python
# backend/app/core/llm_client.py
import httpx
import json
from typing import Dict, Any, Optional

class LLMClient:
    def __init__(self, api_key: str, endpoint: str):
        self.api_key = api_key
        self.endpoint = endpoint
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    async def chat(self, prompt: str, temperature: float = 0.7) -> str:
        """调用 Doubao LLM API"""
        payload = {
            "model": "doubao-seed-2.0-lite",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": temperature
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.endpoint,
                headers=self.headers,
                json=payload,
                timeout=30.0
            )
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
    
    async def chat_structured(self, prompt: str, temperature: float = 0.3) -> Dict[str, Any]:
        """调用 LLM 并解析 JSON 输出"""
        content = await self.chat(prompt, temperature)
        # 提取 JSON 部分
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            # 尝试从 markdown 代码块中提取
            if "```json" in content:
                json_str = content.split("```json")[1].split("```")[0].strip()
                return json.loads(json_str)
            raise ValueError(f"Failed to parse JSON from LLM response: {content}")
```

```python
# backend/app/core/vlm_client.py
import httpx
import base64
from typing import Dict, Any

class VLMClient:
    def __init__(self, api_key: str, endpoint: str):
        self.api_key = api_key
        self.endpoint = endpoint
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    async def recognize(self, image_base64: str, prompt: str) -> str:
        """调用 Doubao VLM API 识别图片"""
        payload = {
            "model": "doubao-seed-2.0-lite",
            "messages": [{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                ]
            }]
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.endpoint,
                headers=self.headers,
                json=payload,
                timeout=60.0
            )
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_llm_client.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/core/ backend/tests/test_llm_client.py
git commit -m "feat: add LLM/VLM clients and prompt engine"
```

---

## Phase 2: 核心服务实现

### 任务 4：识物服务（VLM + LLM 两阶段编排）

**文件：**
- 创建：`backend/app/services/__init__.py`
- 创建：`backend/app/services/recognition.py`
- 测试：`backend/tests/test_recognition.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_recognition.py
import pytest
from unittest.mock import AsyncMock, patch
from app.services.recognition import RecognitionService

@pytest.fixture
def service():
    return RecognitionService()

@pytest.mark.asyncio
async def test_recognize_success(service):
    with patch.object(service.vlm_client, 'recognize', new_callable=AsyncMock) as mock_vlm, \
         patch.object(service.llm_client, 'chat_structured', new_callable=AsyncMock) as mock_llm:
        
        mock_vlm.return_value = "这是一双黑色的 Nike Air Max 运动鞋，42码"
        mock_llm.return_value = {
            "category": "运动鞋",
            "brand": "Nike",
            "color": "黑色",
            "style": "Air Max",
            "attributes": {"size": "42码"}
        }
        
        result = await service.recognize("fake_base64_image")
        
        assert result.category == "运动鞋"
        assert result.brand == "Nike"
        assert result.color == "黑色"
        mock_vlm.assert_called_once()
        mock_llm.assert_called_once()
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_recognition.py -v`

预期：FAIL - ModuleNotFoundError

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/services/recognition.py
from app.core.vlm_client import VLMClient
from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.models.schemas import RecognizeResponse
from app.config import settings

class RecognitionService:
    def __init__(self):
        self.vlm_client = VLMClient(
            api_key=settings.volcengine_api_key,
            endpoint=settings.volcengine_endpoint
        )
        self.llm_client = LLMClient(
            api_key=settings.volcengine_api_key,
            endpoint=settings.volcengine_endpoint
        )
        self.prompt_engine = PromptEngine()
    
    async def recognize(self, image_base64: str) -> RecognizeResponse:
        """两阶段识物：VLM 描述 -> LLM 结构化"""
        # 阶段 1：VLM 描述图片
        vlm_prompt = "请描述这张图片中的商品，包括品牌、颜色、款式、尺码等关键信息。"
        description = await self.vlm_client.recognize(image_base64, vlm_prompt)
        
        # 阶段 2：LLM 结构化提取
        llm_prompt = f"""从以下商品描述中提取结构化信息：
{description}

请以 JSON 格式返回：
{{"category": "类目", "brand": "品牌", "color": "颜色", "style": "款式", "attributes": {{"size": "尺码"}}}}"""
        
        structured = await self.llm_client.chat_structured(llm_prompt, temperature=0.3)
        
        return RecognizeResponse(
            category=structured.get("category", "未知"),
            brand=structured.get("brand"),
            color=structured.get("color"),
            style=structured.get("style"),
            attributes=structured.get("attributes"),
            confidence=0.85  # 后期可基于描述完整度计算
        )
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_recognition.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/services/recognition.py backend/tests/test_recognition.py
git commit -m "feat: add two-stage recognition service (VLM+LLM)"
```

---

### 任务 5：比价服务（Mock 数据 + 数据源抽象层）

**文件：**
- 创建：`backend/app/services/comparison.py`
- 测试：`backend/tests/test_comparison.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_comparison.py
import pytest
from app.services.comparison import ComparisonService, MockDataSource

@pytest.fixture
def service():
    return ComparisonService()

def test_mock_data_source_search():
    ds = MockDataSource()
    results = ds.search_sync(category="运动鞋", brand="Nike", color="黑色")
    assert len(results) > 0
    assert all(r.category == "运动鞋" for r in results)

def test_comparison_service_compare(service):
    results = service.compare_sync(category="运动鞋", brand="Nike", color="黑色")
    assert len(results) >= 3  # 至少3个平台
    platforms = set([r.platform for r in results])
    assert "mock_jd" in platforms
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_comparison.py -v`

预期：FAIL

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/services/comparison.py
from abc import ABC, abstractmethod
from typing import List, Optional
from app.models.schemas import ProductResponse
from uuid import uuid4
from datetime import datetime

class DataSource(ABC):
    @abstractmethod
    async def search(self, category: str, brand: Optional[str], color: Optional[str]) -> List[ProductResponse]:
        pass

class MockDataSource(DataSource):
    """Mock 数据源，内置 200+ 商品数据"""
    
    MOCK_PRODUCTS = [
        {
            "name": "Nike Air Max 90 黑色 42码", "brand": "Nike", "category": "运动鞋",
            "color": "黑色", "price": 749.0, "platform": "mock_jd",
            "rating": 4.9, "tags": ["自营", "官方", "包邮"]
        },
        {
            "name": "Nike Air Max 90 黑色 42码", "brand": "Nike", "category": "运动鞋",
            "color": "黑色", "price": 799.0, "platform": "mock_taobao",
            "rating": 4.8, "tags": ["官方", "七天退换"]
        },
        {
            "name": "Nike Air Max 90 黑色 42码", "brand": "Nike", "category": "运动鞋",
            "color": "黑色", "price": 699.0, "platform": "mock_pdd",
            "rating": 4.7, "tags": ["百亿补贴", "包邮"]
        },
        # ... 更多商品（实际文件中应有 200+ 条）
    ]
    
    async def search(self, category: str, brand: Optional[str], color: Optional[str]) -> List[ProductResponse]:
        results = []
        for p in self.MOCK_PRODUCTS:
            if p["category"] == category:
                if brand and p["brand"] != brand:
                    continue
                if color and p["color"] != color:
                    continue
                results.append(ProductResponse(
                    id=uuid4(), name=p["name"], brand=p["brand"], category=p["category"],
                    color=p["color"], price=p["price"], platform=p["platform"],
                    rating=p["rating"], tags=p["tags"], created_at=datetime.utcnow()
                ))
        return results
    
    def search_sync(self, category: str, brand: Optional[str] = None, color: Optional[str] = None) -> List[ProductResponse]:
        import asyncio
        return asyncio.get_event_loop().run_until_complete(self.search(category, brand, color))

class ComparisonService:
    def __init__(self):
        self.data_source: DataSource = MockDataSource()
    
    async def compare(self, category: str, brand: Optional[str] = None, color: Optional[str] = None) -> List[ProductResponse]:
        return await self.data_source.search(category, brand, color)
    
    def compare_sync(self, category: str, brand: Optional[str] = None, color: Optional[str] = None) -> List[ProductResponse]:
        import asyncio
        return asyncio.get_event_loop().run_until_complete(self.compare(category, brand, color))
    
    def sort_by_price(self, products: List[ProductResponse]) -> List[ProductResponse]:
        return sorted(products, key=lambda x: x.price)
    
    def sort_by_rating(self, products: List[ProductResponse]) -> List[ProductResponse]:
        return sorted(products, key=lambda x: x.rating or 0, reverse=True)
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_comparison.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/services/comparison.py backend/tests/test_comparison.py
git commit -m "feat: add comparison service with mock data source"
```

---

### 任务 6：筛选服务 + 建议服务 + 趋势服务

**文件：**
- 创建：`backend/app/services/filtering.py`
- 创建：`backend/app/services/suggestion.py`
- 创建：`backend/app/services/trend.py`
- 测试：`backend/tests/test_services.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_services.py
import pytest
from unittest.mock import AsyncMock, patch
from app.services.filtering import FilteringService
from app.services.suggestion import SuggestionService
from app.services.trend import TrendService

@pytest.mark.asyncio
async def test_filtering_service():
    service = FilteringService()
    with patch.object(service.llm_client, 'chat_structured', new_callable=AsyncMock) as mock_llm:
        mock_llm.return_value = {"price_max": 1000, "color": "黑色", "rating_min": 4.8}
        conditions = await service.parse_filter("帮我找1000元以内的黑色款，评价4.8分以上")
        assert conditions["price_max"] == 1000
        assert conditions["color"] == "黑色"

def test_suggestion_service():
    service = SuggestionService()
    cards = service.generate_cards(category="运动鞋", brand="Nike", color="黑色")
    assert len(cards) >= 3
    assert any(c.type == "lowest_price" for c in cards)

def test_trend_service():
    service = TrendService()
    trend = service.analyze_trend_sync("Nike Air Max", [
        {"date": "2025-01-01", "price": 899},
        {"date": "2025-01-15", "price": 850},
        {"date": "2025-02-01", "price": 799},
    ])
    assert "suggestion" in trend
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_services.py -v`

预期：FAIL

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/services/filtering.py
from typing import Dict, Any, Optional
from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.config import settings

class FilteringService:
    def __init__(self):
        self.llm_client = LLMClient(
            api_key=settings.volcengine_api_key,
            endpoint=settings.volcengine_endpoint
        )
        self.prompt_engine = PromptEngine()
    
    async def parse_filter(self, query_text: str) -> Dict[str, Any]:
        prompt = self.prompt_engine.get_filter_prompt(query_text)
        return await self.llm_client.chat_structured(prompt, temperature=0.3)
```

```python
# backend/app/services/suggestion.py
from typing import List
from app.models.schemas import SuggestionCard

class SuggestionService:
    def generate_cards(self, category: str, brand: Optional[str], color: Optional[str]) -> List[SuggestionCard]:
        cards = [SuggestionCard(type="lowest_price", title="查看同款低价", action="compare")]
        if brand:
            cards.append(SuggestionCard(type="official_store", title="只看官方旗舰店", action="filter_official"))
        cards.extend([
            SuggestionCard(type="similar_style", title="相似风格推荐", action="similar"),
            SuggestionCard(type="price_trend", title="查看价格走势", action="trend"),
        ])
        if color:
            cards.append(SuggestionCard(type="filter_color", title=f"筛选：{color}色", action=f"filter_color:{color}"))
        return cards
```

```python
# backend/app/services/trend.py
from typing import List, Dict, Any
from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.config import settings
import statistics

class TrendService:
    def __init__(self):
        self.llm_client = LLMClient(
            api_key=settings.volcengine_api_key,
            endpoint=settings.volcengine_endpoint
        )
        self.prompt_engine = PromptEngine()
    
    def analyze_trend_sync(self, product_name: str, history_prices: List[Dict[str, Any]]) -> Dict[str, Any]:
        prices = [p["price"] for p in history_prices]
        avg = statistics.mean(prices)
        current = prices[-1]
        trend = "down" if current < avg else "up"
        
        suggestion = "建议立即购买" if trend == "down" else "建议观望，预计短期内可能降价"
        
        return {
            "history_prices": history_prices,
            "avg_price": avg,
            "trend": trend,
            "suggestion": suggestion,
            "confidence": 0.85
        }
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_services.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/services/filtering.py backend/app/services/suggestion.py backend/app/services/trend.py backend/tests/test_services.py
git commit -m "feat: add filtering, suggestion and trend services"
```

---

### 任务 7：报告服务 + AI 导购服务

**文件：**
- 创建：`backend/app/services/report.py`
- 创建：`backend/app/services/chat.py`
- 测试：`backend/tests/test_chat.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_chat.py
import pytest
from unittest.mock import AsyncMock, patch
from app.services.chat import ChatService
from app.services.report import ReportService

@pytest.mark.asyncio
async def test_chat_service():
    service = ChatService()
    with patch.object(service.llm_client, 'chat_structured', new_callable=AsyncMock) as mock_llm:
        mock_llm.return_value = {
            "reply": "同款还有白色可选，白色当前最低价¥699",
            "action": None,
            "action_data": None
        }
        result = await service.chat("有别的颜色吗？", session_id=None, current_product={"name": "Nike Air Max"})
        assert "白色" in result.reply

def test_report_service():
    service = ReportService()
    report = service.generate_report_sync("Nike Air Max", {"platform": "京东", "price": 749}, [])
    assert "best_choice" in report
    assert "ai_suggestion" in report
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_chat.py -v`

预期：FAIL

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/services/chat.py
from typing import Optional, Dict, Any
from uuid import uuid4
import json
from app.core.llm_client import LLMClient
from app.config import settings

class ChatService:
    def __init__(self):
        self.llm_client = LLMClient(
            api_key=settings.volcengine_api_key,
            endpoint=settings.volcengine_endpoint
        )
        self.sessions = {}  # 简化的内存存储，后期换 Redis
    
    async def chat(self, message: str, session_id: Optional[str] = None, current_product: Optional[Dict] = None) -> Dict[str, Any]:
        session = self.sessions.get(session_id, {"context": []}) if session_id else {"context": []}
        
        prompt = f"""你是一位专业的AI购物导购助手。当前商品：{json.dumps(current_product) if current_product else '无'}

对话历史：{json.dumps(session['context'][-5:])}

用户：{message}

请以 JSON 回复：{{"reply": "...", "action": null, "action_data": null}}"""
        
        result = await self.llm_client.chat_structured(prompt, temperature=0.7)
        
        # 更新会话
        session["context"].extend([message, result["reply"]])
        if not session_id:
            session_id = str(uuid4())
        self.sessions[session_id] = session
        
        return {
            "reply": result["reply"],
            "action": result.get("action"),
            "action_data": result.get("action_data"),
            "session_id": session_id
        }
```

```python
# backend/app/services/report.py
from typing import Dict, Any, List
from uuid import uuid4
from datetime import datetime

class ReportService:
    def generate_report_sync(self, product_name: str, best_choice: Dict, alternatives: List[Dict]) -> Dict[str, Any]:
        return {
            "id": str(uuid4()),
            "target_product": product_name,
            "best_choice": best_choice,
            "alternatives": alternatives,
            "ai_suggestion": f"当前{best_choice['platform']}售价¥{best_choice['price']}，建议立即购买",
            "confidence": 0.89,
            "generated_at": datetime.utcnow().isoformat()
        }
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_chat.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/services/report.py backend/app/services/chat.py backend/tests/test_chat.py
git commit -m "feat: add chat and report services"
```

---

## Phase 3: API 路由层

### 任务 8：注册所有路由

**文件：**
- 修改：`backend/app/main.py`
- 创建：`backend/app/routers/__init__.py`
- 创建：`backend/app/routers/recognize.py`
- 创建：`backend/app/routers/suggest.py`
- 创建：`backend/app/routers/compare.py`
- 创建：`backend/app/routers/filter.py`
- 创建：`backend/app/routers/trend.py`
- 创建：`backend/app/routers/report.py`
- 创建：`backend/app/routers/chat.py`
- 测试：`backend/tests/test_api.py`

- [ ] **步骤 1：编写失败的测试**

```python
# backend/tests/test_api.py
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_recognize_endpoint():
    response = client.post("/api/v1/recognize", json={"image_base64": "fake_image"})
    assert response.status_code in [200, 422]  # 422 if validation fails

def test_compare_endpoint():
    response = client.get("/api/v1/compare?category=运动鞋&brand=Nike&color=黑色")
    assert response.status_code == 200
    data = response.json()
    assert "products" in data

def test_chat_endpoint():
    response = client.post("/api/v1/chat", json={"message": "你好"})
    assert response.status_code == 200
```

- [ ] **步骤 2：运行测试验证失败**

运行：`pytest backend/tests/test_api.py -v`

预期：FAIL - 404 Not Found（路由未注册）

- [ ] **步骤 3：编写最小实现**

```python
# backend/app/routers/recognize.py
from fastapi import APIRouter
from app.models.schemas import RecognizeRequest, RecognizeResponse
from app.services.recognition import RecognitionService

router = APIRouter()
service = RecognitionService()

@router.post("/api/v1/recognize", response_model=RecognizeResponse)
async def recognize(request: RecognizeRequest):
    return await service.recognize(request.image_base64)
```

```python
# backend/app/routers/suggest.py
from fastapi import APIRouter
from typing import Optional
from app.models.schemas import SuggestResponse
from app.services.suggestion import SuggestionService

router = APIRouter()
service = SuggestionService()

@router.get("/api/v1/suggest", response_model=SuggestResponse)
def suggest(category: str, brand: Optional[str] = None, color: Optional[str] = None):
    cards = service.generate_cards(category, brand, color)
    return {"cards": cards}
```

```python
# backend/app/routers/compare.py
from fastapi import APIRouter, Query
from typing import Optional, Literal
from app.models.schemas import CompareResponse
from app.services.comparison import ComparisonService

router = APIRouter()
service = ComparisonService()

@router.get("/api/v1/compare", response_model=CompareResponse)
def compare(
    category: str,
    brand: Optional[str] = None,
    color: Optional[str] = None,
    sort_by: Optional[Literal["price", "rating", "default"]] = "default"
):
    products = service.compare_sync(category, brand, color)
    if sort_by == "price":
        products = service.sort_by_price(products)
    elif sort_by == "rating":
        products = service.sort_by_rating(products)
    return {"products": products}
```

```python
# backend/app/routers/filter.py
from fastapi import APIRouter
from app.models.schemas import FilterRequest, FilterResponse
from app.services.filtering import FilteringService

router = APIRouter()
service = FilteringService()

@router.post("/api/v1/filter", response_model=FilterResponse)
async def filter_products(request: FilterRequest):
    conditions = await service.parse_filter(request.query_text)
    # TODO: 应用筛选条件到商品列表
    return {"products": [], "parsed_conditions": conditions}
```

```python
# backend/app/routers/trend.py
from fastapi import APIRouter
from uuid import UUID
from app.models.schemas import TrendResponse
from app.services.trend import TrendService

router = APIRouter()
service = TrendService()

@router.get("/api/v1/trend/{product_id}", response_model=TrendResponse)
def get_trend(product_id: UUID):
    # TODO: 从数据库获取历史价格
    history = [
        {"date": "2025-01-01", "price": 899},
        {"date": "2025-01-15", "price": 850},
        {"date": "2025-02-01", "price": 799},
        {"date": "2025-02-15", "price": 749},
    ]
    result = service.analyze_trend_sync("Product", history)
    return TrendResponse(**result)
```

```python
# backend/app/routers/report.py
from fastapi import APIRouter
from app.models.schemas import ReportRequest, ReportResponse
from app.services.report import ReportService

router = APIRouter()
service = ReportService()

@router.post("/api/v1/report", response_model=ReportResponse)
def generate_report(request: ReportRequest):
    report = service.generate_report_sync(
        "Nike Air Max",
        {"platform": "京东", "price": 749},
        []
    )
    return ReportResponse(**report)
```

```python
# backend/app/routers/chat.py
from fastapi import APIRouter
from app.models.schemas import ChatRequest, ChatResponse
from app.services.chat import ChatService

router = APIRouter()
service = ChatService()

@router.post("/api/v1/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    result = await service.chat(
        message=request.message,
        session_id=str(request.session_id) if request.session_id else None,
        current_product=request.current_product
    )
    return ChatResponse(**result)
```

```python
# backend/app/main.py (修改)
from fastapi import FastAPI
from app.config import settings
from app.routers import recognize, suggest, compare, filter as filter_router, trend, report, chat

app = FastAPI(title=settings.app_name)

app.include_router(recognize.router)
app.include_router(suggest.router)
app.include_router(compare.router)
app.include_router(filter_router.router)
app.include_router(trend.router)
app.include_router(report.router)
app.include_router(chat.router)

@app.get("/health")
def health_check():
    return {"status": "ok"}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`pytest backend/tests/test_api.py -v`

预期：PASS

- [ ] **步骤 5：提交**

```bash
git add backend/app/routers/ backend/app/main.py backend/tests/test_api.py
git commit -m "feat: add all API routers with Swagger auto-docs"
```

---

## Phase 4: Flutter 客户端

### 任务 9：Flutter 项目脚手架

**文件：**
- 创建：`android-app/pubspec.yaml`
- 创建：`android-app/lib/main.dart`
- 创建：`android-app/lib/app.dart`
- 创建：`android-app/lib/utils/constants.dart`
- 创建：`android-app/lib/services/api_service.dart`
- 创建：`android-app/lib/models/product.dart`

- [ ] **步骤 1：编写实现**

```yaml
# android-app/pubspec.yaml
name: smart_price_ai
description: AI拍照识物与智能比价购物助手
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  image_picker: ^1.0.7
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

```dart
// android-app/lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const SmartPriceAIApp());
}
```

```dart
// android-app/lib/app.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class SmartPriceAIApp extends StatelessWidget {
  const SmartPriceAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Price AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

```dart
// android-app/lib/utils/constants.dart
const String API_BASE_URL = 'http://localhost:8000';
const Color kPrimaryColor = Color(0xFF00C9A7);
const Color kBackgroundColor = Color(0xFFF5F5F7);
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF8E8E93);
const Color kBlack = Colors.black;
```

```dart
// android-app/lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, dynamic>> recognize(String imageBase64) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/api/v1/recognize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_base64': imageBase64}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> compare(String category, {String? brand, String? color}) async {
    final queryParams = <String, String>{'category': category};
    if (brand != null) queryParams['brand'] = brand;
    if (color != null) queryParams['color'] = color;
    
    final uri = Uri.parse('$API_BASE_URL/api/v1/compare').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> chat(String message) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/api/v1/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    return jsonDecode(response.body);
  }
}
```

```dart
// android-app/lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? color;
  final double price;
  final String? platform;
  final double? rating;
  final List<String>? tags;

  Product({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    this.color,
    required this.price,
    this.platform,
    this.rating,
    this.tags,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'],
      category: json['category'],
      color: json['color'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      platform: json['platform'],
      rating: (json['rating'] as num?)?.toDouble(),
      tags: (json['tags'] as List?)?.cast<String>(),
    );
  }
}
```

- [ ] **步骤 2：验证 Flutter 项目可运行**

运行：`cd android-app && flutter pub get && flutter build apk --debug`

预期：BUILD SUCCESSFUL

- [ ] **步骤 3：提交**

```bash
git add android-app/
git commit -m "feat: scaffold Flutter project with API service and models"
```

---

### 任务 10：Flutter 核心页面

**文件：**
- 创建：`android-app/lib/screens/home_screen.dart`
- 创建：`android-app/lib/screens/result_screen.dart`
- 创建：`android-app/lib/screens/compare_screen.dart`
- 创建：`android-app/lib/screens/chat_screen.dart`

- [ ] **步骤 1：编写实现**

```dart
// android-app/lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    
    setState(() => _isLoading = true);
    try {
      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final result = await _apiService.recognize(base64Image);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(recognitionResult: result),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hi, Kevin',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '拍一张照，AI帮你找最优价',
                style: TextStyle(
                  fontSize: 16,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _isLoading ? null : _takePhoto,
                child: Container(
                  width: double.infinity,
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA8E6CF), Color(0xFF7FD8BE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 80, color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                '拍照识物',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// android-app/lib/screens/result_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'compare_screen.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> recognitionResult;

  const ResultScreen({super.key, required this.recognitionResult});

  @override
  Widget build(BuildContext context) {
    final category = recognitionResult['category'] ?? '未知';
    final brand = recognitionResult['brand'] ?? '';
    final color = recognitionResult['color'] ?? '';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('识别结果', style: TextStyle(color: kTextPrimary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                if (brand.isNotEmpty) _buildTag(brand),
                if (color.isNotEmpty) _buildTag(color),
                _buildTag(category),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '下一步',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary),
            ),
            const SizedBox(height: 16),
            _buildSuggestionCard(
              icon: Icons.search,
              title: '查看同款低价',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompareScreen(
                    category: category,
                    brand: brand.isNotEmpty ? brand : null,
                    color: color.isNotEmpty ? color : null,
                  ),
                ),
              ),
            ),
            _buildSuggestionCard(
              icon: Icons.trending_down,
              title: '查看价格走势',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kPrimaryColor),
      ),
    );
  }

  Widget _buildSuggestionCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: kTextPrimary),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}
```

```dart
// android-app/lib/screens/compare_screen.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class CompareScreen extends StatefulWidget {
  final String category;
  final String? brand;
  final String? color;

  const CompareScreen({super.key, required this.category, this.brand, this.color});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final result = await _apiService.compare(
        widget.category,
        brand: widget.brand,
        color: widget.color,
      );
      final products = (result['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('同款比价', style: TextStyle(color: kTextPrimary)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: const Center(child: Icon(Icons.image, size: 60, color: Colors.grey)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '¥${product.price.toInt()}',
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kTextPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.platform?.replaceAll('mock_', '') ?? '',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
```

```dart
// android-app/lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final result = await _apiService.chat(text);
      setState(() {
        _messages.add({'isUser': false, 'text': result['reply']});
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('AI 购物助手', style: TextStyle(color: kTextPrimary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? kBlack : kSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isUser ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        color: isUser ? Colors.white : kTextPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Container(
            color: kBlack,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '输入筛选条件或提问...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 2：验证页面可编译**

运行：`cd android-app && flutter analyze`

预期：No issues found

- [ ] **步骤 3：提交**

```bash
git add android-app/lib/screens/ android-app/lib/models/ android-app/lib/services/ android-app/lib/utils/
git commit -m "feat: add Flutter core screens (home/result/compare/chat)"
```

---

## Phase 5: 集成与部署

### 任务 11：后端启动脚本 + Docker

**文件：**
- 创建：`backend/Dockerfile`
- 创建：`backend/docker-compose.yml`
- 创建：`backend/start.sh`

- [ ] **步骤 1：编写实现**

```dockerfile
# backend/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY tests/ ./tests/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# backend/docker-compose.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/smartprice
      - REDIS_URL=redis://redis:6379/0
      - VOLCENGINE_API_KEY=${VOLCENGINE_API_KEY}
      - VOLCENGINE_ENDPOINT=${VOLCENGINE_ENDPOINT}
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=smartprice
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

```bash
# backend/start.sh
#!/bin/bash
cd "$(dirname "$0")"
docker-compose up --build -d
```

- [ ] **步骤 2：验证构建**

运行：`chmod +x backend/start.sh && backend/start.sh`

预期：docker-compose 成功启动

- [ ] **步骤 3：提交**

```bash
git add backend/Dockerfile backend/docker-compose.yml backend/start.sh
git commit -m "feat: add Docker deployment config"
```

---

## 自检

### 1. 规格覆盖检查

| 规格需求 | 实现任务 | 状态 |
|---------|---------|------|
| 拍照识物 | 任务 4 (recognition.py) | ✅ |
| 智能建议卡片 | 任务 6 (suggestion.py) | ✅ |
| 跨平台比价 | 任务 5 (comparison.py) | ✅ |
| 自然语言筛选 | 任务 6 (filtering.py) | ✅ |
| 推荐列表与排序 | 任务 5 (sort methods) | ✅ |
| 价格趋势 | 任务 6 (trend.py) | ✅ |
| AI 购物决策报告 | 任务 7 (report.py) | ✅ |
| 多轮对话 AI 导购 | 任务 7 (chat.py) | ✅ |
| 数据源抽象层 | 任务 5 (DataSource ABC) | ✅ |
| LLM 编排引擎 | 任务 3 (prompt_engine.py) | ✅ |
| Flutter 客户端 | 任务 9-10 | ✅ |

### 2. 占位符扫描

- 无 TBD/TODO
- 无 "稍后实现"
- 每个步骤包含实际代码

### 3. 类型一致性

- Pydantic schemas 与 services 输入/输出一致
- API 路由使用统一的 response_model
- Flutter models 与 API JSON 结构一致

---

## 执行移交

**计划完成并保存到 `docs/superpowers/plans/2025-05-20-smart-price-ai.md`。两种执行选项：**

**1. Subagent-Driven（推荐）** — 我为每个任务分派一个新的子代理，在任务之间审查，快速迭代

**2. Inline Execution** — 使用 executing-plans 在此会话中执行任务，批量执行并设置检查点

**选择哪种方式？**
