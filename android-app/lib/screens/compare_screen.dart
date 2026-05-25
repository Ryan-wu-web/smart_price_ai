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

  const CompareScreen({
    super.key,
    required this.category,
    this.brand,
    this.color,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final List<String> _filters = ['综合推荐', '价格从低', '销量优先', '好评率'];
  final List<String?> _sortByValues = [null, 'price', null, 'rating'];
  int _selectedFilter = 0;
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService().compare(
        widget.category,
        brand: widget.brand,
        color: widget.color,
        sortBy: _sortByValues[_selectedFilter],
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载失败: $e'),
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
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (_, index) {
                final isSelected = _selectedFilter == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = index);
                    _loadProducts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: isSelected ? Colors.white : Constants.primaryTextColor,
                      ),
                    ),
                  ),
                );
              },
            ),
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
                              color: Constants.secondaryTextColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '暂无比价结果',
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
