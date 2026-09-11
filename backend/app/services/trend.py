"""Historical price data is deliberately not connected in this local edition."""
from app.models.schemas import TrendResponse


class TrendService:
    def unavailable(self) -> TrendResponse:
        return TrendResponse(
            trend="未接入历史价格",
            advice="本项目仅提供本地虚构样例价格区间，没有可验证的历史价格，不能判断涨跌或最佳购买时机。",
            confidence=0.0, history_prices=[],
        )
