import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme/app_motion.dart';

class AnimatedNumber extends ImplicitlyAnimatedWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = '₹',
    this.suffix = '',
    super.duration = AppMotion.durationNormal,
    super.curve = AppMotion.curveNormal,
  });

  @override
  ImplicitlyAnimatedWidgetState<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends AnimatedWidgetBaseState<AnimatedNumber> {
  Tween<double>? _numberTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _numberTween = visitor(
      _numberTween,
      widget.value,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final double currentValue = _numberTween?.evaluate(animation) ?? widget.value;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: widget.prefix,
      decimalDigits: 2,
    );

    return Text(
      '${formatter.format(currentValue.abs())}${widget.suffix}',
      style: widget.style,
    );
  }
}
