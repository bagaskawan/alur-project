import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// AI message bubble widget with avatar at bottom and "Alur" label
/// Supports basic markdown: **bold** text
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

  /// Parse simple markdown and return styled TextSpans
  /// Supports: **bold** and *italic/emphasis*
  List<TextSpan> _parseMarkdown(String text) {
    final List<TextSpan> spans = [];

    // Combined pattern: **bold** or *italic* (but not ** inside *)
    // Process text character by character for proper nested handling
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|\*([^*]+?)\*');

    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      if (match.group(1) != null) {
        // **bold** match (group 1)
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (match.group(2) != null) {
        // *italic* match (group 2) - render as bold too for better visibility
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    // If no matches found, return original text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 64, bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            children: _parseMarkdown(message),
          ),
        ),
      ),
    );
  }
}
