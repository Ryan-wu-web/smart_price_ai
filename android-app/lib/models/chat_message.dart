class ChatMessage {
  final String id;
  String text;              // 流式更新需要可变
  final bool isUser;
  final DateTime timestamp;
  String? action;           // 流式结束后更新
  Map<String, dynamic>? actionData; // 流式结束后更新

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.actionData,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['message']?.toString() ?? '',
      isUser: json['is_user'] == true || json['isUser'] == true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      action: json['action']?.toString(),
      actionData: json['action_data'] as Map<String, dynamic>? ??
          json['actionData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'actionData': actionData,
    };
  }
}
