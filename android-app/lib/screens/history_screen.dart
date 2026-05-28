import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'compare_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('recent_records') ?? [];
    if (!mounted) return;
    setState(() {
      _records = recordsJson
          .map((e) {
            try {
              return jsonDecode(e) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有识别记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Constants.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_records');
    if (!mounted) return;
    setState(() => _records.clear());
  }

  void _showDetailDialog(Map<String, dynamic> record) {
    final imagePath = record['imagePath'] as String?;
    final category = record['category'] as String? ?? '未知商品';
    final brand = record['brand'] as String?;
    final color = record['color'] as String?;
    final confidence = (record['confidence'] as num?)?.toDouble() ?? 0.0;
    final timestamp = record['timestamp'] as String?;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Constants.radiusXLarge),
            boxShadow: const [Constants.shadowCard],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null && File(imagePath).existsSync())
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Constants.radiusXLarge),
                  ),
                  child: Image.file(
                    File(imagePath),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Constants.brandColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Constants.brandColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Constants.successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDetailRow('品牌', brand ?? '—'),
                    _buildDetailRow('颜色', color ?? '—'),
                    if (timestamp != null)
                      _buildDetailRow(
                        '识别时间',
                        DateFormat('MM-dd HH:mm').format(DateTime.parse(timestamp)),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompareScreen(
                                category: category,
                                brand: brand,
                                color: color,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.brandColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('查看比价', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Constants.secondaryTextColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Constants.primaryTextColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '识别历史',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Constants.primaryTextColor),
        ),
        actions: [
          if (_records.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('清空', style: TextStyle(color: Constants.errorColor, fontSize: 14)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Constants.tertiaryTextColor),
            SizedBox(height: 16),
            Text('暂无识别记录', style: TextStyle(fontSize: 15, color: Constants.secondaryTextColor)),
            SizedBox(height: 8),
            Text(
              '去首页拍照识物吧',
              style: TextStyle(fontSize: 13, color: Constants.tertiaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, index) {
        final record = _records[index];
        final imagePath = record['imagePath'] as String?;
        final category = record['category'] as String? ?? '未知商品';
        final brand = record['brand'] as String?;
        final color = record['color'] as String?;
        final timestamp = record['timestamp'] as String?;

        return GestureDetector(
          onTap: () => _showDetailDialog(record),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Constants.largeRadius),
              boxShadow: const [Constants.shadowLight],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Constants.mediumRadius),
                    color: Constants.backgroundColor,
                    image: imagePath != null && File(imagePath).existsSync()
                        ? DecorationImage(image: FileImage(File(imagePath)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imagePath == null || !File(imagePath).existsSync()
                      ? const Icon(Icons.image, color: Constants.tertiaryTextColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Constants.primaryTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [if (brand != null) brand, if (color != null) color].join(' · '),
                        style: const TextStyle(fontSize: 12, color: Constants.secondaryTextColor),
                      ),
                      const SizedBox(height: 4),
                      if (timestamp != null)
                        Text(
                          DateFormat('MM-dd HH:mm').format(DateTime.parse(timestamp)),
                          style: const TextStyle(fontSize: 11, color: Constants.tertiaryTextColor),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Constants.tertiaryTextColor),
              ],
            ),
          ),
        );
      },
    );
  }
}
