import random
from datetime import datetime, timedelta

from app.models.schemas import TrendResponse


class TrendService:
    def _generate_mock_history(self, product_name: str, base_price: float) -> list[dict]:
        """基于基准价格生成 90 天 Mock 历史价格数据"""
        history = []
        price = float(base_price)
        end_date = datetime.now()
        platforms = ["京东", "淘宝", "天猫", "拼多多"]

        # 使用 product_name 的 hash 作为随机种子，保证同一商品每次生成的数据一致
        seed = hash(product_name) % 10000
        rng = random.Random(seed)

        for i in range(90, 0, -1):
            date = end_date - timedelta(days=i)
            # 每天价格波动 ±5%
            change = rng.uniform(-0.05, 0.05)
            price = max(base_price * 0.7, min(base_price * 1.3, price * (1 + change)))

            # 每 3 天换一个平台
            platform = platforms[(90 - i) // 3 % len(platforms)]

            history.append({
                "date": date.strftime("%m-%d"),
                "price": round(price, 2),
                "platform": platform,
            })
        return history

    def analyze_trend_sync(
        self, product_name: str, history_prices: list[dict]
    ) -> TrendResponse:
        if not history_prices:
            return TrendResponse(
                trend="暂无数据", advice="暂无足够历史价格数据", confidence=0.0
            )
        sorted_prices = sorted(history_prices, key=lambda x: x.get("date", ""))
        first_price = sorted_prices[0].get("price", 0)
        last_price = sorted_prices[-1].get("price", 0)
        min_price = min(p.get("price", 0) for p in sorted_prices)
        max_price = max(p.get("price", 0) for p in sorted_prices)

        if last_price > first_price * 1.05:
            trend = "上涨"
            advice = "价格呈上涨趋势，如非急需可观望等待降价"
            confidence = min(0.9, (last_price - first_price) / first_price)
        elif last_price < first_price * 0.95:
            trend = "下跌"
            if last_price <= min_price * 1.02:
                advice = "价格处于低位，建议立即购买"
                confidence = 0.85
            else:
                advice = "价格呈下跌趋势，可继续等待更低价"
                confidence = min(0.8, (first_price - last_price) / first_price)
        else:
            trend = "平稳"
            advice = "价格波动不大，可根据需求随时购买"
            confidence = 0.7

        return TrendResponse(
            trend=trend,
            advice=advice,
            confidence=round(confidence, 2),
            history_prices=sorted_prices,
        )
