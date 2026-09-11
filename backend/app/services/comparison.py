"""Legacy comparison API projected from the same immutable sample catalog."""
from app.models.schemas import CompareQuery, ProductResponse
from app.services.knowledge import ProductCatalog


class ComparisonService:
    def __init__(self, catalog: ProductCatalog | None = None):
        self.catalog = catalog if catalog is not None else ProductCatalog()

    def compare(self, query: CompareQuery) -> list[ProductResponse]:
        # No official-channel evidence exists. Never silently drop a filter.
        if query.filter_mode == "official":
            return []
        results = []
        for p in self.catalog.iter_products():
            color = p.parameters.get("color")
            color_value = str(color.value) if color and color.value is not None else ""
            if p.category.casefold() != query.category.strip().casefold():
                continue
            if query.brand and p.brand.casefold() != query.brand.strip().casefold():
                continue
            if query.color and color_value.casefold() != query.color.strip().casefold():
                continue
            results.append(ProductResponse(
                id=p.product_id, name=p.name, brand=p.brand, category=p.category,
                color=color_value, price=p.price_range.min, price_max=p.price_range.max,
                platform="本地样例库", tags=["虚构样例"],
                evidence_id=p.evidence_id, source_id=p.source_id,
            ))
        # No sales/rating evidence: stable ID order is not a recommendation score.
        return sorted(results, key=lambda p: (p.price, p.id) if query.sort_by == "price" else (p.id,))
