import pytest

from app.models.schemas import CompareQuery, ProductResponse
from app.services.comparison import ComparisonService, MockDataSource, sort_by_price, sort_by_rating


def test_mock_data_source_search():
    ds = MockDataSource()
    results = ds.search("鞋")
    assert len(results) >= 4
    results = ds.search("鞋", brand="Nike")
    assert all(p.brand == "Nike" for p in results)
    results = ds.search("鞋", color="黑色")
    assert all(p.color == "黑色" for p in results)


def test_compare_sort_by_price():
    service = ComparisonService()
    query = CompareQuery(category="鞋", sort_by="price")
    results = service.compare(query)
    assert results == sorted(results, key=lambda p: p.price)


def test_compare_sort_by_rating():
    service = ComparisonService()
    query = CompareQuery(category="手机", sort_by="rating")
    results = service.compare(query)
    assert results == sorted(results, key=lambda p: p.rating, reverse=True)


def test_sort_by_price():
    ds = MockDataSource()
    products = ds.search("鞋")
    sorted_products = sort_by_price(products)
    assert sorted_products[0].price <= sorted_products[-1].price


def test_sort_by_rating():
    ds = MockDataSource()
    products = ds.search("手机")
    sorted_products = sort_by_rating(products)
    assert sorted_products[0].rating >= sorted_products[-1].rating
