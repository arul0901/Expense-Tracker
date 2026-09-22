import 'package:flutter/material.dart';
import '../core/models/category_model.dart';
import '../core/models/transaction_model.dart';
import '../core/utils/date_formatter.dart';
import '../app/theme/app_colors.dart';
import 'amount_text.dart';
import 'app_card.dart';
import 'category_icon_widget.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncome ? AppColors.incomeLight : AppColors.primaryInk,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CategoryIconWidget(
              iconName: category.icon,
              colorValue: Colors.white.value, // Force white icon inside solid block
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.note != null && transaction.note!.isNotEmpty
                      ? transaction.note!
                      : category.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  category.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                amount: transaction.amountRupees,
                isIncome: isIncome,
                showSign: true,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Today, ${DateFormatter.formatTime(transaction.date)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
