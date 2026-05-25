import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ReportScreen extends StatelessWidget {
  final String productName;
  final Map<String, dynamic>? reportData;

  const ReportScreen({
    super.key,
    required this.productName,
    this.reportData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        title: const Text('决策报告'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能开发中')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Constants.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportHeader(),
            const SizedBox(height: Constants.space20),
            _buildBestChoiceCard(),
            const SizedBox(height: Constants.space20),
            _buildAlternativesSection(),
            const SizedBox(height: Constants.space20),
            _buildAISuggestionCard(),
            const SizedBox(height: Constants.space32),
            _buildShareButton(context),
            const SizedBox(height: Constants.space24),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.all(Constants.space20),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AI 生成',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Constants.space12),
          Text(
            '购物决策报告',
            style: Constants.display.copyWith(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: Constants.space8),
          Text(
            productName,
            style: Constants.body.copyWith(color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildBestChoiceCard() {
    return Container(
      padding: const EdgeInsets.all(Constants.space16),
      decoration: BoxDecoration(
        color: Constants.surfaceColor,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
        border: const Border(left: BorderSide(color: Constants.brandColor, width: 3)),
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
                child: const Icon(Icons.emoji_events, color: Constants.successColor, size: 18),
              ),
              const SizedBox(width: Constants.space12),
              const Text('最优选择', style: Constants.h2),
              const Spacer(),
            ],
          ),
          const SizedBox(height: Constants.space16),
          _buildInfoRow('平台', '京东'),
          _buildInfoRow('价格', '¥749', isHighlight: true),
          _buildInfoRow('优惠', '↓16%'),
          _buildInfoRow('理由', '90天最低价，官方旗舰店'),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Constants.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: Constants.caption),
          ),
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
          const Text('其他选择', style: Constants.h2),
          const SizedBox.shrink(),
          const SizedBox(height: Constants.space12),
          _buildAlternativeItem('淘宝', '¥799', '官方店'),
          const Divider(height: 16),
          _buildAlternativeItem('拼多多', '¥699', '百亿补贴'),
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
        const SizedBox(width: Constants.space12),
        Text(price, style: Constants.body.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(tag, style: Constants.caption),
      ],
    );
  }

  Widget _buildAISuggestionCard() {
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
                child: const Icon(Icons.lightbulb, color: Constants.brandColor, size: 18),
              ),
              const SizedBox(width: Constants.space12),
              const Text('AI 建议', style: Constants.h2),
            ],
          ),
          const SizedBox(height: Constants.space12),
          Text(
            '立即购买，未来14天涨价概率 73%。当前价格为90天最低价，且为官方旗舰店，售后有保障。',
            style: Constants.body.copyWith(color: Constants.secondaryTextColor),
          ),
          const SizedBox(height: Constants.space12),
          Row(
            children: [
              const Icon(Icons.verified, color: Constants.brandColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'AI 置信度 89%',
                style: Constants.caption.copyWith(color: Constants.brandColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('报告保存功能开发中')),
          );
        },
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
