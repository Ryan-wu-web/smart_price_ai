import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_decision.dart';
import '../widgets/shopping_decision_card.dart';
import '../models/chat_message.dart';
import '../models/product.dart';
import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/bottom_input_bar.dart';
import '../widgets/animated_chat_bubble.dart';
import 'report_screen.dart';
import 'preferences_screen.dart';

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
  ShoppingDecision? _decision;
  static const _sessionPreferenceKey = 'shopping_session_id';

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
        text:
            '已带入识别商品：${widget.initialRecognition!.name ?? "待确认商品"}。识别属性可能有误，请确认；图片识别不包含可靠报价。',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _sendMessage(widget.initialMessage!);
    } else if (_currentProduct == null) {
      unawaited(_restoreLastSession());
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
      text:
          '你好！我是你的 AI 购物助手。可以结合识别结果和你的需求讨论选购建议。商品和价格仅为本地样例，不是实时电商报价。请分句表达，例如“推荐耳机，预算500元，最好主动降噪”。不确定的需求会先请你确认。',
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

  Future<void> _sendMessage(String text,
      {Map<String, dynamic>? shopping}) async {
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
        shopping: {
          if (_decision != null) 'expected_revision': _decision!.revision,
          ...?shopping
        },
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
          final decision = ShoppingDecision.fromJson(ShoppingDecision.object(
              ShoppingDecision.object(response['action_data'])['workflow']));
          final currentProductData = response['current_product'];
          if (currentProductData is Map<String, dynamic>) {
            // Recognition-only context has no price/ID; never manufacture either.
            _currentProduct = Map<String, dynamic>.from(currentProductData);
          }

          setState(() {
            _isLoading = false;
            _decision = decision;
            final msg = _messages.firstWhere((m) => m.id == streamMsgId);
            msg.text = reply.isNotEmpty ? reply : msg.text;
            msg.action = action;
            msg.actionData = response['action_data'] as Map<String, dynamic>? ??
                response['actionData'] as Map<String, dynamic>?;
          });
          if (_sessionId != null) unawaited(_rememberSession(_sessionId!));
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

  Future<void> _rememberSession(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionPreferenceKey, id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('会话已保存在服务端，本机未能保存恢复标记。')));
      }
    }
  }

  Future<void> _restoreLastSession() async {
    setState(() {
      _isLoading = true;
      _streamStatus = '正在读取会话恢复标记';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_sessionPreferenceKey);
      if (!mounted) return;
      if (id != null) {
        _sessionId = id;
        await _refreshSession();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('本机恢复标记无法读取，可以新建会话。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSession() async {
    final id = _sessionId;
    if (id == null) return;
    setState(() {
      _isLoading = true;
      _streamStatus = '正在恢复已保存需求';
    });
    try {
      final data = await ApiService().readShoppingSession(id);
      final decision =
          ShoppingDecision.fromJson(ShoppingDecision.object(data['workflow']));
      if (decision.sessionId != id) {
        throw const FormatException('Session mismatch');
      }
      final history = ShoppingDecision.rows(data['messages']);
      if (!mounted) return;
      setState(() {
        _decision = decision;
        _currentProduct = data['current_product'] as Map<String, dynamic>?;
        _messages.clear();
        for (var i = 0; i < history.length; i++) {
          final m = history[i];
          _messages.add(ChatMessage(
              id: 'restored_$i',
              text: ShoppingDecision.text(m['content']),
              isUser: m['role'] == 'user',
              timestamp: DateTime.now(),
              actionData: i == history.length - 1 && m['role'] == 'assistant'
                  ? {'workflow': decision.data}
                  : null));
        }
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂时无法恢复购物会话，请确认后端状态；可新建会话，原历史不会删除。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _newSession() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionPreferenceKey);
    } catch (_) {/* Server history remains untouched. */}
    if (!mounted) return;
    setState(() {
      _sessionId = null;
      _decision = null;
      _currentProduct = null;
      _messages.clear();
      _addWelcomeMessage();
      _isLoading = false;
    });
  }

  Future<void> _confirmRecognition() async {
    final category = _currentProduct?['category'];
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('确认识别品类'),
              content:
                  Text('确认要选购“$category”吗？仅把品类加入硬条件，不确认识别品牌、价格或真实同款；不会撤销已有品类。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认品类'))
              ],
            ));
    if (accepted == true && mounted) {
      await _sendMessage('确认识别品类', shopping: {'confirm_recognition': true});
    }
  }

  Future<void> _confirmChange(
      ShoppingDecision decision, Map<String, dynamic> item,
      {required bool pending}) async {
    final label = pending
        ? ShoppingDecision.text(
            ShoppingDecision.object(item['source'])['quote'])
        : decision.conditionLabel(item);
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(pending ? '确认忽略这句话' : '确认撤销这条条件'),
              content: Text(
                  '$label\n${pending ? '忽略后这句话不再阻止推荐，也不会作为已满足条件。' : '撤销后候选范围可能扩大；其余硬条件不变。'}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('保留')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认修改'))
              ],
            ));
    if (accepted == true && mounted) {
      await _sendMessage('应用已确认的条件调整', shopping: {
        'expected_revision': decision.revision,
        'confirm_changes': true,
        (pending ? 'resolve_pending_ids' : 'remove_condition_ids'): [
          item['id']
        ],
      });
    }
  }

  Future<void> _openPreferences() async {
    final options = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => PreferencesScreen(decision: _decision)));
    if (options != null && mounted) {
      await _sendMessage('应用已确认的长期偏好', shopping: options);
    }
  }

  void _openGroundedReport(ShoppingDecision decision) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ReportScreen(
                productName: '样例商品购物决策', shoppingDecision: decision)));
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
          _buildReportRow(
              '对比对象', '${data['product_a']} vs ${data['product_b']}'),
        if (data['differences'] != null)
          _buildReportRow('核心差异', data['differences'].toString()),
        if (data['advantages_a'] != null)
          _buildReportRow(
              '${data['product_a']} 优势', data['advantages_a'].toString()),
        if (data['advantages_b'] != null)
          _buildReportRow(
              '${data['product_b']} 优势', data['advantages_b'].toString()),
        if (data['suitable_for_a'] != null)
          _buildReportRow(
              '适合人群', '${data['product_a']}: ${data['suitable_for_a']}'),
        if (data['suitable_for_b'] != null)
          _buildReportRow(
              '', '${data['product_b']}: ${data['suitable_for_b']}'),
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
          Flexible(
              child: Text(
            _streamStatus,
            style:
                Constants.caption.copyWith(color: Constants.tertiaryTextColor),
          )),
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
              color:
                  Constants.brandColor.withOpacity(0.3 + adjustedValue * 0.7),
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
          PopupMenuButton<String>(
            tooltip: '会话与长期偏好',
            enabled: !_isLoading,
            onSelected: (value) {
              if (value == 'preferences') {
                _openPreferences();
              } else if (value == 'refresh') {
                _refreshSession();
              } else {
                _newSession();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'preferences', child: Text('查看／修改长期偏好')),
              PopupMenuItem(
                  value: 'refresh',
                  enabled: _sessionId != null,
                  child: const Text('刷新已保存会话')),
              const PopupMenuItem(value: 'new', child: Text('新建会话（保留历史）')),
            ],
          ),
          TextButton.icon(
            onPressed: _isLoading ? null : () => _sendMessage('生成报告'),
            icon: const Icon(Icons.assignment,
                size: 18, color: Constants.brandColor),
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

                if (msg.actionData?['workflow'] is Map<String, dynamic>) {
                  final decision = ShoppingDecision.fromJson(
                      msg.actionData!['workflow'] as Map<String, dynamic>);
                  final editable = !_isLoading &&
                      decision.sessionId == _sessionId &&
                      decision.revision == _decision?.revision;
                  return Column(children: [
                    AnimatedChatBubble(message: msg, index: index),
                    ShoppingDecisionCard(
                        decision: decision,
                        editable: editable,
                        onRemove: (condition) =>
                            _confirmChange(decision, condition, pending: false),
                        onDismiss: (condition) =>
                            _confirmChange(decision, condition, pending: true),
                        onReport: decision.hasReport
                            ? () => _openGroundedReport(decision)
                            : null),
                  ]);
                }
                if (msg.action == 'report' && msg.actionData != null) {
                  return _buildDecisionCard(msg.actionData!);
                }
                // 最后一条 AI 消息且正在流式输出时，显示脉冲光标
                final isStreaming =
                    _isLoading && !msg.isUser && index == _messages.length - 1;
                return AnimatedChatBubble(
                  message: msg,
                  index: index,
                  isStreaming: isStreaming,
                );
              },
            ),
          ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 8, children: [
                if (_currentProduct != null &&
                    _decision?.data['recognition_confirmed'] != true)
                  ActionChip(
                      label: Text(
                          '确认识别品类：${_currentProduct!['category'] ?? '未知'}'),
                      onPressed: _confirmRecognition),
                ActionChip(
                    label: const Text('推荐耳机'),
                    onPressed: () => _sendMessage('推荐耳机')),
                ActionChip(
                    label: const Text('推荐运动鞋'),
                    onPressed: () => _sendMessage('推荐运动鞋')),
                ActionChip(
                    label: const Text('推荐双肩包'),
                    onPressed: () => _sendMessage('推荐双肩包')),
                if (_decision?.status == 'ready') ...[
                  ActionChip(
                      label: const Text('解释推荐'),
                      onPressed: () => _sendMessage('解释推荐')),
                  ActionChip(
                      label: const Text('对比候选'),
                      onPressed: () => _sendMessage('对比候选')),
                ],
              ]),
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
            hintText: '例如：预算500元，最好主动降噪',
          ),
        ],
      ),
    );
  }
}
