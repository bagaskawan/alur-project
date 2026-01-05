import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// User message bubble widget - right-aligned with light mint background
class UserMessageBubble extends StatelessWidget {
  final String message;
  final DateTime timestamp;

  const UserMessageBubble({
    super.key,
    required this.message,
    required this.timestamp,
  });

  // Light mint/pastel green for user messages
  static const Color userBubbleColor = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: userBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
