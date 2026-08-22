import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_number.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/budget_progress.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/reminder_tile.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/transaction_tile.dart';
import '../../transactions/presentation/add_edit_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openAddTransaction(BuildContext context, {TransactionType type = TransactionType.expense}) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditTransactionSheet(initialType: type),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final netBalance = ref.watch(netBalanceProvider);
    final totalIncome = ref.watch(totalIncomeProvider);
    final totalExpense = ref.watch(totalExpenseProvider);

    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    final remindersAsync = ref.watch(allRemindersProvider);
    final budgetsAsync = ref.watch(currentMonthBudgetsProvider);

    final todayDateStr = DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$todayDateStr · ARUL\'S EDITION',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'THE MONEY DESK',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search ProFin',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Reminders',
            onPressed: () => context.go('/reminders'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Search Banner
            GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Search food, Ooty, Rahul, ₹500...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 16, thickness: 1, color: AppColors.paperBorder),
            const SizedBox(height: 4),

            // TODAY'S HEADLINE Hero Section
            Text(
              'TODAY\'S HEADLINE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedNumber(
                  value: netBalance,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 38,
                  ),
                ),
                Text(
                  'available balance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.8, color: AppColors.paperBorder),
            const SizedBox(height: 16),

            // INDEX CARDS (INCOME INDEX & SPEND INDEX)
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INCOME INDEX',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedNumber(
                          value: totalIncome,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPEND INDEX',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedNumber(
                          value: totalExpense,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // EDITORIAL ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openAddTransaction(context, type: TransactionType.expense),
                    child: const Text('File an expense'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openAddTransaction(context, type: TransactionType.income),
                    child: const Text('Report income'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 0.8, color: AppColors.paperBorder),
            const SizedBox(height: 16),

            // Monthly Budget Progress Widget
            budgetsAsync.when(
              data: (budgets) {
                if (budgets.isEmpty) return const SizedBox();
                final totalBudget = budgets.fold(0.0, (sum, b) => sum + b.budget.limitRupees);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: AppCard(
                    child: BudgetProgressWidget(
                      label: 'Monthly Budget Limit',
                      spent: totalExpense,
                      limit: totalBudget,
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
            ),

            // NEEDS ATTENTION ALERT SECTION
            remindersAsync.when(
              data: (allReminders) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final urgentItems = allReminders.where((r) {
                  if (r.reminder.isCompleted) return false;
                  final dueDay = DateTime(r.reminder.dueDate.year, r.reminder.dueDate.month, r.reminder.dueDate.day);
                  return dueDay.isBefore(today) || dueDay.isAtSameMomentAs(today);
                }).toList();

                if (urgentItems.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Needs Attention',
                      actionLabel: 'View all →',
                      onAction: () => context.push('/reminders'),
                    ),
                    ...urgentItems.map(
                      (item) => ReminderTile(
                        reminder: item.reminder,
                        category: item.category,
                        onMarkPaid: () async {
                          HapticFeedbackUtil.selectionClick();
                          await ref.read(reminderRepositoryProvider).updateStatus(item.reminder.id, true);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
            ),

            // MARKET ACTIVITY / RECENT TRANSACTIONS SECTION
            SectionHeader(
              title: 'Market Activity',
              actionLabel: 'Full report →',
              onAction: () => context.go('/transactions'),
            ),
            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SizedBox(
                    height: 220,
                    child: EmptyStateWidget(
                      icon: Icons.newspaper_outlined,
                      title: 'No stories filed today',
                      description: 'Your first transaction makes tomorrow\'s front page.',
                      actionLabel: 'File your first entry',
                      onAction: () => _openAddTransaction(context),
                    ),
                  );
                }

                return Column(
                  children: transactions.map((item) {
                    return TransactionTile(
                      transaction: item.transaction,
                      category: item.category,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddEditTransactionSheet(transactionToEdit: item.transaction),
                        );
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => SkeletonLoader.tile(count: 3),
              error: (err, s) => Text('Error loading market activity: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
