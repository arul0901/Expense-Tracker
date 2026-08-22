import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/skeleton_loader.dart';
import 'room_analytics_view.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics & Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search ProFin',
            onPressed: () => context.push('/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Personal Analytics'),
            Tab(icon: Icon(Icons.groups_outlined, size: 20), text: 'Room Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalAnalytics(context),
          const RoomAnalyticsView(),
        ],
      ),
    );
  }

  Widget _buildPersonalAnalytics(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final totalIncome = ref.watch(totalIncomeProvider);
    final totalExpense = ref.watch(totalExpenseProvider);
    final theme = Theme.of(context);

    return transactionsAsync.when(
      data: (transactions) {
        final expenseTransactions = transactions.where((t) => t.transaction.type == 'expense').toList();

        if (expenseTransactions.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.bar_chart_outlined,
            title: 'No Data for Analytics',
            description: 'Record your expenses to generate financial insights and category breakdown charts.',
          );
        }

        // Category expense rollup
        final Map<String, double> categoryTotals = {};
        final Map<String, String> categoryNames = {};
        final Map<String, int> categoryColors = {};

        for (final item in expenseTransactions) {
          final catId = item.category.id;
          final amount = item.transaction.amountRupees;

          categoryTotals[catId] = (categoryTotals[catId] ?? 0) + amount;
          categoryNames[catId] = item.category.name;
          categoryColors[catId] = item.category.color;
        }

        // Top spending category
        String? topCatId;
        double maxCatSpend = 0;
        categoryTotals.forEach((catId, total) {
          if (total > maxCatSpend) {
            maxCatSpend = total;
            topCatId = catId;
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deterministic Financial Insights Card
              const SectionHeader(title: 'Calculated Financial Insights'),
              AppCard(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                borderColor: AppColors.primaryLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outlined, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text('Key Spending Highlights', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topCatId != null) ...[
                      Text(
                        '• You spent most on "${categoryNames[topCatId]}" (₹${maxCatSpend.toStringAsFixed(0)}), accounting for ${((maxCatSpend / (totalExpense > 0 ? totalExpense : 1)) * 100).toInt()}% of overall expenses.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      '• Net Savings Ratio: ${totalIncome > 0 ? (((totalIncome - totalExpense) / totalIncome) * 100).toInt() : 0}% of your total income retained.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category Spending Breakdown Pie Chart
              const SectionHeader(title: 'Where The Money Went'),
              AppCard(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: categoryTotals.entries.map((e) {
                            final percentage = (e.value / (totalExpense > 0 ? totalExpense : 1)) * 100;
                            return PieChartSectionData(
                              color: Color(categoryColors[e.key] ?? 0xFF4F46E5),
                              value: e.value,
                              title: '${percentage.toInt()}%',
                              radius: 50,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: categoryTotals.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(categoryColors[e.key] ?? 0xFF4F46E5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(categoryNames[e.key] ?? 'Category', style: theme.textTheme.bodyMedium)),
                              AmountText(amount: e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Income vs Expense Comparison Bar Widget
              const SectionHeader(title: 'Income vs Expense Comparison'),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Income', style: TextStyle(fontSize: 12, color: AppColors.income, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            AmountText(amount: totalIncome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Expenses', style: TextStyle(fontSize: 12, color: AppColors.expense, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            AmountText(amount: totalExpense, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => SkeletonLoader.tile(count: 4),
      error: (e, s) => Center(child: Text('Error loading analytics: $e')),
    );
  }
}
