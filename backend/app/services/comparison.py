from abc import ABC, abstractmethod
from datetime import datetime, timezone
import random

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
        self.MOCK_PRODUCTS: list[dict] = []
        now = datetime.now(timezone.utc)

        base_items = [
            {"name": "Nike Air Max 90 黑色 42码", "brand": "Nike", "category": "运动鞋", "color": "黑色", "price": 749.0},
            {"name": "Nike Air Force 1 白色 42码", "brand": "Nike", "category": "运动鞋", "color": "白色", "price": 799.0},
            {"name": "Nike Dunk Low 熊猫色 42码", "brand": "Nike", "category": "运动鞋", "color": "熊猫色", "price": 899.0},
            {"name": "Adidas Ultraboost 22 灰色 42码", "brand": "Adidas", "category": "运动鞋", "color": "灰色", "price": 1099.0},
            {"name": "Adidas Samba OG 黑色 42码", "brand": "Adidas", "category": "运动鞋", "color": "黑色", "price": 799.0},
            {"name": "李宁 韦德之道10 白色 42码", "brand": "李宁", "category": "运动鞋", "color": "白色", "price": 1299.0},
            {"name": "安踏 KT8 蓝色 42码", "brand": "安踏", "category": "运动鞋", "color": "蓝色", "price": 699.0},
            {"name": "安踏 水花5 白色 42码", "brand": "安踏", "category": "运动鞋", "color": "白色", "price": 399.0},
            {"name": "Nike Court Vision 白色 42码", "brand": "Nike", "category": "休闲鞋", "color": "白色", "price": 499.0},
            {"name": "Adidas Continental 80 黑色 42码", "brand": "Adidas", "category": "休闲鞋", "color": "黑色", "price": 599.0},
            {"name": "李宁 惟吾Pro 灰色 42码", "brand": "李宁", "category": "休闲鞋", "color": "灰色", "price": 399.0},
            {"name": "Nike 运动T恤 黑色 M码", "brand": "Nike", "category": "T恤", "color": "黑色", "price": 199.0},
            {"name": "Adidas 三叶草T恤 白色 M码", "brand": "Adidas", "category": "T恤", "color": "白色", "price": 229.0},
            {"name": "Uniqlo U系列T恤 灰色 M码", "brand": "Uniqlo", "category": "T恤", "color": "灰色", "price": 99.0},
            {"name": "Uniqlo 快干T恤 白色 M码", "brand": "Uniqlo", "category": "T恤", "color": "白色", "price": 79.0},
            {"name": "ZARA 印花T恤 黑色 M码", "brand": "ZARA", "category": "T恤", "color": "黑色", "price": 129.0},
            {"name": "H&M 基础T恤 白色 M码", "brand": "H&M", "category": "T恤", "color": "白色", "price": 59.0},
            {"name": "李宁 运动T恤 蓝色 M码", "brand": "李宁", "category": "T恤", "color": "蓝色", "price": 89.0},
            {"name": "安踏 速干T恤 黑色 M码", "brand": "安踏", "category": "T恤", "color": "黑色", "price": 69.0},
            {"name": "Uniqlo 修身牛仔裤 深蓝 32码", "brand": "Uniqlo", "category": "牛仔裤", "color": "深蓝", "price": 299.0},
            {"name": "ZARA 直筒牛仔裤 浅蓝 32码", "brand": "ZARA", "category": "牛仔裤", "color": "浅蓝", "price": 259.0},
            {"name": "太平鸟 破洞牛仔裤 黑色 32码", "brand": "太平鸟", "category": "牛仔裤", "color": "黑色", "price": 199.0},
            {"name": "Levi's 501 原色 32码", "brand": "Levi's", "category": "牛仔裤", "color": "原色", "price": 599.0},
            {"name": "H&M 弹力牛仔裤 深蓝 32码", "brand": "H&M", "category": "牛仔裤", "color": "深蓝", "price": 149.0},
            {"name": "Nike 运动外套 黑色 M码", "brand": "Nike", "category": "外套", "color": "黑色", "price": 499.0},
            {"name": "Adidas 三叶草外套 灰色 M码", "brand": "Adidas", "category": "外套", "color": "灰色", "price": 599.0},
            {"name": "Uniqlo 摇粒绒外套 米色 M码", "brand": "Uniqlo", "category": "外套", "color": "米色", "price": 199.0},
            {"name": "ZARA 皮夹克 黑色 M码", "brand": "ZARA", "category": "外套", "color": "黑色", "price": 599.0},
            {"name": "太平鸟 羽绒服 藏青 M码", "brand": "太平鸟", "category": "外套", "color": "藏青", "price": 799.0},
            {"name": "李宁 冲锋衣 黑色 M码", "brand": "李宁", "category": "外套", "color": "黑色", "price": 399.0},
            {"name": "Nike 连帽卫衣 灰色 M码", "brand": "Nike", "category": "卫衣", "color": "灰色", "price": 399.0},
            {"name": "Adidas 圆领卫衣 黑色 M码", "brand": "Adidas", "category": "卫衣", "color": "黑色", "price": 349.0},
            {"name": "Uniqlo 运动卫衣 米色 M码", "brand": "Uniqlo", "category": "卫衣", "color": "米色", "price": 149.0},
            {"name": "ZARA 印花卫衣 白色 M码", "brand": "ZARA", "category": "卫衣", "color": "白色", "price": 199.0},
            {"name": "太平鸟 连帽卫衣 灰色 M码", "brand": "太平鸟", "category": "卫衣", "color": "灰色", "price": 259.0},
            {"name": "Nike 运动裤 黑色 M码", "brand": "Nike", "category": "运动裤", "color": "黑色", "price": 249.0},
            {"name": "Adidas 训练裤 灰色 M码", "brand": "Adidas", "category": "运动裤", "color": "灰色", "price": 229.0},
            {"name": "Uniqlo 休闲裤 米色 M码", "brand": "Uniqlo", "category": "休闲裤", "color": "米色", "price": 149.0},
            {"name": "安踏 运动裤 黑色 M码", "brand": "安踏", "category": "运动裤", "color": "黑色", "price": 129.0},
            {"name": "Nike 运动袜 白色 3双装", "brand": "Nike", "category": "袜子", "color": "白色", "price": 79.0},
            {"name": "Adidas 训练袜 黑色 3双装", "brand": "Adidas", "category": "袜子", "color": "黑色", "price": 69.0},
            {"name": "iPhone 15 Pro 256GB 钛金属", "brand": "Apple", "category": "手机", "color": "钛金属", "price": 7999.0},
            {"name": "iPhone 15 128GB 粉色", "brand": "Apple", "category": "手机", "color": "粉色", "price": 5999.0},
            {"name": "小米14 12+256GB 黑色", "brand": "小米", "category": "手机", "color": "黑色", "price": 3999.0},
            {"name": "小米14 Pro 12+256GB 白色", "brand": "小米", "category": "手机", "color": "白色", "price": 4999.0},
            {"name": "华为Mate60 Pro 256GB 雅川青", "brand": "华为", "category": "手机", "color": "雅川青", "price": 6999.0},
            {"name": "华为P60 128GB 洛可可白", "brand": "华为", "category": "手机", "color": "洛可可白", "price": 4488.0},
            {"name": "Samsung Galaxy S24 256GB 紫色", "brand": "三星", "category": "手机", "color": "紫色", "price": 5999.0},
            {"name": "三星Galaxy A54 128GB 黑色", "brand": "三星", "category": "手机", "color": "黑色", "price": 2999.0},
            {"name": "AirPods Pro 2 白色", "brand": "Apple", "category": "耳机", "color": "白色", "price": 1899.0},
            {"name": "Sony WH-1000XM5 黑色", "brand": "索尼", "category": "耳机", "color": "黑色", "price": 2499.0},
            {"name": "Bose QC45 黑色", "brand": "Bose", "category": "耳机", "color": "黑色", "price": 1999.0},
            {"name": "小米Buds 4 Pro 银色", "brand": "小米", "category": "耳机", "color": "银色", "price": 699.0},
            {"name": "华为FreeBuds Pro 3 白色", "brand": "华为", "category": "耳机", "color": "白色", "price": 999.0},
            {"name": "iPad Air 5 64GB 蓝色", "brand": "Apple", "category": "平板", "color": "蓝色", "price": 4799.0},
            {"name": "iPad Pro 11 128GB 银色", "brand": "Apple", "category": "平板", "color": "银色", "price": 6799.0},
            {"name": "小米Pad 6 Pro 128GB 黑色", "brand": "小米", "category": "平板", "color": "黑色", "price": 2399.0},
            {"name": "华为MatePad 11 128GB 海岛蓝", "brand": "华为", "category": "平板", "color": "海岛蓝", "price": 2499.0},
            {"name": "Logitech MX Keys 黑色", "brand": "Logitech", "category": "键盘", "color": "黑色", "price": 699.0},
            {"name": "Logitech K380 粉色", "brand": "Logitech", "category": "键盘", "color": "粉色", "price": 199.0},
            {"name": "小米机械键盘 黑色", "brand": "小米", "category": "键盘", "color": "黑色", "price": 299.0},
            {"name": "Logitech MX Master 3S 灰色", "brand": "Logitech", "category": "鼠标", "color": "灰色", "price": 799.0},
            {"name": "Logitech G502 黑色", "brand": "Logitech", "category": "鼠标", "color": "黑色", "price": 399.0},
            {"name": "Apple 20W快充头 白色", "brand": "Apple", "category": "充电器", "color": "白色", "price": 149.0},
            {"name": "小米67W充电器 白色", "brand": "小米", "category": "充电器", "color": "白色", "price": 99.0},
            {"name": "Anker 65W氮化镓 黑色", "brand": "Anker", "category": "充电器", "color": "黑色", "price": 169.0},
            {"name": "Chanel 丝绒唇膏58 复古红", "brand": "Chanel", "category": "口红", "color": "复古红", "price": 380.0},
            {"name": "Dior 烈焰蓝金999 正红", "brand": "Dior", "category": "口红", "color": "正红", "price": 370.0},
            {"name": "YSL 小金条21 复古红", "brand": "YSL", "category": "口红", "color": "复古红", "price": 350.0},
            {"name": "完美日记 小细跟L04 红棕", "brand": "完美日记", "category": "口红", "color": "红棕", "price": 89.0},
            {"name": "花西子 雕花口红M116 烂番茄", "brand": "花西子", "category": "口红", "color": "烂番茄", "price": 129.0},
            {"name": "MAC 子弹头Chili 砖红", "brand": "MAC", "category": "口红", "color": "砖红", "price": 170.0},
            {"name": "SK-II 前男友面膜 10片", "brand": "SK-II", "category": "面膜", "color": "白色", "price": 1060.0},
            {"name": "欧莱雅 玻尿酸面膜 15片", "brand": "欧莱雅", "category": "面膜", "color": "白色", "price": 159.0},
            {"name": "完美日记 神经酰胺面膜 20片", "brand": "完美日记", "category": "面膜", "color": "白色", "price": 79.0},
            {"name": "花西子 花露凝萃面膜 10片", "brand": "花西子", "category": "面膜", "color": "白色", "price": 99.0},
            {"name": "敷尔佳 白膜 5片", "brand": "敷尔佳", "category": "面膜", "color": "白色", "price": 89.0},
            {"name": "Chanel 五号香水 50ml", "brand": "Chanel", "category": "香水", "color": "透明", "price": 1150.0},
            {"name": "Dior 花漾甜心 50ml", "brand": "Dior", "category": "香水", "color": "粉色", "price": 920.0},
            {"name": "YSL 黑鸦片 50ml", "brand": "YSL", "category": "香水", "color": "黑色", "price": 1090.0},
            {"name": "SK-II 神仙水套装 230ml", "brand": "SK-II", "category": "护肤套装", "color": "透明", "price": 1540.0},
            {"name": "欧莱雅 复颜抗皱套装", "brand": "欧莱雅", "category": "护肤套装", "color": "白色", "price": 369.0},
            {"name": "完美日记 护肤三件套", "brand": "完美日记", "category": "护肤套装", "color": "白色", "price": 199.0},
            {"name": "兰蔻 小黑瓶精华 50ml", "brand": "兰蔻", "category": "精华", "color": "黑色", "price": 1080.0},
            {"name": "宜家 SAMLA 收纳盒 大号 透明", "brand": "宜家", "category": "收纳盒", "color": "透明", "price": 29.9},
            {"name": "MUJI 聚丙烯收纳盒 中号 白色", "brand": "MUJI", "category": "收纳盒", "color": "白色", "price": 45.0},
            {"name": "网易严选 抽屉收纳盒 灰色", "brand": "网易严选", "category": "收纳盒", "color": "灰色", "price": 39.0},
            {"name": "小米米家台灯1S 白色", "brand": "小米有品", "category": "台灯", "color": "白色", "price": 179.0},
            {"name": "网易严选 护眼台灯 白色", "brand": "网易严选", "category": "台灯", "color": "白色", "price": 199.0},
            {"name": "MUJI LED台灯 白色", "brand": "MUJI", "category": "台灯", "color": "白色", "price": 249.0},
            {"name": "宜家 GURLI 抱枕套 米色", "brand": "宜家", "category": "抱枕", "color": "米色", "price": 29.9},
            {"name": "MUJI 棉抱枕 灰色", "brand": "MUJI", "category": "抱枕", "color": "灰色", "price": 79.0},
            {"name": "网易严选 乳胶抱枕 白色", "brand": "网易严选", "category": "抱枕", "color": "白色", "price": 89.0},
            {"name": "宜家 IKEA365+ 煎锅 24cm 黑色", "brand": "宜家", "category": "厨具", "color": "黑色", "price": 99.0},
            {"name": "网易严选 铸铁锅 22cm 红色", "brand": "网易严选", "category": "厨具", "color": "红色", "price": 199.0},
            {"name": "小米有品 不粘锅 28cm 黑色", "brand": "小米有品", "category": "厨具", "color": "黑色", "price": 129.0},
            {"name": "MUJI 马克杯 白色", "brand": "MUJI", "category": "杯子", "color": "白色", "price": 29.0},
            {"name": "宜家 法格里克 杯子 蓝色", "brand": "宜家", "category": "杯子", "color": "蓝色", "price": 9.9},
            {"name": "网易严选 四件套 1.5m 灰色", "brand": "网易严选", "category": "床上用品", "color": "灰色", "price": 299.0},
            {"name": "MUJI 天竺棉被套 双人 米色", "brand": "MUJI", "category": "床上用品", "color": "米色", "price": 399.0},
        ]

        platforms = {
            "mock_jd": {"mult": 1.0, "tags": ["自营", "官方", "包邮"]},
            "mock_taobao": {"mult": (0.95, 1.1), "tags": ["官方", "七天退换"]},
            "mock_pdd": {"mult": (0.85, 0.95), "tags": ["百亿补贴", "包邮"]},
        }

        for item in base_items:
            jd_price = item["price"]
            for platform, cfg in platforms.items():
                if platform == "mock_jd":
                    price = round(jd_price, 2)
                else:
                    mult = random.uniform(cfg["mult"][0], cfg["mult"][1])
                    price = round(jd_price * mult, 2)
                original_price = round(price * random.uniform(1.1, 1.3), 2)
                rating = round(random.uniform(4.5, 5.0), 1)
                url_text = "+".join(item["name"].split()[:3])
                image_url = f"https://via.placeholder.com/300x300/00B4D8/FFFFFF?text={url_text}"
                self.MOCK_PRODUCTS.append({
                    "name": item["name"],
                    "brand": item["brand"],
                    "category": item["category"],
                    "color": item["color"],
                    "price": price,
                    "original_price": original_price,
                    "platform": platform,
                    "rating": rating,
                    "tags": cfg["tags"][:],
                    "image_url": image_url,
                })

        for i, item in enumerate(self.MOCK_PRODUCTS):
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
        
        # 第二步：如果精确匹配为空，尝试包含匹配
        if not results:
            results = [p for p in self._data if category in p.category or p.category in category]
            logger.info(f"[MockDataSource] loose category match: {len(results)} items")
        
        # 第三步：兜底
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
            if brand_results:
                results = brand_results
            logger.info(f"[MockDataSource] after brand filter: {len(results)} items")
        
        # 颜色过滤
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
