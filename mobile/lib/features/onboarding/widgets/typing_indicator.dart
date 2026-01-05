import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Animated typing indicator showing AI is "thinking"
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 48, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar (at bottom, matching message style)
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
                'assets/images/ai_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          // Typing dots container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return _BouncingDot(
                  animation: _animations[index],
                  isLast: index == 2,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single bouncing dot widget
class _BouncingDot extends AnimatedWidget {
  final bool isLast;

  const _BouncingDot({
    required Animation<double> animation,
    this.isLast = false,
  }) : super(listenable: animation);

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: isLast ? 0 : 6),
      child: Transform.translate(
        offset: Offset(0, -4 * _animation.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            // Using Pastel Blue for typing indicator
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
