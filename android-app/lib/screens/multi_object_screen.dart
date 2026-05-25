import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MultiObjectScreen extends StatefulWidget {
  final File imageFile;

  const MultiObjectScreen({super.key, required this.imageFile});

  @override
  State<MultiObjectScreen> createState() => _MultiObjectScreenState();
}

class _MultiObjectScreenState extends State<MultiObjectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  final List<Map<String, dynamic>> _detectedObjects = [
    {'name': '白色运动鞋', 'x': 0.15, 'y': 0.25, 'w': 0.4, 'h': 0.3},
    {'name': '黑色背包', 'x': 0.55, 'y': 0.35, 'w': 0.35, 'h': 0.35},
    {'name': '红色帽子', 'x': 0.25, 'y': 0.65, 'w': 0.3, 'h': 0.15},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBoxTap(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('识别: $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(widget.imageFile, fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '检测到 3 个商品，点击识别',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._detectedObjects.asMap().entries.map((entry) {
            final index = entry.key;
            final obj = entry.value;
            final delay = index * 0.25;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final adjustedValue =
                    ((_controller.value - delay) / (1 - delay))
                        .clamp(0.0, 1.0);

                return Opacity(
                  opacity: adjustedValue.toDouble(),
                  child: Positioned(
                    left: obj['x'] * size.width,
                    top: obj['y'] * size.height * 0.6,
                    child: GestureDetector(
                      onTap: () => _onBoxTap(obj['name'] as String),
                      child: Container(
                        width: obj['w'] * size.width,
                        height: obj['h'] * size.width,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Constants.brandColor,
                            width: 2,
                          ),
                          color: Constants.brandColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Constants.brandColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              obj['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
