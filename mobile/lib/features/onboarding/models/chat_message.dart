/// Enum representing message sender types
enum MessageSender { user, ai }

/// Model class for chat messages in the onboarding flow
class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isOnboarding;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    DateTime? timestamp,
    this.isOnboarding = true,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.user,
    );
  }

  /// Create an AI message
  factory ChatMessage.ai(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.ai,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'content': content,
      'sender': sender == MessageSender.user ? 'USER' : 'AI',
      'is_onboarding': isOnboarding,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
