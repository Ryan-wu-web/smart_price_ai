import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TrendScreen extends StatelessWidget {
  final String productName;
  final double currentPrice;

  const TrendScreen({
    super.key,
    required this.productName,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        title: const Text('价格走势'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Constants.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(),
            const SizedBox(height: Constants.space20),
            _buildChartPlaceholder(context),
            const SizedBox(height: Constants.space20),
            _buildAIAnalysisCard(),
            const SizedBox(height: Constants.space20),
            _buildPriceStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.all(Constants.space16),
      decoration: BoxDecoration(
        color: Constants.surfaceColor,
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
          const SizedBox(width: Constants.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: Constants.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Constants.space4),
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

  Widget _buildChartPlaceholder(BuildContext context) {
    final chartHeight = (MediaQuery.of(context).size.height * 0.28).clamp(180.0, 300.0);
    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(Constants.space16),
      decoration: BoxDecoration(
        color: Constants.surfaceColor,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('90天价格走势', style: Constants.h2),
          const SizedBox(height: Constants.space12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: Constants.placeholderGradient,
                borderRadius: BorderRadius.circular(Constants.radiusMedium),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights, size: 40, color: Constants.tertiaryTextColor),
                    SizedBox(height: 8),
                    Text(
                      '走势图即将上线',
                      style: TextStyle(color: Constants.tertiaryTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(Constants.space16),
      decoration: BoxDecoration(
        color: Constants.surfaceColor,
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
                child: const Icon(Icons.auto_awesome, color: Constants.brandColor, size: 18),
              ),
              const SizedBox(width: Constants.space12),
              const Text('AI 价格分析', style: Constants.h2),
              const Spacer(),
            ],
          ),
          const SizedBox(height: Constants.space12),
          Text(
            '当前价格 ¥${currentPrice.toStringAsFixed(0)}，低于 90 天均价。建议立即购买，未来 14 天涨价概率较高。',
            style: Constants.body.copyWith(color: Constants.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStats() {
    return Row(
      children: [
        _buildStatCard('90天均价', '¥${(currentPrice * 1.1).toStringAsFixed(0)}'),
        const SizedBox(width: Constants.space12),
        _buildStatCard('历史最低', '¥${(currentPrice * 0.85).toStringAsFixed(0)}'),
        const SizedBox(width: Constants.space12),
        _buildStatCard('价格趋势', '下降 ↓'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Constants.space12),
        decoration: BoxDecoration(
          color: Constants.surfaceColor,
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
