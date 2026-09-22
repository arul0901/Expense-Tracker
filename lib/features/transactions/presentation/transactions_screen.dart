import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/filter_bottom_sheet.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/transaction_tile.dart';
import 'add_edit_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransactionType? _filterType;

  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddTransactionSheet([TransactionModel? item]) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditTransactionSheet(transactionToEdit: item),
    );
  }

  void _openFilterBottomSheet() {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FilterBottomSheet(
        initialType: _filterType,
        onApply: (type) {
          setState(() => _filterType = type);
        },
      ),
    );
  }

  Future<void> _confirmDelete(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.mediumImpact();
      await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(transaction.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search ProFin',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _filterType != null ? AppColors.primary : null,
            ),
            onPressed: _openFilterBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddTransactionSheet(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
          ],
        ),
      ),
      body: transactionsAsync.when(
        data: (allList) {
          final filtered = allList.where((item) {
            return _filterType == null ||
                item.transaction.type == _filterType!.name;
          }).toList();

          if (filtered.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Found',
              description: 'Try adjusting your search or filters.',
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDailyView(filtered, theme),
              _buildWeeklyView(filtered, theme),
              _buildMonthlyView(filtered, theme),
              _buildYearlyView(filtered, theme),
            ],
          );
        },
        loading: () => SkeletonLoader.tile(count: 5),
        error: (err, stack) =>
            Center(child: Text('Error loading transactions: $err')),
      ),
    );
  }

  Widget _buildDailyView(List<TransactionWithCategory> items, ThemeData theme) {
    final Map<String, List<TransactionWithCategory>> grouped = {};
    for (final item in items) {
      final dateKey = DateFormatter.formatShortDate(item.transaction.date);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final list = grouped[dateKey]!;
        final dayExpensePaise = list
            .where((t) => _filterType == null ? t.transaction.type == 'expense' : true)
            .fold(0, (sum, t) => sum + t.transaction.amountPaise);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateKey.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${_filterType?.name == 'income' ? 'Received' : 'Spent'}: ₹${(dayExpensePaise / 100.0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...list.map((item) {
              return TransactionTile(
                transaction: item.transaction,
                category: item.category,
                onTap: () => _openAddTransactionSheet(item.transaction),
                onDelete: () => _confirmDelete(item.transaction),
              );
            }),
            const Divider(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyView(
    List<TransactionWithCategory> items,
    ThemeData theme,
  ) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Map<int, double> dayExpenses = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    for (final item in items) {
      if (_filterType == null ? item.transaction.type == 'expense' : true) {
        final d = item.transaction.date;
        if (d.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
          dayExpenses[d.weekday] =
              (dayExpenses[d.weekday] ?? 0) + item.transaction.amountRupees;
        }
      }
    }

    final maxVal = dayExpenses.values.fold(
      1.0,
      (max, val) => val > max ? val : max,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK\'S SPENDING TREND',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final dayNum = index + 1;
                    final spent = dayExpenses[dayNum] ?? 0.0;
                    final ratio = (spent / maxVal).clamp(0.05, 1.0);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 100 * ratio,
                          decoration: BoxDecoration(
                            color: spent > 0
                                ? AppColors.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weekdays[index],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDailyView(
            items.where((item) {
              final d = item.transaction.date;
              return d.isAfter(startOfWeek.subtract(const Duration(days: 1)));
            }).toList(),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyView(
    List<TransactionWithCategory> items,
    ThemeData theme,
  ) {
    final monthName = DateFormatter.formatMonthYear(_selectedMonth);
    final monthExpensePaise = items
        .where(
          (t) =>
              (_filterType == null ? t.transaction.type == 'expense' : true) &&
              t.transaction.date.month == _selectedMonth.month &&
              t.transaction.date.year == _selectedMonth.year,
        )
        .fold(0, (sum, t) => sum + t.transaction.amountPaise);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                  },
                ),
                Column(
                  children: [
                    Text(
                      monthName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      amount: monthExpensePaise / 100.0,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _filterType?.name == 'income' ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildDailyView(items, theme)),
      ],
    );
  }

  Widget _buildYearlyView(
    List<TransactionWithCategory> items,
    ThemeData theme,
  ) {
    final year = DateTime.now().year;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final monthNum = index + 1;
        final monthTotalPaise = items
            .where(
              (t) =>
                  (_filterType == null ? t.transaction.type == 'expense' : true) &&
                  t.transaction.date.month == monthNum &&
                  t.transaction.date.year == year,
            )
            .fold(0, (sum, t) => sum + t.transaction.amountPaise);

        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                months[index],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              AmountText(
                amount: monthTotalPaise / 100.0,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: monthTotalPaise > 0 
                      ? (_filterType?.name == 'income' ? AppColors.income : AppColors.expense) 
                      : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
