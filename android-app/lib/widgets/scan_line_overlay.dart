import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 识别加载页：扫描线 + 脉冲圆点 + 进度阶段文字
/// 参考 frontend-design skill — 现代极简科技风
class ScanLineOverlay extends StatefulWidget {
  final Widget child;

  const ScanLineOverlay({
    super.key,
    required this.child,
  });

  @override
  State<ScanLineOverlay> createState() => _ScanLineOverlayState();
}

class _ScanLineOverlayState extends State<ScanLineOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 进度阶段：每 2 秒切换一次
  final List<String> _stages = const [
    '正在上传图片…',
    '正在分析商品特征…',
    '正在识别品牌和品类…',
    '正在生成结果…',
    '即将完成，请稍候…',
  ];
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // 每次动画循环完成时切换进度阶段，然后重新开始
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          if (_stageIndex < _stages.length - 1) {
            _stageIndex++;
          }
        });
        _controller.forward(from: 0.0);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPulseDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value + delay) % 1.0;
        final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
        // 最小不透明度 0.5，确保始终可见；最大 1.0
        final visibleOpacity = 0.5 + opacity * 0.5;
        // 脉冲缩放：0.8 ~ 1.3
        final scale = 0.8 + opacity * 0.5;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Constants.brandColor.withOpacity(visibleOpacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Constants.brandColor.withOpacity(visibleOpacity * 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
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
        // 暗化遮罩
        Container(
          color: Colors.black.withOpacity(0.25),
        ),
        // 扫描线
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: _controller.value * screenHeight * 0.65,
              left: 0,
              right: 0,
              child: child!,
            );
          },
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Constants.brandColor,
                  Constants.brandColor,
                  Colors.transparent,
                ],
                stops: [0.0, 0.25, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Constants.brandColor.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ),
        // 进度阶段文字（屏幕下方居中，脉冲圆点上方）
        Positioned(
          top: screenHeight * 0.62,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _stages[_stageIndex],
                  key: ValueKey<String>(_stages[_stageIndex]),
                  style: const TextStyle(
                    color: Constants.brandColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 脉冲圆点（屏幕下方居中）
        Positioned(
          top: screenHeight * 0.72,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulseDot(0.0),
                const SizedBox(width: 14),
                _buildPulseDot(0.33),
                const SizedBox(width: 14),
                _buildPulseDot(0.66),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
