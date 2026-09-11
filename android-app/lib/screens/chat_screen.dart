import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/product.dart';
import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/bottom_input_bar.dart';
import '../widgets/animated_chat_bubble.dart';
import 'report_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final Product? initialProduct;
  final RecognitionResult? initialRecognition;

  const ChatScreen({
    super.key,
    this.initialMessage,
    this.initialProduct,
    this.initialRecognition,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _sessionId;
  bool _isLoading = false;
  String _streamStatus = '正在连接';
  final _streamCancellation = ChatStreamCancellation();
  Map<String, dynamic>? _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct =
        widget.initialProduct?.toJson() ?? widget.initialRecognition?.toJson();
    _addWelcomeMessage();
    if (widget.initialProduct != null) {
      _addProductMessage(widget.initialProduct!);
    } else if (widget.initialRecognition != null) {
      _messages.add(ChatMessage(
        id: 'recognized_product',
        text: '已带入识别商品：${widget.initialRecognition!.name ?? "待确认商品"}。识别属性可能有误，请确认；图片识别不包含可靠报价。',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _sendMessage(widget.initialMessage!);
    }
  }

  @override
  void dispose() {
    _streamCancellation.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: 'welcome',
      text: '你好！我是你的 AI 购物助手。可以结合识别结果和你的需求讨论选购建议。商品和价格仅为本地样例，不是实时电商报价。',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _addProductMessage(Product product) {
    _messages.add(ChatMessage(
      id: 'product_${product.id}',
      text:
          '已选择样例商品：${product.name}（样例价 ¥${product.price.toStringAsFixed(0)}）\n你想了解这款商品的什么信息？',
      isUser: false,
      timestamp: DateTime.now(),
      action: 'product_selected',
      actionData: product.toJson(),
    ));
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _streamStatus = '正在连接';
    });
    _scrollToBottom();

    // 创建流式 AI 消息占位
    final streamMsgId = '${DateTime.now().millisecondsSinceEpoch}_stream';
    setState(() {
      _messages.add(ChatMessage(
        id: streamMsgId,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    try {
      await ApiService().sendChatStream(
        text,
        sessionId: _sessionId,
        currentProduct: _currentProduct,
        cancellation: _streamCancellation,
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _streamStatus = status['message'] as String;
            _sessionId = status['session_id'] as String;
          });
        },
        onChunk: (chunk) {
          if (!mounted) return;
          setState(() {
            final msg = _messages.firstWhere((m) => m.id == streamMsgId);
            msg.text += chunk;
          });
          _scrollToBottom();
        },
        onDone: (response) {
          if (!mounted) return;

          final reply = response['reply']?.toString() ?? '';
          final newSessionId = response['session_id']?.toString() ??
              response['sessionId']?.toString();
          if (newSessionId != null) _sessionId = newSessionId;

          final action = response['action']?.toString() ?? 'none';
          final currentProductData = response['current_product'];
          if (currentProductData is Map<String, dynamic>) {
            // Recognition-only context has no price/ID; never manufacture either.
            _currentProduct = Map<String, dynamic>.from(currentProductData);
          }

          setState(() {
            _isLoading = false;
            final msg = _messages.firstWhere((m) => m.id == streamMsgId);
            msg.text = reply.isNotEmpty ? reply : msg.text;
            msg.action = action;
            msg.actionData = response['action_data'] as Map<String, dynamic>? ??
                response['actionData'] as Map<String, dynamic>?;
          });
          _scrollToBottom();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            final msg = _messages.firstWhere((m) => m.id == streamMsgId);
            msg.text = '发送消息失败: $error';
          });
          _scrollToBottom();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发送消息失败: $error'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildDecisionCard(Map<String, dynamic> data) {
    final reportType = data['report_type']?.toString() ?? 'decision';
    switch (reportType) {
      case 'comparison':
        return _buildComparisonCard(data);
      case 'buy_guide':
        return _buildBuyGuideCard(data);
      case 'decision':
      default:
        return _buildDecisionReportCard(data);
    }
  }

  Widget _buildDecisionReportCard(Map<String, dynamic> data) {
    return _buildCardWrapper(
      icon: Icons.assignment_turned_in,
      title: 'AI 决策报告',
      children: [
        if (data['target_product'] != null)
          _buildReportRow('目标商品', data['target_product'].toString()),
        if (data['best_choice'] != null)
          _buildReportRow('最优选择', data['best_choice'].toString()),
        if (data['suggestion'] != null)
          _buildReportRow('AI 建议', data['suggestion'].toString()),
        if (data['savings'] != null)
          _buildReportRow('预计节省', '¥${data['savings']}'),
      ],
      buttonText: '分享报告',
      onButtonTap: () => _navigateToReport(data),
    );
  }

  Widget _buildComparisonCard(Map<String, dynamic> data) {
    return _buildCardWrapper(
      icon: Icons.compare_arrows,
      title: '对比分析',
      accentColor: Colors.orange,
      children: [
        if (data['product_a'] != null && data['product_b'] != null)
          _buildReportRow('对比对象', '${data['product_a']} vs ${data['product_b']}'),
        if (data['differences'] != null)
          _buildReportRow('核心差异', data['differences'].toString()),
        if (data['advantages_a'] != null)
          _buildReportRow('${data['product_a']} 优势', data['advantages_a'].toString()),
        if (data['advantages_b'] != null)
          _buildReportRow('${data['product_b']} 优势', data['advantages_b'].toString()),
        if (data['suitable_for_a'] != null)
          _buildReportRow('适合人群', '${data['product_a']}: ${data['suitable_for_a']}'),
        if (data['suitable_for_b'] != null)
          _buildReportRow('', '${data['product_b']}: ${data['suitable_for_b']}'),
      ],
      buttonText: '查看详情',
      onButtonTap: () => _navigateToReport(data),
    );
  }

  Widget _buildBuyGuideCard(Map<String, dynamic> data) {
    return _buildCardWrapper(
      icon: Icons.shopping_bag,
      title: '购买指南',
      accentColor: Colors.green,
      children: [
        if (data['target_product'] != null)
          _buildReportRow('目标商品', data['target_product'].toString()),
        if (data['best_time'] != null)
          _buildReportRow('最佳时机', data['best_time'].toString()),
        if (data['best_platform'] != null)
          _buildReportRow('推荐平台', data['best_platform'].toString()),
        if (data['popular_colors'] != null)
          _buildReportRow('热门配色', data['popular_colors'].toString()),
        if (data['price_estimate'] != null)
          _buildReportRow('预估价格', data['price_estimate'].toString()),
      ],
      buttonText: '查看详情',
      onButtonTap: () => _navigateToReport(data),
    );
  }

  Widget _buildCardWrapper({
    required IconData icon,
    required String title,
    required List<Widget> children,
    required String buttonText,
    required VoidCallback onButtonTap,
    Color accentColor = Constants.brandColor,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Constants.largeRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Constants.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onButtonTap,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToReport(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          productName: data['target_product']?.toString() ??
              data['product_a']?.toString() ??
              '未知商品',
          reportData: data,
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: Constants.secondaryTextColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Constants.primaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
          const SizedBox(width: 8),
          Text(
            _streamStatus,
            style: Constants.caption.copyWith(color: Constants.tertiaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final adjustedValue = (value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        return Transform.scale(
          scale: 0.5 + adjustedValue * 0.5,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Constants.brandColor.withOpacity(0.3 + adjustedValue * 0.7),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
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
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Constants.brandColor, size: 22),
            SizedBox(width: 8),
            Text(
              'AI 购物助手',
              style: TextStyle(
                color: Constants.primaryTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final product = _currentProduct;
              if (product == null ||
                  product['price'] is! num ||
                  (product['platform']?.toString().isEmpty ?? true)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('识别结果没有可靠报价，请先选择本地样例商品再生成价格相关报告。'),
                ));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportScreen(
                    productName: product['name'] as String,
                    bestChoice: {
                      'name': product['name'],
                      'platform': product['platform'],
                      'price': product['price'],
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.assignment, size: 18, color: Constants.brandColor),
            label: const Text(
              '报告',
              style: TextStyle(color: Constants.brandColor, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final msg = _messages[index];
                if (msg.action == 'report' && msg.actionData != null) {
                  return _buildDecisionCard(msg.actionData!);
                }
                // 最后一条 AI 消息且正在流式输出时，显示脉冲光标
                final isStreaming = _isLoading &&
                    !msg.isUser &&
                    index == _messages.length - 1;
                return AnimatedChatBubble(
                  message: msg,
                  index: index,
                  isStreaming: isStreaming,
                );
              },
            ),
          ),
          if (_isLoading) _buildTypingIndicator(),
          BottomInputBar(
            controller: _inputController,
            onSend: () {
              final text = _inputController.text.trim();
              if (text.isNotEmpty) {
                _inputController.clear();
                _sendMessage(text);
              }
            },
            hintText: '输入问题...',
          ),
        ],
      ),
    );
  }
}
