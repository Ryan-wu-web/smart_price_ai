import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_card.dart';
import 'chat_screen.dart';

class CompareScreen extends StatefulWidget {
  final String category;
  final String? brand;
  final String? color;
  final String? filterMode;

  const CompareScreen({
    super.key,
    required this.category,
    this.brand,
    this.color,
    this.filterMode,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final List<String> _filters = ['固定目录顺序', '样例区间下限从低'];
  final List<String?> _sortByValues = [null, 'price'];
  int _selectedFilter = 0;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _filterMode;
  String _filterTitle = '';
  bool _categoryOnly = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _filterMode = widget.filterMode;
    _updateFilterTitle();
    _loadProducts();
  }

  void _updateFilterTitle() {
    if (_filterMode == 'official') {
      _filterTitle = '未提供官方渠道证据';
    } else if (_filterMode == 'similar') {
      _filterTitle = '同品类样例';
    } else {
      _filterTitle = '';
    }
  }

  Future<void> _loadProducts() async {
    final version = ++_loadVersion;
    setState(() => _isLoading = true);
    try {
      final products = await ApiService().compare(
        widget.category,
        brand: _categoryOnly ? null : widget.brand,
        color: _categoryOnly ? null : widget.color,
        sortBy: _sortByValues[_selectedFilter],
        filterMode: _filterMode,
      );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _isLoading = false;
        _products = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('样例商品暂时无法加载，请稍后重试。'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onProductTap(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          initialProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Constants.primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '找到 ${_products.length} 个结果',
          style: const TextStyle(
            color: Constants.primaryTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_filterTitle.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: Constants.brandGradient,
                borderRadius: BorderRadius.circular(Constants.radiusLarge),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _filterTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterMode = null;
                        _filterTitle = '';
                      });
                      _loadProducts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '取消渠道限制',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tags = List.generate(_filters.length, (index) {
                final isSelected = _selectedFilter == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = index);
                    _loadProducts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Constants.brandColor : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: isSelected
                          ? null
                          : Border.all(color: Constants.borderColor),
                    ),
                    child: Text(
                      _filters[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Constants.primaryTextColor,
                      ),
                    ),
                  ),
                );
              });
              if (constraints.maxWidth > 420) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Wrap(spacing: 10, children: tags),
                );
              }
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: tags,
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('本地虚构样例及价格区间，不是实际报价；不提供销量、评分或官方渠道保证。'),
          ),
          if (!_categoryOnly)
            TextButton(
              onPressed: () {
                setState(() {
                  _categoryOnly = true;
                  _filterMode = null;
                  _updateFilterTitle();
                });
                _loadProducts();
              },
              child: const Text('取消品牌、颜色和渠道条件，仅按品类浏览样例'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 3,
                    itemBuilder: (_, __) => const ShimmerCard(),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color:
                                  Constants.secondaryTextColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '没有满足当前条件的样例，未放宽条件',
                              style: TextStyle(
                                color: Constants.secondaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _products.length,
                        itemBuilder: (_, index) {
                          final product = _products[index];
                          return ProductCard(
                            key: ValueKey(product.id),
                            product: product,
                            onTap: () => _onProductTap(product),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
