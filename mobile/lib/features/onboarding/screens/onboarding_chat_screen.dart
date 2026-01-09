import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';
import '../services/onboarding_service.dart';
import '../widgets/typing_indicator.dart';

/// Onboarding chat screen for collecting user profile data through
/// a conversational AI interview
class OnboardingChatScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingChatScreen({super.key, this.onComplete});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnboardingService _onboardingService = OnboardingService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoading = false;
  bool _showGetStartedButton = false;

  // Keep state alive when widget is temporarily removed (e.g., app backgrounded)
  @override
  bool get wantKeepAlive => true;

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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),

            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                // +1 for intro section at top
                itemCount: 1 + _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  // Index 0 = Intro Section
                  if (index == 0) {
                    return _buildIntroSection();
                  }

                  // Adjust index for messages (offset by 1 due to intro)
                  final messageIndex = index - 1;

                  // Show typing indicator at the end
                  if (_isTyping && messageIndex == _messages.length) {
                    return _buildTypingIndicatorBubble();
                  }

                  final message = _messages[messageIndex];
                  return _buildMessageBubble(
                    message.content,
                    message.sender == MessageSender.user,
                  );
                },
              ),
            ),

            // Bottom Area (Chips + Input or Button)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.0),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.2],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showGetStartedButton)
                    _buildGetStartedButton()
                  else ...[
                    if (!_isLoading && !_isTyping) _buildChoiceChips(),
                    const SizedBox(height: 16),
                    _buildChatInputArea(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'Onboarding Session',
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('👋', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Selamat datang!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Sebelum mulai, aku ingin kenalan dulu denganmu. '
            'Aku akan bertanya beberapa hal sederhana untuk memahami '
            'kebiasaan dan preferensimu.',
            style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.dark),
          ),
          const SizedBox(height: 12),
          Text(
            '🔒 Tenang, data kamu hanya digunakan untuk memberikan '
            'rekomendasi yang lebih personal dan tidak akan dibagikan ke pihak lain.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.pastelYellow : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: isUser
            ? Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.dark,
                ),
              )
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.dark,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                  em: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.dark,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 8, bottom: 16),
        child: TypingIndicator(),
      ),
    );
  }

  Widget _buildChoiceChips() {
    final options = _onboardingService.getOptionsForCurrentStage();
    if (options == null || options.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(option),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary, // Blue text
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              ),
              onPressed: () {
                _textController.text = option;
                _handleSend();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatInputArea() {
    return Row(
      children: [
        // Input Field (separate container)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(28),
            ),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send Button (separate)
        GestureDetector(
          onTap: _isLoading ? null : _handleSend,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey[300] : AppColors.pastelYellow,
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      color: AppColors.dark,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward,
                    color: AppColors.dark,
                    size: 24,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.dark.withOpacity(0.3),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
