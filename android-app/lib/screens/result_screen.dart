import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import '../utils/constants.dart';
// import '../utils/error_messages.dart'; // Removed: no longer needed
// import '../services/api_service.dart'; // Removed: no longer needed
import '../widgets/bottom_input_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/suggestion_card.dart';
import 'chat_screen.dart';
import 'compare_screen.dart';
import 'trend_screen.dart';

class ResultScreen extends StatefulWidget {
  final RecognitionResult recognitionResult;
  final File? imageFile;

  const ResultScreen({
    super.key,
    required this.recognitionResult,
    this.imageFile,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late RecognitionResult _result;
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _staggerController;
  // _isLoading removed: no longer needed since we navigate directly

  @override
  void initState() {
    super.initState();
    _result = widget.recognitionResult;
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _editAttribute(String title, String currentValue,
      void Function(String) onConfirm) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.largeRadius)),
        title: Text('修正$title', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入$title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Constants.smallRadius),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onConfirm(controller.text);
              Navigator.pop(context);
              final focusContext = context;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!focusContext.mounted) return;
                FocusScope.of(focusContext).requestFocus(FocusNode());
              });
            },
            child: const Text('确定', style: TextStyle(color: Constants.brandColor)),
          ),
        ],
      ),
    );
  }

  void _onBottomSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialMessage: text),
      ),
    );
    _inputController.clear();
  }

  Widget _buildAttributeChip(String label, String? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.42,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Constants.brandColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 12,
                color: Constants.secondaryTextColor,
              ),
            ),
            Flexible(
              child: Text(
                value ?? '未知',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Constants.primaryTextColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 12, color: Constants.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSuggestionCard({
    required int index,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(0.3 + index * 0.12, 1.0, curve: Curves.easeOutCubic),
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidence = _result.confidence;
    final confidenceText = confidence >= 0.8
        ? '高置信度'
        : confidence >= 0.5
            ? '中等置信度'
            : '低置信度';
    final imageHeight = (MediaQuery.of(context).size.height * 0.25).clamp(180.0, 280.0);
    final listHeight = ResponsiveLayout.value(context,
      small: 130.0,
      medium: 140.0,
      large: 150.0,
    );

    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Constants.primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '识别结果',
          style: TextStyle(
            color: Constants.primaryTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: confidence >= 0.8
                  ? Constants.brandColor.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              confidenceText,
              style: TextStyle(
                fontSize: 12,
                color: confidence >= 0.8 ? Constants.brandColor : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: imageHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Constants.largeRadius),
                      color: const Color(0xFFE8E8ED),
                      boxShadow: const [Constants.shadowCard],
                    ),
                    child: widget.imageFile != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(Constants.largeRadius),
                            child: Image.file(
                              widget.imageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image,
                              size: 60,
                              color: Constants.secondaryTextColor,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (_result.name != null && _result.name!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _result.name!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Constants.primaryTextColor,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(parent: _staggerController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
                        ),
                        child: _buildAttributeChip(
                          '品牌',
                          _result.brand,
                          () => _editAttribute('品牌', _result.brand ?? '', (v) {
                            setState(() => _result = _result.copyWith(brand: v));
                          }),
                        ),
                      ),
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(parent: _staggerController, curve: const Interval(0.15, 0.75, curve: Curves.easeOut)),
                        ),
                        child: _buildAttributeChip(
                          '颜色',
                          _result.color,
                          () => _editAttribute('颜色', _result.color ?? '', (v) {
                            setState(() => _result = _result.copyWith(color: v));
                          }),
                        ),
                      ),
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(parent: _staggerController, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)),
                        ),
                        child: _buildAttributeChip(
                          '类目',
                          _result.category,
                          () => _editAttribute('类目', _result.category ?? '', (v) {
                            setState(() => _result = _result.copyWith(category: v));
                          }),
                        ),
                      ),
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(parent: _staggerController, curve: const Interval(0.45, 1.0, curve: Curves.easeOut)),
                        ),
                        child: _buildAttributeChip(
                          '风格',
                          _result.style,
                          () => _editAttribute('风格', _result.style ?? '', (v) {
                            setState(() => _result = _result.copyWith(style: v));
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '下一步',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Constants.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: listHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildAnimatedSuggestionCard(
                          index: 0,
                          child: SuggestionCard(
                            icon: Icons.compare_arrows,
                            title: '查看同款低价',
                            subtitle: '跨平台比价',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompareScreen(
                                    category: _result.category ?? '',
                                    brand: _result.brand,
                                    color: _result.color,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _buildAnimatedSuggestionCard(
                          index: 1,
                          child: SuggestionCard(
                            icon: Icons.store,
                            title: '官方旗舰店',
                            subtitle: '正品保障',
                            iconColor: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompareScreen(
                                    category: _result.category ?? '',
                                    brand: _result.brand,
                                    color: _result.color,
                                    filterMode: 'official',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Loading indicator removed: navigation is instant now
                        _buildAnimatedSuggestionCard(
                          index: 2,
                          child: SuggestionCard(
                            icon: Icons.trending_up,
                            title: '价格走势',
                            subtitle: '历史价格分析',
                            iconColor: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrendScreen(
                                    productName: _result.name ?? _result.category ?? '未知商品',
                                    productId: '${_result.name ?? _result.category}_${_result.brand ?? ''}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _buildAnimatedSuggestionCard(
                          index: 3,
                          child: SuggestionCard(
                            icon: Icons.recommend,
                            title: '相似推荐',
                            subtitle: '更多类似商品',
                            iconColor: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompareScreen(
                                    category: _result.category ?? '',
                                    brand: _result.brand,
                                    color: _result.color,
                                    filterMode: 'similar',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Constants.largeRadius),
                      boxShadow: const [Constants.shadowCard],
                      border: const Border(left: BorderSide(color: Constants.brandColor, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Constants.brandColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Constants.brandColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'AI 导购建议',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Constants.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '识别到 "${_result.category ?? '未知商品'}"，建议您可以查看同款低价进行比价，或咨询 AI 购物助手获取更多购买建议。',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Constants.secondaryTextColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          BottomInputBar(
            controller: _inputController,
            onSend: _onBottomSend,
            hintText: '输入筛选条件，如 "价格低于 500"...',
          ),
        ],
      ),
    );
  }
}
