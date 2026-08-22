import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_motion.dart';

class AnimatedCheckWidget extends StatefulWidget {
  final bool isChecked;
  final VoidCallback? onTap;
  final double size;

  const AnimatedCheckWidget({
    super.key,
    required this.isChecked,
    this.onTap,
    this.size = 24,
  });

  @override
  State<AnimatedCheckWidget> createState() => _AnimatedCheckWidgetState();
}

class _AnimatedCheckWidgetState extends State<AnimatedCheckWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curveEmphasized),
    );

    if (widget.isChecked) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      if (widget.isChecked) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isChecked ? AppColors.income : Colors.transparent,
            border: Border.all(
              color: widget.isChecked ? AppColors.income : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: widget.isChecked
              ? Icon(
                  Icons.check,
                  size: widget.size * 0.65,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
