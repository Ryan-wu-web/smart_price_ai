import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ScanLineOverlay extends StatefulWidget {
  final Widget child;
  final String statusText;

  const ScanLineOverlay({
    super.key,
    required this.child,
    this.statusText = 'AI 正在识别...',
  });

  @override
  State<ScanLineOverlay> createState() => _ScanLineOverlayState();
}

class _ScanLineOverlayState extends State<ScanLineOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<String> _statusTexts = [
    'AI 正在识别...',
    '分析商品特征...',
    '生成比价方案...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStatusText(double value) {
    final index = (value * 3).floor() % 3;
    return _statusTexts[index];
  }

  Widget _buildPulseDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value + delay) % 1.0;
        final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Constants.brandColor.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Container(
          color: Colors.black.withOpacity(0.3),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: _controller.value * screenHeight * 0.6,
              left: 0,
              right: 0,
              child: child!,
            );
          },
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Constants.brandColor.withOpacity(0.8),
                  Constants.brandColor.withOpacity(0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Constants.brandColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: screenHeight * 0.6 + 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _getStatusText(_controller.value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: screenHeight * 0.6 + 56,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulseDot(0.0),
                const SizedBox(width: 8),
                _buildPulseDot(0.33),
                const SizedBox(width: 8),
                _buildPulseDot(0.66),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
