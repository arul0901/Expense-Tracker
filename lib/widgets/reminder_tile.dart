import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../core/models/category_model.dart';
import '../core/models/reminder_model.dart';
import '../core/utils/date_formatter.dart';
import 'amount_text.dart';
import 'category_icon_widget.dart';

class ReminderTile extends StatelessWidget {
  final ReminderModel reminder;
  final CategoryModel? category;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ReminderTile({
    super.key,
    required this.reminder,
    this.category,
    this.onMarkPaid,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(reminder.dueDate.year, reminder.dueDate.month, reminder.dueDate.day);

    final isCompleted = reminder.isCompleted;
    final isOverdue = !isCompleted && dueDay.isBefore(today);
    final isDueToday = !isCompleted && dueDay.isAtSameMomentAs(today);

    Color tileBg = theme.colorScheme.surface;
    Color borderCol = isOverdue ? AppColors.dangerLight : (isDueToday ? AppColors.warningLight : theme.dividerColor);

    if (isOverdue) {
      tileBg = AppColors.dangerLight.withValues(alpha: 0.2);
    } else if (isDueToday) {
      tileBg = AppColors.warningLight.withValues(alpha: 0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: isOverdue || isDueToday ? 1.5 : 1.0),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CategoryIconWidget(
          iconName: category?.icon ?? 'receipt_long',
          colorValue: category?.color ?? 0xFF4F46E5,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                reminder.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isOverdue)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Due: ${DateFormatter.formatRelative(reminder.dueDate)} • ${reminder.frequency.toUpperCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOverdue ? AppColors.danger : theme.textTheme.bodySmall?.color,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              amount: reminder.amountRupees,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!isCompleted && onMarkPaid != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: AppColors.income),
                tooltip: 'Mark Paid',
                onPressed: onMarkPaid,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
