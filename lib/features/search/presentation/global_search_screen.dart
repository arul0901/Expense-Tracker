import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/search_result_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  String _currentQuery = '';
  SearchCategory _selectedCategory = SearchCategory.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentQuery = text.trim();
        });
      }
    });
  }

  void _clearSearch() {
    HapticFeedbackUtil.selectionClick();
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
    _searchFocusNode.requestFocus();
  }

  void _selectRecentQuery(String query) {
    HapticFeedbackUtil.selectionClick();
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    setState(() {
      _currentQuery = query;
    });
  }

  void _onResultTap(SearchResultModel result) {
    HapticFeedbackUtil.lightImpact();
    if (_currentQuery.isNotEmpty) {
      ref.read(searchRepositoryProvider).addRecentSearch(_currentQuery);
      ref.invalidate(recentSearchesProvider);
    }
    context.push(result.deepLinkRoute);
  }

  Map<SearchCategory, List<SearchResultModel>> _groupResults(List<SearchResultModel> items) {
    final Map<SearchCategory, List<SearchResultModel>> map = {};
    for (final item in items) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final recentSearchesAsync = ref.watch(recentSearchesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 46,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search food, Ooty, Rahul, ₹500...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                ref.read(searchRepositoryProvider).addRecentSearch(val.trim());
                ref.invalidate(recentSearchesProvider);
              }
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Scroll View
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: SearchCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    label: Text(cat.label),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedbackUtil.selectionClick();
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: _currentQuery.isEmpty
                ? _buildInitialState(theme, recentSearchesAsync)
                : _buildSearchResultsState(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(ThemeData theme, AsyncValue<List<String>> recentSearchesAsync) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        recentSearchesAsync.when(
          data: (recentList) {
            if (recentList.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT SEARCHES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        HapticFeedbackUtil.selectionClick();
                        await ref.read(searchRepositoryProvider).clearRecentSearches();
                        ref.invalidate(recentSearchesProvider);
                      },
                      child: const Text('Clear all', style: TextStyle(fontSize: 12, color: AppColors.expense)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentList.map((query) {
                    return ActionChip(
                      avatar: const Icon(Icons.history, size: 14),
                      label: Text(query),
                      onPressed: () => _selectRecentQuery(query),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        Text(
          'EXPLORE PROFIN',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        _buildCategoryQuickCard(
          theme,
          title: 'Transactions & Expenses',
          subtitle: 'Search notes, payments, categories & amounts',
          icon: Icons.receipt_long_outlined,
          color: AppColors.income,
          onTap: () => _selectRecentQuery('Food'),
        ),
        _buildCategoryQuickCard(
          theme,
          title: 'Rooms & Shared Workspaces',
          subtitle: 'Find Ooty trip, flatmates, members & settlements',
          icon: Icons.groups_outlined,
          color: AppColors.primary,
          onTap: () => _selectRecentQuery('Ooty'),
        ),
        _buildCategoryQuickCard(
          theme,
          title: 'Financial Reminders',
          subtitle: 'Track upcoming bill payments & subscriptions',
          icon: Icons.notifications_active_outlined,
          color: Colors.orange,
          onTap: () => _selectRecentQuery('EMI'),
        ),
        _buildCategoryQuickCard(
          theme,
          title: 'Events & Tasks',
          subtitle: 'Find assigned tasks and planned trip events',
          icon: Icons.task_alt_outlined,
          color: AppColors.primary,
          onTap: () => _selectRecentQuery('Rahul'),
        ),
      ],
    );
  }

  Widget _buildCategoryQuickCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildSearchResultsState(ThemeData theme) {
    final searchAsync = ref.watch(searchResultsProvider(
      SearchParams(query: _currentQuery, category: _selectedCategory),
    ));

    return searchAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No matches for "$_currentQuery"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try checking for typos, using broader keywords, or searching by exact amount (e.g. ₹500).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final grouped = _groupResults(results);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: grouped.entries.map((group) {
            final category = group.key;
            final items = group.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(category.icon, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        category.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.map((item) => _buildResultTile(theme, item)),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching ProFin Cloud...', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.expense),
              const SizedBox(height: 12),
              const Text('Couldn\'t complete search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Please check your network connection and try again. ($err)', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(searchResultsProvider),
                child: const Text('Retry Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(ThemeData theme, SearchResultModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        onTap: () => _onResultTap(item),
        leading: CircleAvatar(
          backgroundColor: item.iconColor.withValues(alpha: 0.15),
          child: Icon(item.icon, color: item.iconColor, size: 20),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.subtitle, style: theme.textTheme.bodySmall),
            if (item.contextInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                item.contextInfo!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.amountRupees != null)
              AmountText(
                amount: item.amountRupees!,
                isIncome: item.amountType == 'income',
                showSign: item.amountType == 'income' || item.amountType == 'expense',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
