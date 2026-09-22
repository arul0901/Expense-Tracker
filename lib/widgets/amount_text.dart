import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme/app_colors.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final bool? isIncome;
  final bool showSign;
  final TextStyle? style;

  const AmountText({
    super.key,
    required this.amount,
    this.isIncome,
    this.showSign = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    final String formatted = formatter.format(amount.abs());
    String text = formatted;

    if (showSign && amount != 0) {
      final String sign = isIncome == true ? '+' : (isIncome == false ? '−' : (amount > 0 ? '+' : '−'));
      text = '$sign$formatted';
    }

    Color color;
    if (isIncome == true) {
      color = AppColors.income;
    } else if (isIncome == false) {
      color = AppColors.expense;
    } else {
      color = style?.color ?? Theme.of(context).textTheme.titleMedium?.color ?? Theme.of(context).colorScheme.onSurface;
    }

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
