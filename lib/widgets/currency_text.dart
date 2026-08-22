import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSign;
  final bool? isIncome;

  const CurrencyText({
    super.key,
    required this.amount,
    this.style,
    this.showSign = false,
    this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    Color? color = style?.color;

    if (isIncome != null) {
      color = isIncome! ? AppColors.income : AppColors.expense;
    }

    String sign = '';
    if (showSign && amount != 0) {
      if (isIncome == true || amount > 0) {
        sign = '+';
      } else if (isIncome == false || amount < 0) {
        sign = '-';
      }
    }

    final formatted = CurrencyFormatter.format(amount.abs());

    return Text(
      '$sign$formatted',
      style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
        color: color,
        fontWeight: style?.fontWeight ?? FontWeight.w600,
      ),
    );
  }
}
