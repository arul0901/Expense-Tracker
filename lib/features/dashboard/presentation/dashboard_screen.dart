import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/auth/providers/auth_provider.dart';
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
import '../../budgets/presentation/add_edit_budget_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openAddTransaction(
    BuildContext context, {
    TransactionType type = TransactionType.expense,
  }) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditTransactionSheet(initialType: type),
    );
  }

  void _openAddBudget(BuildContext context) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddEditBudgetSheet(),
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

    final todayDateStr = DateFormat(
      'EEEE, MMM d',
    ).format(DateTime.now()).toUpperCase();

    final authState = ref.watch(authNotifierProvider);
    final userName = authState.user?.displayName ?? 'User';

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: AppColors.primaryInk,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello,',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              'Good day, $userName!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Reminders',
            onPressed: () => context.go('/reminders'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome), // AI Assistant Icon
            tooltip: 'AI Assistant',
            onPressed: () => context.push('/ai-assistant'), // Assuming route
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOTAL BALANCE CARD (Blue Gradient)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF0284C7),
                  ], // Vibrant Blue Gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedNumber(
                    value: netBalance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_box,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Include saving plan',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _openAddBudget(context),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // STATISTICS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('MMMM').format(DateTime.now()),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedNumber(
                          value: totalIncome,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.expenseLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedNumber(
                          value: totalExpense,
                          style: const TextStyle(
                            fontSize: 22,
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
            const SizedBox(height: 32),

            // SAVING PLAN / BUDGETS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saving Plan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            budgetsAsync.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return InkWell(
                    onTap: () => _openAddBudget(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.paperBorder,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            color: AppColors.textMutedLight,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No saving plans yet',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap to create one',
                            style: TextStyle(
                              color: AppColors.textMutedLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Render as horizontal scrolling cards to match reference
                return SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final b = budgets[index];
                      // Just mock progress for UI demonstration since we don't have per-budget spend calculated here easily
                      final double progress = 0.45;

                      return Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.paperBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  b.category?.name ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'On Process',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${(b.budget.limitRupees * progress).toInt()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${b.budget.limitRupees.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.paperBorder,
                              color: AppColors.primaryAccent,
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
            ),
            const SizedBox(height: 32),

            // NEEDS ATTENTION ALERT SECTION
            remindersAsync.when(
              data: (allReminders) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final urgentItems = allReminders.where((r) {
                  if (r.reminder.isCompleted) return false;
                  final dueDay = DateTime(
                    r.reminder.dueDate.year,
                    r.reminder.dueDate.month,
                    r.reminder.dueDate.day,
                  );
                  return dueDay.isBefore(today) ||
                      dueDay.isAtSameMomentAs(today);
                }).toList();

                if (urgentItems.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Needs Attention',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/reminders'),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...urgentItems.map(
                      (item) => ReminderTile(
                        reminder: item.reminder,
                        category: item.category,
                        onMarkPaid: () async {
                          HapticFeedbackUtil.selectionClick();
                          await ref
                              .read(reminderRepositoryProvider)
                              .updateStatus(item.reminder.id, true);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
            ),

            // RECENT TRANSACTIONS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SizedBox(
                    height: 220,
                    child: EmptyStateWidget(
                      icon: Icons.newspaper_outlined,
                      title: 'No stories filed today',
                      description:
                          'Your first transaction makes tomorrow\'s front page.',
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
                          builder: (context) => AddEditTransactionSheet(
                            transactionToEdit: item.transaction,
                          ),
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
