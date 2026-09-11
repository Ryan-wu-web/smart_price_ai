"""Evidence-bound compatibility report. Client prices/names are not facts."""
from typing import Any
from app.models.schemas import ReportResponse
from app.services.knowledge import ProductCatalog


class ReportService:
    def __init__(self, catalog: ProductCatalog):
        self.catalog = catalog

    async def generate_report(self, product_name: str, best_choice: dict[str, Any],
                              alternatives: list[dict[str, Any]]) -> ReportResponse:
        product_id = best_choice.get("id") or best_choice.get("product_id")
        detail = self.catalog.get_product(product_id) if isinstance(product_id, str) else None
        if detail is None:
            raise ValueError("请选择有证据ID的本地样例商品后生成报告。")
        p = detail.product
        # Alternatives are not a verified ranking; do not repeat untrusted input.
        return ReportResponse(
            summary=f"{p.name}；样例价格区间 ¥{p.price_range.min:g}–¥{p.price_range.max:g}。"
                    "此为商品知识摘要，不代表满足个人条件或优于其他商品。",
            pros=p.advantages, cons=p.disadvantages,
            recommendation="；".join(p.buying_advice) + "。如需个性化排序，请进入AI购物决策对话。",
            product_id=p.product_id, evidence_ids=[p.evidence_id], catalog=detail.catalog,
        )
