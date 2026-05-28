import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_card.dart';
import 'compare_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _hotTags = ['运动鞋', '数码', '服饰', '美妆', '家居', '手机', '耳机'];

  List<Product> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });
    try {
      final products = await ApiService().compare(query.trim());
      if (!mounted) return;
      setState(() {
        _results = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onProductTap(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          category: product.category ?? product.name,
          brand: product.brand,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const Divider(height: 1, color: Constants.borderColor),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Constants.primaryTextColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Constants.radiusMedium),
                boxShadow: const [Constants.shadowLight],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Constants.secondaryTextColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: const InputDecoration(
                        hintText: '搜索商品、品牌、分类...',
                        hintStyle: TextStyle(fontSize: 14, color: Constants.tertiaryTextColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14, color: Constants.primaryTextColor),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _hasSearched = false;
                          _results = [];
                          _error = null;
                        });
                      },
                      child: const Icon(Icons.clear, color: Constants.secondaryTextColor, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _search(_controller.text),
            child: const Text(
              '搜索',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Constants.brandColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Constants.tertiaryTextColor),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Constants.secondaryTextColor)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _search(_controller.text),
              child: const Text('重试', style: TextStyle(color: Constants.brandColor)),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildHotTags();
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Constants.tertiaryTextColor),
            SizedBox(height: 16),
            Text('未找到相关商品', style: TextStyle(fontSize: 15, color: Constants.secondaryTextColor)),
            SizedBox(height: 8),
            Text('换个关键词试试', style: TextStyle(fontSize: 13, color: Constants.tertiaryTextColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (_, index) {
        return ProductCard(
          product: _results[index],
          onTap: () => _onProductTap(_results[index]),
        );
      },
    );
  }

  Widget _buildHotTags() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热门搜索',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Constants.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hotTags.map((tag) {
              return GestureDetector(
                onTap: () {
                  _controller.text = tag;
                  _search(tag);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Constants.borderColor),
                    boxShadow: const [Constants.shadowLight],
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Constants.secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            '搜索提示',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Constants.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildTip(Icons.camera_alt, '拍照识物', '点击首页相机按钮，一键识别商品'),
          _buildTip(Icons.chat_bubble_outline, 'AI 助手', '描述需求，让 AI 帮你筛选'),
          _buildTip(Icons.trending_up, '价格走势', '查看商品历史价格，避免买贵'),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowLight],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Constants.brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Constants.brandColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Constants.secondaryTextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
