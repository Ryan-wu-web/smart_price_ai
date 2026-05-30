import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _hotTags = [
    '运动鞋', '数码', '服饰', '美妆', '家居', '手机', '耳机'
  ];

  List<Product> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isFocused = false;

  late AnimationController _animController;
  late Animation<double> _searchBarAnim;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _searchBarAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _contentAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );
    _animController.forward();

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _searchHistory = prefs.getStringList('search_history') ?? [];
      });
    } catch (_) {
      // 降级到空列表
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      history.remove(query);
      history.insert(0, query);
      if (history.length > 10) history.removeLast();
      await prefs.setStringList('search_history', history);
      setState(() => _searchHistory = history);
    } catch (_) {}
  }

  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
      setState(() => _searchHistory = []);
    } catch (_) {}
  }

  Future<void> _removeSearchHistoryItem(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      history.remove(query);
      await prefs.setStringList('search_history', history);
      setState(() => _searchHistory = history);
    } catch (_) {}
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });
    try {
      final products = await ApiService().compare(query.trim());
      if (!mounted) return;
      setState(() {
        _results = products;
        _isLoading = false;
        _isSearching = false;
      });
      await _saveSearchHistory(query.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isSearching = false;
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
    return AnimatedBuilder(
      animation: _searchBarAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (1 - _searchBarAnim.value)),
          child: Opacity(
            opacity: _searchBarAnim.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Constants.primaryTextColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(Constants.radiusMedium),
                        boxShadow: [
                          if (_isFocused)
                            BoxShadow(
                              color: Constants.brandColor.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            )
                          else
                            Constants.shadowLight,
                        ],
                        border: _isFocused
                            ? Border.all(
                                color: Constants.brandColor.withOpacity(0.5),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Constants.secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _search,
                              decoration: const InputDecoration(
                                hintText: '搜索商品、品牌、分类...',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Constants.secondaryTextColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Constants.primaryTextColor,
                              ),
                            ),
                          ),
                          if (_isSearching)
                            _buildPulseDot()
                          else if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() {
                                  _hasSearched = false;
                                  _results = [];
                                  _error = null;
                                });
                              },
                              child: const Icon(
                                Icons.clear,
                                color: Constants.secondaryTextColor,
                                size: 18,
                              ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulseDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Constants.brandColor.withOpacity(0.3 + value * 0.7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Constants.brandColor.withOpacity(0.3 * value),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Constants.tertiaryTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Constants.secondaryTextColor),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _search(_controller.text),
              child: const Text(
                '重试',
                style: TextStyle(color: Constants.brandColor),
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return AnimatedBuilder(
        animation: _contentAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _contentAnim.value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - _contentAnim.value)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchHistory.isNotEmpty) ...[
                      _buildSearchHistory(),
                      const SizedBox(height: 24),
                    ],
                    _buildHotTags(),
                    const SizedBox(height: 32),
                    _buildTips(),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Constants.tertiaryTextColor,
            ),
            SizedBox(height: 16),
            Text(
              '未找到相关商品',
              style: TextStyle(
                fontSize: 15,
                color: Constants.secondaryTextColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '换个关键词试试',
              style: TextStyle(
                fontSize: 13,
                color: Constants.tertiaryTextColor,
              ),
            ),
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

  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '最近搜索',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Constants.primaryTextColor,
              ),
            ),
            GestureDetector(
              onTap: _clearSearchHistory,
              child: const Text(
                '清空',
                style: TextStyle(
                  fontSize: 13,
                  color: Constants.tertiaryTextColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _searchHistory.map((tag) {
            return GestureDetector(
              onTap: () {
                _controller.text = tag;
                _search(tag);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Constants.borderColor),
                  boxShadow: const [Constants.shadowLight],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history,
                      size: 14,
                      color: Constants.tertiaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Constants.secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeSearchHistoryItem(tag),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Constants.tertiaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHotTags() {
    return Column(
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
          children: _hotTags.asMap().entries.map((entry) {
            final index = entry.key;
            final tag = entry.value;
            return _AnimatedTag(
              delay: Duration(milliseconds: 100 + index * 80),
              child: GestureDetector(
                onTap: () {
                  _controller.text = tag;
                  _search(tag);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Constants.borderColor),
                    boxShadow: const [Constants.shadowLight],
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Constants.secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '搜索提示',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Constants.primaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        _AnimatedTag(
          delay: const Duration(milliseconds: 400),
          child: _buildTip(
            Icons.camera_alt,
            '拍照识物',
            '点击首页相机按钮，一键识别商品',
          ),
        ),
        const SizedBox(height: 10),
        _AnimatedTag(
          delay: const Duration(milliseconds: 520),
          child: _buildTip(
            Icons.chat_bubble_outline,
            'AI 助手',
            '描述需求，让 AI 帮你筛选',
          ),
        ),
        const SizedBox(height: 10),
        _AnimatedTag(
          delay: const Duration(milliseconds: 640),
          child: _buildTip(
            Icons.trending_up,
            '价格走势',
            '查看商品历史价格，避免买贵',
          ),
        ),
      ],
    );
  }

  Widget _buildTip(IconData icon, String title, String desc) {
    return Container(
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Constants.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTag extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _AnimatedTag({required this.delay, required this.child});

  @override
  State<_AnimatedTag> createState() => _AnimatedTagState();
}

class _AnimatedTagState extends State<_AnimatedTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
