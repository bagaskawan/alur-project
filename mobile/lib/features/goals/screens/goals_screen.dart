import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/goals_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'blueprint_preview_screen.dart';

class GoalsScreen extends StatefulWidget {
  final bool isNewUser;

  const GoalsScreen({super.key, this.isNewUser = true});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GoalsService _goalsService = GoalsService();

  bool _isEnhancing = false;
  bool _isSessionStarted = false;

  // Chat State
  final List<Map<String, dynamic>> _messages =
      []; // {text: String, isUser: bool}
  bool _isAiLoading = false;
  String _loadingText = '';

  // Blueprint State
  bool _showBlueprintButton = false;
  String _currentGoal = '';
  String _currentTimeHorizon = '';

  // Typing Animation State
  Timer? _typingTimer;
  int _typingIndex = 0;
  String _currentTypingText = '';
  bool _isTyping = false;

  // Animation Controllers
  late AnimationController _transitionController;
  late Animation<double> _helperFadeAnimation;
  late Animation<double> _goalCardFadeAnimation;
  late Animation<double> _bubbleSlideAnimation;
  late Animation<double> _chatInputSlideAnimation;

  @override
  void initState() {
    super.initState();
    _goalController.text = '';

    // Main transition controller - longer duration for smoothness
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Helper text fades out first (0% - 40%)
    _helperFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // Goal card fades out (20% - 60%)
    _goalCardFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Bubble slides in from right (40% - 80%)
    _bubbleSlideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // Chat input slides up (50% - 100%)
    _chatInputSlideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _goalController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  /// Scroll to show the latest AI message at the top of the viewport
  void _scrollToLatestMessage() {
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

  /// Start typing animation for AI response (word by word)
  void _startTypingAnimation(String fullText, {Function? onComplete}) {
    _typingTimer?.cancel();

    final words = fullText.split(' ');
    _typingIndex = 0;
    _currentTypingText = '';
    _isTyping = true;

    // Add empty AI message that will be updated
    setState(() {
      _messages.add({'text': '', 'isUser': false, 'isTyping': true});
    });

    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_typingIndex < words.length) {
        setState(() {
          _currentTypingText +=
              ((_typingIndex > 0) ? ' ' : '') + words[_typingIndex];
          // Update the last message (which is the AI message being typed)
          if (_messages.isNotEmpty) {
            _messages.last['text'] = _currentTypingText;
          }
        });
        _typingIndex++;
        _scrollToLatestMessage();
      } else {
        timer.cancel();
        _isTyping = false;
        if (_messages.isNotEmpty) {
          _messages.last['isTyping'] = false;
        }
        if (onComplete != null) {
          onComplete();
        }
      }
    });
  }

  Future<void> _onAIEnhance() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis goal kamu dulu ya!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isEnhancing = true);

    try {
      final enhanced = await _goalsService.enhanceGoal(_goalController.text);
      _goalController.text = enhanced;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed enhance: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEnhancing = false);
      }
    }
  }

  Future<void> _processUserGoal() async {
    final rawGoal = _goalController.text.trim();
    if (rawGoal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis goal kamu dulu ya!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSessionStarted = true;
      _isAiLoading = true;
      _loadingText = 'Memperjelas kalimat...';
      // Add initial user message
      _messages.add({'text': rawGoal, 'isUser': true});
    });

    // Start animation immediately for smooth transition
    _transitionController.forward();

    try {
      // 1. Enhance Goal (Mocking the enhance call logic from service if not redundant,
      // but actually we already have the text in controller.
      // The user might have already clicked 'Enhance' manually.
      // If they didn't, we could enhance it here.
      // Current flow: User types -> (Optional Enhance) -> Click Start.
      // If we assume user wants to start with what is in the box:
      String currentGoal = rawGoal;

      // [TEMPORARILY DISABLED] Relationship Check - causes DB transaction errors
      // Uncomment when Supabase schema matches Python models
      /*
      if (mounted) setState(() => _loadingText = 'checking...');
      final relation = await _goalsService.checkGoalRelationship(currentGoal);
      if (relation['is_related'] == true && mounted) {
        // Show merge dialog...
      }
      */

      // 3. Strategy Advisor
      if (mounted) setState(() => _loadingText = 'Merancang strategi...');
      final strategy = await _goalsService.getStrategyAdvice(currentGoal);

      // Construct the AI welcome message based on strategy
      String strategyName = strategy['recommended_method'] ?? 'Metode Standar';
      String timeHorizon = strategy['time_horizon'] ?? 'beberapa waktu';
      String reason = strategy['why'] ?? '';

      String aiWelcome =
          "Oke, targetmu adalah **$currentGoal**. \n\n"
          "Berdasarkan kompleksitas goal ini, saya **merekomendasikan** sekitar **$timeHorizon** dengan metode **$strategyName**.\n"
          "_Alasan: ${reason}_ \n\n"
          "Apakah timeline ini sesuai, atau kamu punya target waktu sendiri?";

      if (mounted) {
        setState(() {
          _isAiLoading = false;
          // Store for Blueprint generation
          _currentGoal = currentGoal;
          _currentTimeHorizon = timeHorizon;
        });

        // Start typing animation for AI response
        _startTypingAnimation(aiWelcome);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          // Fallback message
          _messages.add({
            'text': 'Maaf, ada gangguan. Kita lanjut manual saja ya.',
            'isUser': false,
          });
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _onSendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    // Check if user is agreeing
    final agreementKeywords = [
      'setuju',
      'iya',
      'ya',
      'ok',
      'oke',
      'yes',
      'agree',
      'sesuai',
      'lanjut',
      'gas',
    ];
    final isAgreement = agreementKeywords.any(
      (k) => text.toLowerCase().contains(k),
    );

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isAiLoading = true;
    });

    try {
      final reply = await _goalsService.sendGoalSetupMessage(text);
      if (mounted) {
        setState(() => _isAiLoading = false);

        // Check for error response
        final isErrorResponse =
            reply.toLowerCase().contains('maaf') ||
            reply.toLowerCase().contains('error') ||
            reply.toLowerCase().contains('sibuk') ||
            reply.toLowerCase().contains('coba lagi');

        // Start typing animation with callback for agreement
        _startTypingAnimation(
          reply,
          onComplete: () {
            if (isAgreement && _currentGoal.isNotEmpty && !isErrorResponse) {
              setState(() => _showBlueprintButton = true);
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _transitionController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Expanded area for content
                  Expanded(
                    child: Stack(
                      children: [
                        // === BEFORE STATE: Helper text + Goal card ===
                        if (!_isSessionStarted ||
                            _transitionController.value < 1.0) ...[
                          // Helper text (fades out)
                          Positioned.fill(
                            child: Opacity(
                              opacity: _helperFadeAnimation.value,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [_buildHelperText()],
                              ),
                            ),
                          ),
                        ],

                        // === AFTER STATE: Chat Session ===
                        if (_isSessionStarted)
                          Positioned(
                            top: 0,
                            bottom:
                                0, // Ensure it takes full height available in Expanded
                            left: 0,
                            right: 0,
                            child: Opacity(
                              opacity: (_transitionController.value > 0.4)
                                  ? ((_transitionController.value - 0.4) / 0.4)
                                        .clamp(0.0, 1.0)
                                  : 0.0,
                              child: Transform.translate(
                                // Slide in effect wrapper
                                offset: Offset(_bubbleSlideAnimation.value, 0),
                                child: _buildSessionChat(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // === BOTTOM AREA ===
                  if (!_isSessionStarted ||
                      _transitionController.value < 1.0) ...[
                    // Goal card (fades out and slides down)
                    Opacity(
                      opacity: _goalCardFadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          (1 - _goalCardFadeAnimation.value) * 30,
                        ),
                        child: _buildGoalCard(),
                      ),
                    ),
                    SizedBox(height: 24 * _goalCardFadeAnimation.value),
                    // Start button (fades out)
                    Opacity(
                      opacity: _goalCardFadeAnimation.value,
                      child: _buildStartButton(),
                    ),
                  ],

                  // Chat input OR Blueprint button (slides up)
                  if (_isSessionStarted)
                    Transform.translate(
                      offset: Offset(0, _chatInputSlideAnimation.value),
                      child: Opacity(
                        opacity: (_transitionController.value > 0.5)
                            ? ((_transitionController.value - 0.5) / 0.5).clamp(
                                0.0,
                                1.0,
                              )
                            : 0.0,
                        child: _showBlueprintButton
                            ? _buildBlueprintButton()
                            : _buildChatInputRow(),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (!widget.isNewUser)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: AppColors.dark, size: 24),
            ),
          )
        else
          const SizedBox(width: 40),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _isSessionStarted ? 'Strategy Session' : 'Goals Setup',
              key: ValueKey<bool>(_isSessionStarted),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildHelperText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Be bold.',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: AppColors.dark.withOpacity(0.15),
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your strategy adapts to the ambition of your statement.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withOpacity(0.1),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: _messages.length + (_isAiLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildLoadingBubble();
        }
        final message = _messages[index];
        return _buildMessageBubble(
          message['text'] as String,
          message['isUser'] as bool,
        );
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.pastelYellow.withOpacity(0.6)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? AppColors.pastelYellow : Colors.black)
                  .withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: MarkdownBody(
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.dark,
              height: 1.5,
              fontFamily: 'Outfit',
            ),
            h1: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
              height: 1.4,
            ),
            h2: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
              height: 1.4,
            ),
            h3: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
              height: 1.4,
            ),
            strong: const TextStyle(fontWeight: FontWeight.w700),
            em: const TextStyle(fontStyle: FontStyle.italic),
            listBullet: TextStyle(
              color: AppColors.dark.withOpacity(0.6),
              fontSize: 14,
            ),
            blockSpacing: 8,
            listIndent: 20,
            blockquote: TextStyle(
              color: AppColors.dark.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
            code: TextStyle(
              backgroundColor: AppColors.dark.withOpacity(0.05),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppColors.dark.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.dark.withOpacity(0.5),
                ),
              ),
            ),
            if (_loadingText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _loadingText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dark.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final double offset = (value + index * 0.3) % 1.0;
        final double opacity = 0.3 + (0.7 * (1.0 - (offset - 0.5).abs() * 2));

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.dark.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd:
          () {}, // Loop handled by parent implicitly if rebuilt, but TweenAnimationBuilder isn't looping by default.
      // Better to use a simpler looping logic or just constant opacity for now to keep it simple as user asked for "bubble loading"
      // Let's use a simpler static Loading indicator or a repeating animation controller if available.
      // Since I can't easily add a new controller without refactoring big chunks, I'll use a standard Loading Indicator for simplicity but styled.
    );
  }

  Widget _buildGoalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _goalController,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.dark,
              height: 1.6,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Launch my Startup...',
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.dark.withOpacity(0.2),
                height: 1.6,
              ),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          // AI Enhance button
          Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              onTap: _isEnhancing ? null : _onAIEnhance,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isEnhancing
                      ? AppColors.dark.withOpacity(0.05)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.dark.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isEnhancing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                        ),
                      )
                    else
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 246, 92, 92),
                            Color.fromARGB(255, 246, 92, 246),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isEnhancing ? 'Enhancing...' : 'AI Enhance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isEnhancing
                            ? AppColors.dark.withOpacity(0.5)
                            : AppColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _processUserGoal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pastelYellow,
          foregroundColor: AppColors.dark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Start Strategy Session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueprintButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _onOpenBlueprint,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pastelYellow,
          foregroundColor: AppColors.dark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Lihat Blueprint Strategy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onOpenBlueprint() async {
    setState(() {
      _isAiLoading = true;
      _loadingText = 'Membuat blueprint detail...';
    });

    try {
      final blueprintResult = await _goalsService.generateBlueprint(
        _currentGoal,
        _currentTimeHorizon,
      );

      if (mounted) {
        setState(() => _isAiLoading = false);

        final blueprintData =
            blueprintResult['blueprint_data'] as List<dynamic>? ?? [];
        final goalTitle = blueprintResult['goal_title'] ?? _currentGoal;
        final timeHorizon =
            blueprintResult['time_horizon'] ?? _currentTimeHorizon;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlueprintPreviewScreen(
              goalTitle: goalTitle,
              timeHorizon: timeHorizon,
              blueprintData: blueprintData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating blueprint: $e')),
        );
      }
    }
  }

  Widget _buildChatInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Text input
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.dark.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _chatController,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 16, color: AppColors.dark),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ask about your strategy...',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: AppColors.dark.withOpacity(0.3),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Send button (circular)
        GestureDetector(
          onTap: _onSendMessage,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.pastelYellow,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pastelYellow.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: AppColors.dark,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
