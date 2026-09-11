import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/shopping_decision.dart';
import '../widgets/shopping_decision_card.dart';

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
    if (widget.shoppingDecision == null && widget.bestChoice != null) {
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
    final report = _apiReport;
    return Scaffold(
      appBar: AppBar(title: const Text('样例商品知识报告'), actions: [
        if (report != null)
          IconButton(
              icon: const Icon(Icons.share_outlined), onPressed: _shareReport),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本地虚构样例 · 非实际报价 · 非个性化最优选择'),
                  const SizedBox(height: 16),
                  if (report == null) ...[
                    const Text('暂无已核验的报告。请从样例商品库重新选择，或进入AI购物决策对话。'),
                    if (widget.bestChoice != null)
                      TextButton(
                          onPressed: _loadReport, child: const Text('重试')),
                  ] else
                    SelectableText(_formatReportText()),
                ],
              )),
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
    final r = _apiReport;
    if (r == null) return '暂无已核验的样例报告';
    final sb = StringBuffer('Smart Price AI 样例商品知识报告\n');
    sb.writeln(r['notice']);
    sb.writeln(r['summary']);
    sb.writeln('优点：${(r['pros'] as List? ?? []).join('；')}');
    sb.writeln('缺点：${(r['cons'] as List? ?? []).join('；')}');
    sb.writeln(r['recommendation']);
    sb.writeln('商品ID：${r['product_id']}');
    sb.writeln('证据：${(r['evidence_ids'] as List? ?? []).join('、')}');
    sb.writeln('目录SHA-256：${(r['catalog'] as Map?)?['sha256']}');
    return sb.toString();
  }
}
