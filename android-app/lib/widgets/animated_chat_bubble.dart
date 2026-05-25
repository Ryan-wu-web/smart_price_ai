import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';
import 'chat_bubble.dart';

class AnimatedChatBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;

  const AnimatedChatBubble({
    super.key,
    required this.message,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final offsetX = message.isUser ? 30.0 : -30.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Constants.durationNormal,
      curve: Constants.easeEntrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offsetX * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: ChatBubble(message: message),
    );
  }
}
