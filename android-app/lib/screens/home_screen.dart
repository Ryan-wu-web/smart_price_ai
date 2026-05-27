import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';
import '../widgets/responsive_layout.dart';
import 'chat_screen.dart';
import 'compare_screen.dart';
import 'multi_object_screen.dart';
import 'result_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/scan_line_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _categories = ['运动鞋', '数码', '服饰', '美妆', '家居'];
  final List<Map<String, dynamic>> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _loadRecentRecords();
  }

  Future<void> _loadRecentRecords() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final recordsJson = prefs.getStringList('recent_records') ?? [];
    setState(() {
      _recentRecords.clear();
      _recentRecords.addAll(
        recordsJson
            .map((e) {
              try {
                return jsonDecode(e) as Map<String, dynamic>;
              } catch (_) {
                return null;
              }
            })
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
    });
  }

  Future<void> _saveRecentRecord(RecognitionResult result, String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final record = {
      'category': result.category,
      'brand': result.brand,
      'color': result.color,
      'confidence': result.confidence,
      'imagePath': imagePath,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _recentRecords.insert(0, record);
    while (_recentRecords.length > 5) {
      _recentRecords.removeLast();
    }
    await prefs.setStringList(
      'recent_records',
      _recentRecords.map((e) => jsonEncode(e)).toList(),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: source, maxWidth: 1200);
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('需要相机权限'),
            content: const Text(ErrorMessages.cameraDenied),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (picked == null) return;

    final file = File(picked.path);

    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Constants.durationNormal,
      pageBuilder: (_, __, ___) {
        return ScanLineOverlay(
          statusText: 'AI 正在识别...',
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );

    try {
      final result = await ApiService().recognize(file);

      if (!mounted) return;
      Navigator.pop(context);

      if (result != null) {
        await _saveRecentRecord(result, picked.path);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              recognitionResult: result,
              imageFile: file,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('识别失败: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickMultiObjectImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
    if (picked == null) return;
    final file = File(picked.path);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiObjectScreen(imageFile: file),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择图片来源',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Constants.brandColor),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  final focusContext = context;
                  Future.delayed(Duration.zero, () {
                    if (!focusContext.mounted) return;
                    FocusScope.of(focusContext).requestFocus(FocusNode());
                  });
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Constants.brandColor),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  final focusContext = context;
                  Future.delayed(Duration.zero, () {
                    if (!focusContext.mounted) return;
                    FocusScope.of(focusContext).requestFocus(FocusNode());
                  });
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hi, User',
                        style: Constants.display,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '今天想买点什么？',
                        style: Constants.label.copyWith(color: Constants.tertiaryTextColor),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Constants.primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Constants.largeRadius),
                    boxShadow: const [Constants.shadowLight],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Constants.secondaryTextColor),
                      const SizedBox(width: 8),
                      Text(
                        '搜索商品、品牌...',
                        style: TextStyle(
                          color: Constants.secondaryTextColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (_, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompareScreen(
                              category: _categories[index],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Constants.borderColor),
                        ),
                        child: Text(
                          _categories[index],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Constants.primaryTextColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(ResponsiveLayout.value(context,
                    small: 20.0,
                    medium: 28.0,
                    large: 36.0,
                  )),
                  decoration: BoxDecoration(
                    gradient: Constants.brandGradient,
                    borderRadius: BorderRadius.circular(Constants.xLargeRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Constants.brandColor.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '拍照识物',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '拍一张商品照片，AI 帮你识别并比价',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _pickMultiObjectImage();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Constants.surfaceColor,
                    borderRadius: BorderRadius.circular(Constants.radiusLarge),
                    boxShadow: const [Constants.shadowCard],
                    border: Border.all(color: Constants.brandColor.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.grid_view, color: Constants.brandColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '多目标识别',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Constants.primaryTextColor,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '拍一张场景照，AI 识别图中多个商品',
                              style: TextStyle(
                                fontSize: 12,
                                color: Constants.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Constants.tertiaryTextColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (_recentRecords.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '最近识别',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Constants.primaryTextColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('recent_records');
                        setState(() => _recentRecords.clear());
                      },
                      child: const Text(
                        '清空',
                        style: TextStyle(
                          fontSize: 13,
                          color: Constants.brandColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentRecords.length,
                    itemBuilder: (_, index) {
                      final record = _recentRecords[index];
                      final recentCardWidth = ResponsiveLayout.value(context,
                        small: 120.0,
                        medium: 140.0,
                        large: 160.0,
                      );
                      return Container(
                        width: recentCardWidth,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Constants.largeRadius),
                          boxShadow: const [Constants.shadowCard],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Constants.brandColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_circle,
                                  color: Constants.brandColor, size: 20),
                            ),
                            const Spacer(),
                            Text(
                              record['category'] ?? '未知商品',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Constants.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              record['brand'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Constants.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          }
        },
      ),
    );
  }
}
