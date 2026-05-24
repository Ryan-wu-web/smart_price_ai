import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 浅色主题底部输入栏
/// 白色背景 + 浅灰输入框 + 品牌色圆形发送按钮
class BottomInputBar extends StatelessWidget {
  final TextEditingController? controller;
  final VoidCallback? onSend;
  final String hintText;
  final bool showSendButton;
  final bool showMicButton;

  const BottomInputBar({
    super.key,
    this.controller,
    this.onSend,
    this.hintText = '输入内容...',
    this.showSendButton = true,
    this.showMicButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(Constants.radiusXLarge),
          topRight: Radius.circular(Constants.radiusXLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (showMicButton) ...[
              GestureDetector(
                onTap: () {
                  // TODO: voice input
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Constants.backgroundColor,
                    borderRadius: BorderRadius.circular(Constants.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Constants.secondaryTextColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Constants.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Constants.primaryTextColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Constants.tertiaryTextColor,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            if (showSendButton) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: Constants.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [Constants.shadowButton],
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
