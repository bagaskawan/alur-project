import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Floating capsule chat input field with send button
class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  // Light mint green for send button (matching user bubble)
  static const Color sendButtonColor = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text input field
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          // Send button
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLoading ? Colors.grey.shade300 : sendButtonColor,
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.textSecondary.withOpacity(0.7),
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
