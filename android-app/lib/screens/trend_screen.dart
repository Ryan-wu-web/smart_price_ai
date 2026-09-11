import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Keep the route and retry behavior, but never render fabricated price charts.
class TrendScreen extends StatefulWidget {
  final String productName;
  final String productId;
  const TrendScreen(
      {super.key, required this.productName, required this.productId});
  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ApiService().getTrend(widget.productId);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('历史价格说明')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(widget.productName),
                        const SizedBox(height: 16),
                        const Text(
                            '未接入历史价格数据。当前仅提供本地虚构样例价格区间，不能推断价格涨跌、历史低点或最佳购买时机。'),
                        if (_failed) ...[
                          const SizedBox(height: 16),
                          const Text('服务暂时无法连接；不会用模拟曲线替代。'),
                          TextButton(onPressed: _load, child: const Text('重试')),
                        ],
                      ],
                    ))),
      );
}
