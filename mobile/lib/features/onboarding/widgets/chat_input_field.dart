import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

/// Floating capsule chat input field with send button
/// Supports: Enter = Send, Shift+Enter = New Line (like WhatsApp/Telegram desktop)
class ChatInputField extends StatefulWidget {
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
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard events: Enter = Send, Shift+Enter = New Line
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only handle key down events for Enter key
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // Check if Shift is pressed
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isShiftPressed) {
        // Shift+Enter: Insert new line (let the event propagate)
        return KeyEventResult.ignored;
      } else {
        // Enter only: Send message
        if (!widget.isLoading && widget.controller.text.trim().isNotEmpty) {
          widget.onSend();
        }
        return KeyEventResult.handled; // Prevent default newline
      }
    }
    return KeyEventResult.ignored;
  }

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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 120, // Max height before scrolling (about 5 lines)
              ),
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: TextField(
                  controller: widget.controller,
                  enabled: !widget.isLoading,
                  maxLines: null, // Allow unlimited lines
                  minLines: 1, // Start with single line
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
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
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          // Send button
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: GestureDetector(
              onTap: widget.isLoading ? null : widget.onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isLoading
                      ? Colors.grey.shade300
                      : ChatInputField.sendButtonColor,
                  shape: BoxShape.circle,
                ),
                child: widget.isLoading
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
          ),
        ],
      ),
    );
  }
}
