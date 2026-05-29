import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class TrendScreen extends StatefulWidget {
  final String productName;
  final String productId;

  const TrendScreen({
    super.key,
    required this.productName,
    required this.productId,
  });

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  Map<String, dynamic>? _trendData;
  List<Map<String, dynamic>> _historyPrices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getTrend(widget.productId);
      if (!mounted) return;
      setState(() {
        _trendData = data;
        _historyPrices = (data?['history_prices'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        title: const Text('价格走势'),
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Constants.primaryTextColor),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Constants.primaryTextColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Constants.tertiaryTextColor),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Constants.secondaryTextColor)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadTrend,
            child: const Text('重试', style: TextStyle(color: Constants.brandColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final currentPrice = _historyPrices.isNotEmpty
        ? (_historyPrices.last['price'] as num).toDouble()
        : 0.0;
    final avgPrice = _historyPrices.isNotEmpty
        ? _historyPrices.map((p) => (p['price'] as num).toDouble()).reduce((a, b) => a + b) /
            _historyPrices.length
        : 0.0;
    final minPrice = _historyPrices.isNotEmpty
        ? _historyPrices.map((p) => (p['price'] as num).toDouble()).reduce((a, b) => a < b ? a : b)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductHeader(currentPrice),
          const SizedBox(height: 20),
          _buildChart(),
          const SizedBox(height: 20),
          _buildAIAnalysisCard(),
          const SizedBox(height: 20),
          _buildPriceStats(avgPrice, minPrice),
        ],
      ),
    );
  }

  Widget _buildProductHeader(double currentPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: Constants.placeholderGradient,
              borderRadius: BorderRadius.circular(Constants.radiusMedium),
            ),
            child: const Icon(Icons.show_chart, color: Constants.tertiaryTextColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName,
                  style: Constants.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '当前价格 ¥${currentPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Constants.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final chartHeight = (MediaQuery.of(context).size.height * 0.28).clamp(180.0, 300.0);

    if (_historyPrices.isEmpty) {
      return Container(
        height: chartHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Constants.radiusLarge),
          boxShadow: const [Constants.shadowCard],
        ),
        child: const Center(child: Text('暂无历史价格数据')),
      );
    }

    final spots = _historyPrices.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['price'] as num).toDouble());
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.05;
    final interval = (maxY - minY) / 4;

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('90天价格走势', style: Constants.h2),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Constants.borderColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '¥${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Constants.tertiaryTextColor,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: spots.length / 6,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _historyPrices.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _historyPrices[index]['date'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Constants.tertiaryTextColor,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Constants.brandColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Constants.brandColor,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Constants.brandColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisCard() {
    final advice = _trendData?['advice'] as String? ?? '暂无分析';
    final trend = _trendData?['trend'] as String? ?? '平稳';
    final confidence = (_trendData?['confidence'] as num?)?.toDouble() ?? 0.0;

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
                child: const Icon(
                  Icons.auto_awesome,
                  color: Constants.brandColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text('AI 价格分析', style: Constants.h2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTrendColor(trend).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getTrendColor(trend),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advice,
            style: Constants.body.copyWith(color: Constants.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.verified, color: Constants.brandColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'AI 置信度 ${(confidence * 100).toStringAsFixed(0)}%',
                style: Constants.caption.copyWith(color: Constants.brandColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrendColor(String trend) {
    if (trend.contains('上涨')) return Constants.errorColor;
    if (trend.contains('下跌')) return Constants.successColor;
    return Constants.warningColor;
  }

  Widget _buildPriceStats(double avgPrice, double minPrice) {
    return Row(
      children: [
        _buildStatCard('90天均价', '¥${avgPrice.toStringAsFixed(0)}'),
        const SizedBox(width: 12),
        _buildStatCard('历史最低', '¥${minPrice.toStringAsFixed(0)}'),
        const SizedBox(width: 12),
        _buildStatCard('价格趋势', _trendData?['trend'] ?? '—'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Constants.radiusLarge),
          boxShadow: const [Constants.shadowLight],
        ),
        child: Column(
          children: [
            Text(label, style: Constants.caption),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Constants.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
