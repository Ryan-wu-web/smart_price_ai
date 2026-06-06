import 'dart:io';
import 'package:flutter/material.dart';

import '../models/recognition_result.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';
import '../widgets/scan_line_overlay.dart';
import 'result_screen.dart';

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointDown;

  _TrianglePainter({required this.color, this.pointDown = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointDown) {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BubbleData {
  final int index;
  final String name;
  final String brand;
  final String category;
  final String color;
  // 归一化坐标 (0-1)，在 build 中转为屏幕坐标
  final double normX;
  final double normY;
  // 屏幕坐标（由 _computeBubblePositions 计算）
  double anchorX = 0;
  double anchorY = 0;
  double bubbleX = 0;
  double bubbleY = 0;
  bool below = false;

  _BubbleData({
    required this.index,
    required this.name,
    required this.brand,
    required this.category,
    required this.color,
    required this.normX,
    required this.normY,
  });
}

class MultiObjectScreen extends StatefulWidget {
  final File imageFile;

  const MultiObjectScreen({super.key, required this.imageFile});

  @override
  State<MultiObjectScreen> createState() => _MultiObjectScreenState();
}

class _MultiObjectScreenState extends State<MultiObjectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  bool _isLoading = true;
  String? _error;
  List<_BubbleData> _bubbles = [];

  static const double _bubbleMaxWidth = 160;
  static const double _bubbleHeight = 38;
  static const double _arrowHeight = 8;
  static const double _minHorizontalGap = 140;
  static const double _verticalStep = 48;
  static const double _marginTop = 56;
  static const double _marginBottom = 24;
  static const double _marginSide = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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

      final bubbles = <_BubbleData>[];
      if (objects != null) {
        for (var i = 0; i < objects.length; i++) {
          final item = objects[i];
          if (item is! Map<String, dynamic>) continue;

          double cx = 0.5, cy = 0.5;
          final center = item['center'];
          if (center is Map<String, dynamic>) {
            cx = (center['x'] ?? 0.5).toDouble();
            cy = (center['y'] ?? 0.5).toDouble();
          } else {
            final bbox = item['bbox'];
            if (bbox is Map<String, dynamic>) {
              final bx = (bbox['x'] ?? 0.0).toDouble();
              final by = (bbox['y'] ?? 0.0).toDouble();
              final bw = (bbox['w'] ?? 0.2).toDouble();
              final bh = (bbox['h'] ?? 0.2).toDouble();
              cx = bx + bw / 2;
              cy = by + bh / 2;
            } else if (bbox is List && bbox.length >= 4) {
              cx = (bbox[0] as num).toDouble() + (bbox[2] as num).toDouble() / 2;
              cy = (bbox[1] as num).toDouble() + (bbox[3] as num).toDouble() / 2;
            }
          }

          bubbles.add(
            _BubbleData(
              index: i,
              name: item['name']?.toString() ?? '未知商品',
              brand: item['brand']?.toString() ?? '',
              category: item['category']?.toString() ?? '未知',
              color: item['color']?.toString() ?? '',
              normX: cx.clamp(0.0, 1.0),
              normY: cy.clamp(0.0, 1.0),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _bubbles = bubbles;
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

  void _computeBubblePositions(double screenW, double screenH) {
    // 0. 将归一化坐标转为屏幕坐标
    for (final b in _bubbles) {
      b.anchorX = b.normX * screenW;
      b.anchorY = b.normY * screenH;
    }

    // 1. 初始位置：气泡在锚点上方，水平居中于锚点
    for (final b in _bubbles) {
      b.bubbleX = b.anchorX;
      b.bubbleY = b.anchorY - _bubbleHeight - _arrowHeight;
      b.below = false;
    }

    // 2. 上方空间不足 → 翻转到下方
    for (final b in _bubbles) {
      if (b.bubbleY < _marginTop) {
        b.below = true;
        b.bubbleY = b.anchorY + _arrowHeight;
      }
    }

    // 3. 按 bubbleX 排序，解决水平重叠（只向下推，不移动锚点）
    final sorted = List<_BubbleData>.from(_bubbles)
      ..sort((a, b) => a.bubbleX.compareTo(b.bubbleX));

    for (var i = 1; i < sorted.length; i++) {
      final curr = sorted[i];
      for (var j = 0; j < i; j++) {
        final prev = sorted[j];
        final dx = (curr.bubbleX - prev.bubbleX).abs();
        if (dx < _minHorizontalGap) {
          final minY = prev.bubbleY + _bubbleHeight + _arrowHeight + _verticalStep;
          if (curr.bubbleY < minY) {
            curr.bubbleY = minY;
          }
        }
      }
    }

    // 4. 如果 above 的气泡被推到锚点下方，强制翻转为 below
    for (final b in _bubbles) {
      if (!b.below && b.bubbleY + _bubbleHeight > b.anchorY) {
        b.below = true;
        b.bubbleY = b.anchorY + _arrowHeight;
      }
    }

    // 5. 底部越界检查
    for (final b in _bubbles) {
      if (b.bubbleY + _bubbleHeight > screenH - _marginBottom) {
        b.bubbleY = screenH - _marginBottom - _bubbleHeight;
      }
    }

    // 6. 气泡水平边缘 clamp（确保不超出屏幕）
    for (final b in _bubbles) {
      const halfW = _bubbleMaxWidth / 2;
      if (b.bubbleX - halfW < _marginSide) {
        b.bubbleX = _marginSide + halfW;
      }
      if (b.bubbleX + halfW > screenW - _marginSide) {
        b.bubbleX = screenW - _marginSide - halfW;
      }
    }
  }

  void _onBubbleTap(_BubbleData bubble) {
    final result = RecognitionResult(
      name: bubble.name,
      brand: bubble.brand,
      category: bubble.category,
      color: bubble.color,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 加载态：ScanLineOverlay（和拍照识物完全一致）
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ScanLineOverlay(
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // 加载页无返回按钮，和拍照识物加载页保持一致
          ],
        ),
      );
    }

    // 错误态
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.imageFile, fit: BoxFit.cover),
            Container(color: Colors.black.withOpacity(0.4)),
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
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
          ],
        ),
      );
    }

    // 结果态：图片 + 气泡标签
    _computeBubblePositions(size.width, size.height);

    return Scaffold(
      backgroundColor: Colors.black,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 原图
            Image.file(widget.imageFile, fit: BoxFit.cover),
            // Vignette 暗角：中心透明，边缘暗化，突出气泡
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.transparent, Color(0x40000000)],
                  center: Alignment.center,
                  radius: 0.85,
                ),
              ),
            ),
            // 锚点指示器：空心圆环
            ..._bubbles.map((bubble) {
              return Positioned(
                left: bubble.anchorX - 4,
                top: bubble.anchorY - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Constants.brandColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Constants.brandColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              );
            }),
            // 连接线：气泡 ↔ 锚点（只在有间距时显示）
            ..._bubbles.map((bubble) {
              final startY = bubble.below
                  ? bubble.anchorY
                  : bubble.bubbleY + _bubbleHeight + _arrowHeight;
              final endY = bubble.below
                  ? bubble.bubbleY - _arrowHeight
                  : bubble.anchorY;
              final top = startY < endY ? startY : endY;
              final height = (endY - startY).abs();
              if (height <= 2) return const SizedBox.shrink();

              return Positioned(
                left: bubble.anchorX - 1,
                top: top,
                child: Container(
                  width: 2,
                  height: height,
                  decoration: BoxDecoration(
                    color: Constants.brandColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
            // 气泡标签
            ..._bubbles.asMap().entries.map((entry) {
              final bubble = entry.value;
              final delay = entry.key * 0.12;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final rawValue = ((_controller.value - delay) / (1 - delay))
                      .clamp(0.0, 1.0);
                  final adjustedValue = Curves.elasticOut.transform(rawValue);
                  final opacity = rawValue.clamp(0.0, 1.0);

                  final arrowOffset = bubble.anchorX - bubble.bubbleX;
                  final clampedArrowOffset = arrowOffset.clamp(
                    -_bubbleMaxWidth / 2 + 12,
                    _bubbleMaxWidth / 2 - 12,
                  );

                  return Positioned(
                    left: bubble.bubbleX - _bubbleMaxWidth / 2,
                    top: bubble.bubbleY,
                    child: GestureDetector(
                      onTap: () => _onBubbleTap(bubble),
                      child: Transform.scale(
                        scale: adjustedValue,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!bubble.below)
                                Transform.translate(
                                  offset: Offset(clampedArrowOffset, 0),
                                  child: CustomPaint(
                                    size: const Size(12, _arrowHeight),
                                    painter: _TrianglePainter(
                                      color: const Color(0xFF00D4FF),
                                      pointDown: true,
                                    ),
                                  ),
                                ),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: _bubbleMaxWidth,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF00B4D8).withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    // 柔和品牌青外发光
                                    BoxShadow(
                                      color: const Color(0xFF00B4D8).withOpacity(0.15),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                    ),
                                    // 紧凑下沉阴影
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Constants.brandColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${bubble.index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        bubble.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (bubble.below)
                                Transform.translate(
                                  offset: Offset(clampedArrowOffset, 0),
                                  child: CustomPaint(
                                    size: const Size(12, _arrowHeight),
                                    painter: _TrianglePainter(
                                      color: const Color(0xFF00D4FF),
                                      pointDown: false,
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
      ),
    );
  }
}
