import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import '../utils/constants.dart';
import '../widgets/bottom_input_bar.dart';
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

class _ResultScreenState extends State<ResultScreen> {
  late RecognitionResult _result;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _result = widget.recognitionResult;
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final confidence = _result.confidence;
    final confidenceText = confidence >= 0.8
        ? '高置信度'
        : confidence >= 0.5
            ? '中等置信度'
            : '低置信度';

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
                    height: 220,
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
                      _buildAttributeChip(
                        '品牌',
                        _result.brand,
                        () => _editAttribute('品牌', _result.brand ?? '', (v) {
                          setState(() => _result = _result.copyWith(brand: v));
                        }),
                      ),
                      _buildAttributeChip(
                        '颜色',
                        _result.color,
                        () => _editAttribute('颜色', _result.color ?? '', (v) {
                          setState(() => _result = _result.copyWith(color: v));
                        }),
                      ),
                      _buildAttributeChip(
                        '类目',
                        _result.category,
                        () => _editAttribute('类目', _result.category ?? '', (v) {
                          setState(() => _result = _result.copyWith(category: v));
                        }),
                      ),
                      _buildAttributeChip(
                        '风格',
                        _result.style,
                        () => _editAttribute('风格', _result.style ?? '', (v) {
                          setState(() => _result = _result.copyWith(style: v));
                        }),
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
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        SuggestionCard(
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
                        SuggestionCard(
                          icon: Icons.store,
                          title: '官方旗舰店',
                          subtitle: '正品保障',
                          iconColor: Colors.blue,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('功能开发中，敬请期待'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        SuggestionCard(
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
                                  currentPrice: 799,
                                ),
                              ),
                            );
                          },
                        ),
                        SuggestionCard(
                          icon: Icons.recommend,
                          title: '相似推荐',
                          subtitle: '更多类似商品',
                          iconColor: Colors.purple,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('功能开发中，敬请期待'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
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
