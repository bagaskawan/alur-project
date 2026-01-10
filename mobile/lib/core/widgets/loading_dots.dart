import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LoadingDots extends StatefulWidget {
  final Color? color;
  final double size;

  const LoadingDots({super.key, this.color, this.size = 8.0});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = (_controller.value + index * 0.2) % 1.0;
        final double scale = 0.6 + (0.4 * (1.0 - (t - 0.5).abs() * 2));

        return Container(
          width: widget.size,
          height: widget.size,
          margin: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
          decoration: BoxDecoration(
            color: (widget.color ?? AppColors.dark).withOpacity(
              0.4 + (scale - 0.6),
            ),
            shape: BoxShape.circle,
          ),
          transform: Matrix4.identity()..scale(scale),
        );
      },
    );
  }
}
