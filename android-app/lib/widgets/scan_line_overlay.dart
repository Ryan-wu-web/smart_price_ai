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
        Positioned(
          top: screenHeight * 0.6 + 24,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              widget.statusText,
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
        ),
        Positioned(
          top: screenHeight * 0.6 + 56,
          left: 64,
          right: 64,
          child: const LinearProgressIndicator(
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Constants.brandColor),
          ),
        ),
      ],
    );
  }
}
