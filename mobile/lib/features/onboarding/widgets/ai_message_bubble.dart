import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// AI message bubble widget with avatar at bottom and "Alur" label
class AiMessageBubble extends StatelessWidget {
  final String message;
  final bool showLabel;
  final bool showAvatar;

  const AiMessageBubble({
    super.key,
    required this.message,
    this.showLabel = true,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 48, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alur label
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Text(
                'Alur',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Message with avatar at bottom-left
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI Avatar (at bottom)
              if (showAvatar)
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/hero_illustration.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 44), // Space for alignment when no avatar
              // Message bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.grey.shade200),
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
        ],
      ),
    );
  }
}
