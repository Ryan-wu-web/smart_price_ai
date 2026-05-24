import 'package:flutter/material.dart';

/// 极淡噪点纹理覆盖层
/// 避免纯平背景色的单调感（frontend-design 推荐）
class NoiseTexture extends StatelessWidget {
  final Widget child;
  final double opacity;

  const NoiseTexture({
    super.key,
    required this.child,
    this.opacity = 0.03,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _NoisePainter(),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.5;

    const step = 4.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if ((x + y) % 7 == 0 || (x * y) % 11 == 0) {
          canvas.drawCircle(Offset(x, y), 0.3, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
