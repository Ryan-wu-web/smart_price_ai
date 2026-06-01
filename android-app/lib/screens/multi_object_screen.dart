import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';
import 'result_screen.dart';

class MultiObjectScreen extends StatefulWidget {
  final File imageFile;

  const MultiObjectScreen({super.key, required this.imageFile});

  @override
  State<MultiObjectScreen> createState() => _MultiObjectScreenState();
}

class _MultiObjectScreenState extends State<MultiObjectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _detectedObjects = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _detectObjects();
  }

  Future<void> _detectObjects() async {
    try {
      final data = await ApiService().recognizeMultiple(widget.imageFile);
      if (data == null) {
        setState(() {
          _error = '识别失败，请重试';
          _isLoading = false;
        });
        return;
      }

      final singleResult = data['single_result'] as Map<String, dynamic>?;
      final objects = data['objects'] as List<dynamic>?;

      // 只有一个商品：直接跳转结果页
      if (singleResult != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                recognitionResult: RecognitionResult.fromJson(singleResult),
                imageFile: widget.imageFile,
              ),
            ),
          );
        }
        return;
      }

      // 多个商品：解析检测框数据
      final parsed = <Map<String, dynamic>>[];
      if (objects != null) {
        for (final item in objects) {
          if (item is! Map<String, dynamic>) continue;
          final bbox = item['bbox'];
          Map<String, dynamic> box;
          if (bbox is List && bbox.length >= 4) {
            box = {'x': bbox[0], 'y': bbox[1], 'w': bbox[2], 'h': bbox[3]};
          } else if (bbox is Map<String, dynamic>) {
            box = {
              'x': (bbox['x'] ?? 0.0).toDouble(),
              'y': (bbox['y'] ?? 0.0).toDouble(),
              'w': (bbox['w'] ?? 0.1).toDouble(),
              'h': (bbox['h'] ?? 0.1).toDouble(),
            };
          } else {
            box = {'x': 0.1, 'y': 0.1, 'w': 0.3, 'h': 0.3};
          }
          parsed.add({
            'name': item['name']?.toString() ?? '未知商品',
            'brand': item['brand']?.toString() ?? '',
            'category': item['category']?.toString() ?? '未知',
            'color': item['color']?.toString() ?? '',
            'x': box['x']!.toDouble(),
            'y': box['y']!.toDouble(),
            'w': box['w']!.toDouble(),
            'h': box['h']!.toDouble(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _detectedObjects = parsed;
          _isLoading = false;
        });
        _controller.forward();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMessages.recognizeFailed;
          _isLoading = false;
        });
      }
    }
  }

  void _onBoxTap(Map<String, dynamic> obj) {
    final result = RecognitionResult(
      name: obj['name'] as String,
      brand: obj['brand'] as String,
      category: obj['category'] as String,
      color: obj['color'] as String,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          recognitionResult: result,
          imageFile: widget.imageFile,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(widget.imageFile, fit: BoxFit.cover),
          // 暗化遮罩（保持图片可见）
          Container(color: Colors.black.withOpacity(0.2)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isLoading
                          ? '正在识别商品...'
                          : _error != null
                              ? '识别失败'
                              : '检测到 ${_detectedObjects.length} 个商品，点击识别',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 加载态：半透明白色遮罩 + 大脉冲圆点
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.15),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Constants.brandColor.withOpacity(
                              0.2 + 0.5 * _pulseController.value,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Constants.brandColor.withOpacity(
                                  0.3 + 0.5 * _pulseController.value,
                                ),
                                blurRadius: 30 + 20 * _pulseController.value,
                                spreadRadius: 4 + 6 * _pulseController.value,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'AI 正在识别中...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 错误态
          if (!_isLoading && _error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _detectObjects();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.brandColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          // 检测框
          if (!_isLoading && _error == null)
            ..._detectedObjects.asMap().entries.map((entry) {
              final index = entry.key;
              final obj = entry.value;
              final delay = index * 0.25;

              // 计算位置，限制不溢出屏幕
              var boxLeft = obj['x'] * size.width;
              var boxTop = obj['y'] * size.height;
              var boxWidth = (obj['w'] * size.width).clamp(80.0, size.width * 0.7);
              var boxHeight = (obj['h'] * size.height).clamp(50.0, size.height * 0.5);

              // 确保不超出屏幕
              if (boxLeft + boxWidth > size.width) {
                boxLeft = (size.width - boxWidth).clamp(0.0, size.width);
              }
              if (boxTop + boxHeight > size.height) {
                boxTop = (size.height - boxHeight).clamp(safeTop + 50.0, size.height);
              }
              if (boxTop < safeTop + 50) {
                boxTop = safeTop + 50;
              }

              // 交替颜色：品牌青 / 橙色
              final boxColor = index % 2 == 0
                  ? Constants.brandColor
                  : const Color(0xFFFF6B6B);

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final adjustedValue =
                      ((_controller.value - delay) / (1 - delay))
                          .clamp(0.0, 1.0);

                  return Opacity(
                    opacity: adjustedValue.toDouble(),
                    child: Positioned(
                      left: boxLeft,
                      top: boxTop,
                      child: GestureDetector(
                        onTap: () => _onBoxTap(obj),
                        child: SizedBox(
                          width: boxWidth,
                          height: boxHeight,
                          child: Stack(
                            children: [
                              // 外发光
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: boxColor.withOpacity(0.7),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              // 内边框 + 填充
                              Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: boxColor,
                                    width: 2,
                                  ),
                                  color: boxColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // 标签固定在内部顶部
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: boxColor,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: boxColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: boxWidth - 50,
                                        ),
                                        child: Text(
                                          obj['name'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}
