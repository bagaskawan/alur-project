import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/loading_dots.dart';

class ChatScreen extends StatefulWidget {
  final String initialMode;

  const ChatScreen({super.key, this.initialMode = 'DAILY'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Sample messages for demonstration
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Good morning, Bagas! I noticed you have a high-energy session starting soon. How are you feeling?',
      'timestamp': 'Today, 9:41 AM',
    },
    {'isUser': true, 'text': "I'm feeling great and ready to focus!"},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Assistant',
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final showTimestamp = message['timestamp'] != null;

                return Column(
                  children: [
                    if (showTimestamp)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          message['timestamp'],
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    _buildMessageBubble(message['text'], message['isUser']),
                  ],
                );
              },
            ),
          ),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          boxShadow: isUser
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isUser ? Colors.white : AppColors.dark,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SafeArea(
        child: Row(
          children: [
            // Input Field (separate container)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _messageController,
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
                        child: LoadingDots(size: 4),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                        color: AppColors.dark,
                        size: 24,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _messageController.clear();
      _isLoading = true;
    });

    // Simulate AI response (replace with actual API call)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'isUser': false,
            'text':
                'This is a sample AI response. Connect to your backend API here.',
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
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
}
