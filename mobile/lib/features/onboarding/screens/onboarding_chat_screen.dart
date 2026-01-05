import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';
import '../services/onboarding_service.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/user_message_bubble.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/typing_indicator.dart';

/// Onboarding chat screen for collecting user profile data through
/// a conversational AI interview
class OnboardingChatScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingChatScreen({super.key, this.onComplete});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnboardingService _onboardingService = OnboardingService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoading = false;
  bool _showGetStartedButton = false;

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addInitialMessage() async {
    // Small delay for natural feel
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage.ai(_onboardingService.getInitialMessage()));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage.user(text));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Show typing indicator
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isTyping = true);
    _scrollToBottom();

    // Get AI response
    try {
      final response = await _onboardingService.processUserMessage(text);

      // Typing delay for natural feel
      final typingDelay = 800 + (response.length * 10).clamp(0, 1500);
      await Future.delayed(Duration(milliseconds: typingDelay));
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _isLoading = false;
        _messages.add(ChatMessage.ai(response));

        // Show "Get Started" button when onboarding is complete
        if (_onboardingService.isComplete) {
          _showGetStartedButton = true;
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    try {
      // Save data to Supabase
      await _onboardingService.savePersonalizationData();
      await _onboardingService.saveChatMessages(_messages);

      if (mounted) {
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Onboarding Chat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Show typing indicator at the end
                if (_isTyping && index == _messages.length) {
                  return const TypingIndicator();
                }

                final message = _messages[index];
                if (message.sender == MessageSender.ai) {
                  // Show label only for first AI message or after user message
                  final showLabel =
                      index == 0 ||
                      (index > 0 &&
                          _messages[index - 1].sender == MessageSender.user);
                  return AiMessageBubble(
                    message: message.content,
                    showLabel: showLabel,
                  );
                } else {
                  return UserMessageBubble(
                    message: message.content,
                    timestamp: message.timestamp,
                  );
                }
              },
            ),
          ),

          // Get Started button (shown when onboarding is complete)
          if (_showGetStartedButton) _buildGetStartedButton(),

          // Input field (hidden when showing Get Started button)
          if (!_showGetStartedButton)
            ChatInputField(
              controller: _textController,
              onSend: _handleSend,
              isLoading: _isLoading,
            ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4988C4), // Blue send button color
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Get Started',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
