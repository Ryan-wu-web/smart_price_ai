from abc import ABC, abstractmethod
from datetime import datetime, timezone

from app.models.schemas import CompareQuery, ProductResponse


class DataSource(ABC):
    @abstractmethod
    def search(
        self, category: str, brand: str | None = None, color: str | None = None
    ) -> list[ProductResponse]:
        raise NotImplementedError


class MockDataSource(DataSource):
    def __init__(self):
        self._data: list[ProductResponse] = []
        now = datetime.now(timezone.utc)
        base_items = [
            {"name": "Nike Air Force 1 空军一号", "brand": "Nike", "category": "鞋", "color": "白色", "price": 749.0, "platform": "淘宝", "rating": 4.9, "tags": ["经典", "板鞋"]},
            {"name": "Nike Air Force 1 空军一号", "brand": "Nike", "category": "鞋", "color": "白色", "price": 799.0, "platform": "京东", "rating": 4.8, "tags": ["经典", "板鞋"]},
            {"name": "Nike Air Force 1 空军一号", "brand": "Nike", "category": "鞋", "color": "白色", "price": 699.0, "platform": "拼多多", "rating": 4.7, "tags": ["经典", "百亿补贴"]},
            {"name": "Nike Air Max 90", "brand": "Nike", "category": "鞋", "color": "白色", "price": 899.0, "platform": "淘宝", "rating": 4.8, "tags": ["运动", "经典"]},
            {"name": "Nike Air Max 90", "brand": "Nike", "category": "鞋", "color": "黑色", "price": 799.0, "platform": "京东", "rating": 4.7, "tags": ["运动", "经典"]},
            {"name": "Adidas Ultraboost 22", "brand": "Adidas", "category": "鞋", "color": "灰色", "price": 1099.0, "platform": "天猫", "rating": 4.9, "tags": ["跑步", "缓震"]},
            {"name": "Adidas Ultraboost 22", "brand": "Adidas", "category": "鞋", "color": "黑色", "price": 999.0, "platform": "淘宝", "rating": 4.8, "tags": ["跑步", "缓震"]},
            {"name": "iPhone 15 Pro", "brand": "Apple", "category": "手机", "color": "钛金属", "price": 7999.0, "platform": "京东", "rating": 4.9, "tags": ["5G", "旗舰"]},
            {"name": "iPhone 15 Pro", "brand": "Apple", "category": "手机", "color": "黑色", "price": 7899.0, "platform": "天猫", "rating": 4.8, "tags": ["5G", "旗舰"]},
            {"name": "Samsung Galaxy S24", "brand": "Samsung", "category": "手机", "color": "紫色", "price": 5999.0, "platform": "淘宝", "rating": 4.7, "tags": ["AI", "拍照"]},
            {"name": "Samsung Galaxy S24", "brand": "Samsung", "category": "手机", "color": "黑色", "price": 5799.0, "platform": "京东", "rating": 4.6, "tags": ["AI", "拍照"]},
            {"name": "MacBook Pro 14", "brand": "Apple", "category": "笔记本", "color": "银色", "price": 14999.0, "platform": "天猫", "rating": 4.9, "tags": ["M3", "专业"]},
            {"name": "MacBook Pro 14", "brand": "Apple", "category": "笔记本", "color": "深空灰", "price": 14999.0, "platform": "京东", "rating": 4.9, "tags": ["M3", "专业"]},
            {"name": "Dell XPS 13", "brand": "Dell", "category": "笔记本", "color": "银色", "price": 8999.0, "platform": "淘宝", "rating": 4.5, "tags": ["轻薄", "办公"]},
            {"name": "Dell XPS 13", "brand": "Dell", "category": "笔记本", "color": "黑色", "price": 8799.0, "platform": "京东", "rating": 4.4, "tags": ["轻薄", "办公"]},
            {"name": "YSL 小金条口红", "brand": "YSL", "category": "口红", "color": "复古红", "price": 350.0, "platform": "天猫", "rating": 4.8, "tags": ["哑光", "显白"]},
            {"name": "YSL 小金条口红", "brand": "YSL", "category": "口红", "color": "豆沙色", "price": 340.0, "platform": "京东", "rating": 4.7, "tags": ["哑光", "日常"]},
            {"name": "Dior 烈焰蓝金", "brand": "Dior", "category": "口红", "color": "正红", "price": 370.0, "platform": "淘宝", "rating": 4.9, "tags": ["滋润", "经典"]},
            {"name": "Dior 烈焰蓝金", "brand": "Dior", "category": "口红", "color": "豆沙色", "price": 360.0, "platform": "天猫", "rating": 4.8, "tags": ["滋润", "日常"]},
            {"name": "IKEA 波昂扶手椅", "brand": "IKEA", "category": "家具", "color": "原木色", "price": 399.0, "platform": "京东", "rating": 4.6, "tags": ["简约", "舒适"]},
            {"name": "IKEA 波昂扶手椅", "brand": "IKEA", "category": "家具", "color": "黑色", "price": 399.0, "platform": "天猫", "rating": 4.5, "tags": ["简约", "舒适"]},
            {"name": "无印良品懒人沙发", "brand": "MUJI", "category": "家具", "color": "米色", "price": 899.0, "platform": "淘宝", "rating": 4.7, "tags": ["日式", "舒适"]},
            {"name": "无印良品懒人沙发", "brand": "MUJI", "category": "家具", "color": "灰色", "price": 899.0, "platform": "京东", "rating": 4.6, "tags": ["日式", "舒适"]},
        ]
        for i, item in enumerate(base_items):
            self._data.append(
                ProductResponse(
                    id=f"mock-{i}",
                    created_at=now,
                    **item,
                )
            )

    def search(
        self, category: str, brand: str | None = None, color: str | None = None
    ) -> list[ProductResponse]:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"[MockDataSource] search called: category={category}, brand={brand}, color={color}")
        
        # 第一步：精确匹配 category
        results = [p for p in self._data if p.category == category]
        logger.info(f"[MockDataSource] exact category match: {len(results)} items")
        
        # 第二步：如果精确匹配为空，尝试包含匹配（如"运动休闲板鞋"包含"鞋"）
        if not results:
            results = [p for p in self._data if category in p.category or p.category in category]
            logger.info(f"[MockDataSource] loose category match: {len(results)} items")
        
        # 第三步：如果还是为空，返回所有商品（兜底）
        if not results:
            results = list(self._data)
            for p in results:
                if "fallback" not in p.tags:
                    p.tags.append("fallback")
            logger.info(f"[MockDataSource] returning all {len(results)} items as fallback")
        
        # 品牌过滤
        if brand:
            brand_clean = brand.split("（")[0].strip().lower()
            brand_results = [p for p in results if p.brand.lower() == brand_clean]
            if brand_results:  # 有匹配才过滤，否则保留原结果
                results = brand_results
            logger.info(f"[MockDataSource] after brand filter: {len(results)} items")
        
        # 颜色过滤（宽松）
        if color:
            color_clean = color.replace("纯", "").replace("色", "").strip().lower()
            color_results = [p for p in results if color_clean in p.color.lower() or p.color.lower() in color.lower()]
            if color_results:
                results = color_results
            logger.info(f"[MockDataSource] after color filter: {len(results)} items")
        
        return results


class ComparisonService:
    def __init__(self, data_source: DataSource | None = None):
        self.data_source = data_source or MockDataSource()

    def compare(self, query: CompareQuery) -> list[ProductResponse]:
        results = self.data_source.search(
            query.category, query.brand, query.color
        )
        if query.sort_by == "price":
            results = sort_by_price(results)
        elif query.sort_by == "rating":
            results = sort_by_rating(results)
        return results


def sort_by_price(products: list[ProductResponse]) -> list[ProductResponse]:
    return sorted(products, key=lambda p: p.price)


def sort_by_rating(products: list[ProductResponse]) -> list[ProductResponse]:
    return sorted(products, key=lambda p: p.rating, reverse=True)
