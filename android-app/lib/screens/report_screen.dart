import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/shopping_decision.dart';
import '../widgets/shopping_decision_card.dart';
import '../utils/constants.dart';

class ReportScreen extends StatefulWidget {
  final String productName;
  final ShoppingDecision? shoppingDecision;
  final Map<String, dynamic>? reportData;
  final Map<String, dynamic>? bestChoice;
  final List<Map<String, dynamic>>? alternatives;

  const ReportScreen({
    super.key,
    required this.productName,
    this.shoppingDecision,
    this.reportData,
    this.bestChoice,
    this.alternatives,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _apiReport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.shoppingDecision == null &&
        widget.reportData == null &&
        widget.bestChoice != null) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService().generateReport(
        productName: widget.productName,
        bestChoice: widget.bestChoice!,
        alternatives: widget.alternatives,
      );
      if (!mounted) return;
      setState(() {
        _apiReport = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法生成报告，请稍后重试。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.shoppingDecision;
    if (decision != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('有据购物决策报告'), actions: [
          IconButton(
              tooltip: '分享含证据的报告',
              onPressed: _shareReport,
              icon: const Icon(Icons.share_outlined))
        ]),
        body: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                  '需求版本 ${decision.revision}\n目录SHA-256：${ShoppingDecision.object(decision.data['report'])['catalog_sha256']}')),
          ShoppingDecisionCard(decision: decision),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Constants.primaryTextColor),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Constants.primaryTextColor,
        ),
        title: const Text('决策报告'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportHeader(),
                  const SizedBox(height: 20),
                  _buildBestChoiceCard(),
                  const SizedBox(height: 20),
                  _buildAlternativesSection(),
                  const SizedBox(height: 20),
                  _buildAISuggestionCard(),
                  const SizedBox(height: 32),
                  _buildShareButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Future<void> _shareReport() async {
    final text = _formatReportText();
    try {
      await Share.share(text, subject: 'Smart Price AI 购物决策报告');
    } catch (e) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('分享和复制暂时不可用，请稍后重试。')));
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报告已复制到剪贴板')),
        );
      }
    }
  }

  String _formatReportText() {
    if (widget.shoppingDecision != null) {
      return widget.shoppingDecision!.reportText;
    }
    final sb = StringBuffer();
    sb.writeln('🛍️ Smart Price AI 样例购物决策报告（非实时价格）');
    sb.writeln('商品：${widget.productName}');
    sb.writeln('');
    sb.writeln('🏆 最优选择');
    sb.writeln(widget.reportData?['best_choice']?.toString() ??
        widget.bestChoice?['name']?.toString() ??
        '暂无已核验的选择');
    sb.writeln('');
    sb.writeln('💡 AI 建议');
    sb.writeln(widget.reportData?['suggestion']?.toString() ??
        _apiReport?['recommendation']?.toString() ??
        '证据不足，暂不提供购买时机建议。');
    return sb.toString();
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Constants.brandGradient,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowElevated],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '样例数据 · 非实时价格',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '购物决策报告',
            style:
                Constants.display.copyWith(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            widget.productName,
            style:
                Constants.body.copyWith(color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildBestChoiceCard() {
    final bestName = widget.reportData?['best_choice']?.toString() ??
        widget.bestChoice?['name']?.toString() ??
        '暂无已核验的选择';
    final price = widget.bestChoice?['price'] != null
        ? '样例价 ¥${widget.bestChoice!['price']}'
        : '暂无价格证据';
    final pros = _apiReport?['pros'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
        border: const Border(
            left: BorderSide(color: Constants.brandColor, width: 3)),
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
                  color: Constants.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(Constants.radiusMedium),
                ),
                child: const Icon(Icons.emoji_events,
                    color: Constants.successColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('最优选择', style: Constants.h2),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('选择', bestName),
          _buildInfoRow('价格', price, isHighlight: true),
          if (pros != null && pros.isNotEmpty)
            ...pros.map((p) => _buildInfoRow('优点', p.toString())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: Constants.caption)),
          Expanded(
            child: Text(
              value,
              style: isHighlight
                  ? const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Constants.accentColor,
                    )
                  : const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Constants.primaryTextColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    final alts = widget.alternatives ?? <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('其他选择', style: Constants.h2),
          const SizedBox(height: 12),
          ...alts.asMap().entries.map((entry) {
            final i = entry.key;
            final alt = entry.value;
            return Column(
              children: [
                _buildAlternativeItem(
                  alt['platform']?.toString() ?? '未知',
                  alt['price']?.toString() ?? '—',
                  alt['tag']?.toString() ?? '',
                ),
                if (i < alts.length - 1) const Divider(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlternativeItem(String platform, String price, String tag) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Constants.backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(platform, style: Constants.caption),
        ),
        const SizedBox(width: 12),
        Text(price,
            style: Constants.body.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(tag, style: Constants.caption),
      ],
    );
  }

  Widget _buildAISuggestionCard() {
    final suggestion = widget.reportData?['suggestion']?.toString() ??
        _apiReport?['recommendation']?.toString() ??
        '证据不足，暂不提供购买时机建议。';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
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
                  color: Constants.brandColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(Constants.radiusMedium),
                ),
                child: const Icon(Icons.lightbulb,
                    color: Constants.brandColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('AI 建议', style: Constants.h2),
            ],
          ),
          const SizedBox(height: 12),
          Text(suggestion,
              style:
                  Constants.body.copyWith(color: Constants.secondaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _shareReport,
        icon: const Icon(Icons.download),
        label: const Text('保存报告'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Constants.brandColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.radiusLarge),
          ),
        ),
      ),
    );
  }
}
