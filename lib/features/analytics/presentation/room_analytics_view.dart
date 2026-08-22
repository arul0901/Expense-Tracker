import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/category_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/settlement_engine.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/room_repository.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/skeleton_loader.dart';

class RoomAnalyticsView extends ConsumerStatefulWidget {
  final String? initialRoomId;

  const RoomAnalyticsView({
    super.key,
    this.initialRoomId,
  });

  @override
  ConsumerState<RoomAnalyticsView> createState() => _RoomAnalyticsViewState();
}

class _RoomAnalyticsViewState extends ConsumerState<RoomAnalyticsView> {
  String? _selectedRoomId;
  String _timeFilter = 'All Time'; // 'Today', 'This Week', 'This Month', 'All Time'

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId;
  }

  DateTime? _getStartDate() {
    final now = DateTime.now();
    if (_timeFilter == 'Today') {
      return DateTime(now.year, now.month, now.day);
    } else if (_timeFilter == 'This Week') {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    } else if (_timeFilter == 'This Month') {
      return DateTime(now.year, now.month, 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return roomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.meeting_room_outlined,
            title: 'No Rooms Found',
            description: 'Create or join a room first to view room spending analytics and member insights.',
          );
        }

        // Set default selected room if not set or invalid
        final activeRoomId = (_selectedRoomId != null && rooms.any((r) => r.room.id == _selectedRoomId))
            ? _selectedRoomId!
            : rooms.first.room.id;

        final selectedRoomDetails = rooms.firstWhere((r) => r.room.id == activeRoomId);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Room Selector & Time Filter
              _buildHeaderControls(context, rooms, activeRoomId),
              const SizedBox(height: 16),

              // 2. Fetch room expenses & balances
              _buildRoomAnalyticsContent(context, selectedRoomDetails),
            ],
          ),
        );
      },
      loading: () => SkeletonLoader.tile(count: 4),
      error: (e, s) => Center(child: Text('Error loading rooms: $e')),
    );
  }

  Widget _buildHeaderControls(BuildContext context, List<RoomWithDetails> rooms, String activeRoomId) {
    final theme = Theme.of(context);
    final options = ['Today', 'This Week', 'This Month', 'All Time'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room Dropdown Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeRoomId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: rooms.map((r) {
                      return DropdownMenuItem(
                        value: r.room.id,
                        child: Text(
                          r.room.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        HapticFeedbackUtil.selectionClick();
                        setState(() {
                          _selectedRoomId = newId;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Time Period Filter Chips
        Row(
          children: options.map((opt) {
            final isSelected = _timeFilter == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtil.selectionClick();
                  setState(() => _timeFilter = opt);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _resolveCategoryName(String? catId, List<CategoryModel> categories) {
    if (catId == null || catId.trim().isEmpty) return 'General / Food';
    final trimmedId = catId.trim();
    for (final c in categories) {
      if (c.id == trimmedId) return c.name;
    }
    if (!trimmedId.contains('-')) return trimmedId;
    return 'Food & Dining';
  }

  Widget _buildRoomAnalyticsContent(BuildContext context, RoomWithDetails roomDetails) {
    final expensesAsync = ref.watch(roomExpensesProvider(roomDetails.room.id));
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final categoriesList = categoriesAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <CategoryModel>[],
    );
    final startDate = _getStartDate();

    return expensesAsync.when(
      data: (allExpensesWithPayer) {
        // Filter expenses by date
        final filteredList = allExpensesWithPayer.where((e) {
          if (startDate == null) return true;
          return e.expense.date.isAfter(startDate) || e.expense.date.isAtSameMomentAs(startDate);
        }).toList();

        if (filteredList.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: EmptyStateWidget(
              icon: Icons.analytics_outlined,
              title: 'No Expenses in Selected Period',
              description: 'Add room expenses for this time period to see spending heatmaps and category breakdowns.',
            ),
          );
        }

        // Calculate totals
        double totalRoomSpend = 0;
        final Map<String, double> spendedByMap = {};
        final Map<String, double> categorySpendsMap = {};
        final Map<DateTime, double> dailyHeatmapMap = {};

        for (final item in filteredList) {
          final exp = item.expense;
          final amount = exp.amountRupees;
          totalRoomSpend += amount;

          // Spended by (paid upfront)
          final payerName = exp.paidByMemberName.trim();
          spendedByMap[payerName] = (spendedByMap[payerName] ?? 0) + amount;

          // Category spend
          final categoryName = _resolveCategoryName(exp.categoryId, categoriesList);
          categorySpendsMap[categoryName] = (categorySpendsMap[categoryName] ?? 0) + amount;

          // Heatmap by day (yyyy-MM-dd)
          final dayKey = DateTime(exp.date.year, exp.date.month, exp.date.day);
          dailyHeatmapMap[dayKey] = (dailyHeatmapMap[dayKey] ?? 0) + amount;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 1. Recommended Actions & Smart Insights
            _buildRecommendedActionsSection(context, roomDetails, filteredList, totalRoomSpend, spendedByMap, categorySpendsMap),
            const SizedBox(height: 20),

            // 💳 2. Spended By Breakdown
            _buildSpendedBySection(context, roomDetails, spendedByMap, totalRoomSpend),
            const SizedBox(height: 20),

            // 🍔 3. Category Consumption
            _buildCategoryConsumptionSection(context, categorySpendsMap, totalRoomSpend),
            const SizedBox(height: 20),

            // 🔥 4. Payment / Spending Heatmap
            _buildSpendingHeatmapSection(context, dailyHeatmapMap, totalRoomSpend),
          ],
        );
      },
      loading: () => SkeletonLoader.tile(count: 4),
      error: (e, s) => Center(child: Text('Error loading room analytics: $e')),
    );
  }

  // --- 1. RECOMMENDED ACTIONS SECTION ---
  Widget _buildRecommendedActionsSection(
    BuildContext context,
    RoomWithDetails roomDetails,
    List<ExpenseWithPayerAndSplits> expenses,
    double totalRoomSpend,
    Map<String, double> spendedByMap,
    Map<String, double> categorySpendsMap,
  ) {
    final roomRepo = ref.read(roomRepositoryProvider);

    return FutureBuilder<List<MemberNetBalance>>(
      future: roomRepo.calculateRoomBalances(roomDetails.room.id, startDate: _getStartDate()),
      builder: (context, snapshot) {
        final balances = snapshot.data ?? [];
        final suggestions = SettlementEngine.calculateMinimumSettlements(balances);

        // Generate dynamic smart recommendations
        final List<Widget> actionCards = [];

        // Action 1: Pending Settlement Recommendations
        if (suggestions.isNotEmpty) {
          final topS = suggestions.first;
          actionCards.add(
            _buildActionTile(
              context,
              icon: Icons.payments_outlined,
              iconColor: AppColors.expense,
              title: 'Pending Settlement',
              description: '${topS.fromMemberName} owes ₹${(topS.amountPaise / 100).toStringAsFixed(2)} to ${topS.toMemberName}. Settle up to clear group balance.',
              actionLabel: 'Settle Now',
              onPressed: () {
                HapticFeedbackUtil.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Go to Room Workspace > Balances tab to record settlement between ${topS.fromMemberName} and ${topS.toMemberName}.')),
                );
              },
            ),
          );
        }

        // Action 2: Top Spender Burden Insight
        if (spendedByMap.isNotEmpty) {
          final sortedSpenders = spendedByMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final topSpender = sortedSpenders.first;
          final pct = totalRoomSpend > 0 ? ((topSpender.value / totalRoomSpend) * 100).toInt() : 0;

          if (pct >= 50 && roomDetails.members.length > 1) {
            actionCards.add(
              _buildActionTile(
                context,
                icon: Icons.balance_outlined,
                iconColor: AppColors.income,
                title: 'Fair Group Spending Prompt',
                description: '${topSpender.key} funded $pct% (₹${topSpender.value.toStringAsFixed(0)}) of room expenses upfront. Suggest other members pay next!',
                actionLabel: 'Remind Room',
                onPressed: () {
                  HapticFeedbackUtil.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${topSpender.key} has funded the majority of group costs.')),
                  );
                },
              ),
            );
          }
        }

        // Action 3: Top Category Consumption Rule
        if (categorySpendsMap.isNotEmpty) {
          final topCat = (categorySpendsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
          final catPct = totalRoomSpend > 0 ? ((topCat.value / totalRoomSpend) * 100).toInt() : 0;
          if (catPct >= 40) {
            actionCards.add(
              _buildActionTile(
                context,
                icon: Icons.pie_chart_outline,
                iconColor: AppColors.primary,
                title: 'Category Budget Alert',
                description: '"${topCat.key}" is consuming $catPct% (₹${topCat.value.toStringAsFixed(0)}) of room budget. Setting a category cap can save funds.',
                actionLabel: 'View Details',
                onPressed: () {},
              ),
            );
          }
        }

        if (actionCards.isEmpty) {
          actionCards.add(
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.income),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All group balances are clear and room spending is evenly distributed!',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'RECOMMENDED ACTIONS & INSIGHTS'),
            ...actionCards,
          ],
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.15),
            radius: 20,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SPENDED BY BREAKDOWN SECTION ---
  Widget _buildSpendedBySection(
    BuildContext context,
    RoomWithDetails roomDetails,
    Map<String, double> spendedByMap,
    double totalRoomSpend,
  ) {
    final theme = Theme.of(context);

    // Make sure all room members are included in the list
    final List<_MemberSpendInfo> memberSpends = roomDetails.members.map((m) {
      final spent = spendedByMap[m.name.trim()] ?? 0.0;
      final pct = totalRoomSpend > 0 ? (spent / totalRoomSpend) * 100 : 0.0;
      return _MemberSpendInfo(name: m.name, amount: spent, percentage: pct);
    }).toList();

    memberSpends.sort((a, b) => b.amount.compareTo(a.amount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'SPENDED BY (MEMBER CONTRIBUTIONS)'),
            Text(
              'Total: ₹${totalRoomSpend.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
        AppCard(
          child: Column(
            children: [
              // Member Bar Chart Visualization
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (memberSpends.fold<double>(0, (max, m) => m.amount > max ? m.amount : max) * 1.2).clamp(10, double.infinity),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < memberSpends.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  memberSpends[idx].name,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: memberSpends.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.amount,
                            color: AppColors.primary,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Detailed Member Contribution Cards
              ...memberSpends.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                AmountText(amount: m.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (m.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${m.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. CATEGORY CONSUMPTION SECTION ---
  Widget _buildCategoryConsumptionSection(
    BuildContext context,
    Map<String, double> categorySpendsMap,
    double totalRoomSpend,
  ) {
    final theme = Theme.of(context);
    final sortedCategories = categorySpendsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> categoryColors = [
      AppColors.primary,
      AppColors.income,
      AppColors.expense,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.blue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CATEGORY CONSUMPTION (MONEY DRAIN)'),
        AppCard(
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 38,
                    sections: sortedCategories.asMap().entries.map((e) {
                      final pct = totalRoomSpend > 0 ? (e.value.value / totalRoomSpend) * 100 : 0.0;
                      final color = categoryColors[e.key % categoryColors.length];
                      return PieChartSectionData(
                        color: color,
                        value: e.value.value,
                        title: '${pct.toInt()}%',
                        radius: 45,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...sortedCategories.asMap().entries.map((e) {
                final catName = e.value.key;
                final amount = e.value.value;
                final pct = totalRoomSpend > 0 ? (amount / totalRoomSpend) * 100 : 0.0;
                final color = categoryColors[e.key % categoryColors.length];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(catName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      AmountText(amount: amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. PAYMENT / SPENDING HEATMAP SECTION ---
  Widget _buildSpendingHeatmapSection(
    BuildContext context,
    Map<DateTime, double> dailyHeatmapMap,
    double totalRoomSpend,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Generate last 14 days activity intensity cells
    final List<DateTime> days = List.generate(14, (idx) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - idx));
    });

    final maxDaySpend = dailyHeatmapMap.values.fold<double>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'PAYMENT / SPENDING HEATMAP (LAST 14 DAYS)'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intensity grid showing daily room expense activity.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, idx) {
                  final day = days[idx];
                  final daySpend = dailyHeatmapMap[day] ?? 0.0;

                  // Compute intensity level (0 to 1.0)
                  final intensity = maxDaySpend > 0 ? (daySpend / maxDaySpend) : 0.0;
                  final color = daySpend == 0
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppColors.primary.withValues(alpha: (0.2 + (intensity * 0.8)).clamp(0.2, 1.0));

                  return Tooltip(
                    message: '${DateFormat('dd MMM (EEE)').format(day)}: ₹${daySpend.toStringAsFixed(2)}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: daySpend > 0 ? AppColors.primary : theme.dividerColor,
                          width: daySpend > 0 ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('dd').format(day),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: daySpend > 0 && intensity > 0.5 ? Colors.white : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('No Spend ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey)),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(' High Spend', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberSpendInfo {
  final String name;
  final double amount;
  final double percentage;

  _MemberSpendInfo({
    required this.name,
    required this.amount,
    required this.percentage,
  });
}
