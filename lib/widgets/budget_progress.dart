import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import 'amount_text.dart';

class BudgetProgressWidget extends StatelessWidget {
  final String label;
  final double spent;
  final double limit;

  const BudgetProgressWidget({
    super.key,
    required this.label,
    required this.spent,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final percentage = (ratio * 100).toInt();

    Color color = AppColors.income;
    if (ratio >= 0.90) {
      color = AppColors.expense;
    } else if (ratio >= 0.75) {
      color = AppColors.warning;
    }

    final remaining = (limit - spent).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('$percentage%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Spent ', style: TextStyle(fontSize: 12)),
                AmountText(amount: spent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              children: [
                Text(ratio >= 1.0 ? 'Exceeded by ' : 'Remaining ', style: const TextStyle(fontSize: 12)),
                AmountText(
                  amount: ratio >= 1.0 ? (spent - limit) : remaining,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ratio >= 1.0 ? AppColors.expense : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
