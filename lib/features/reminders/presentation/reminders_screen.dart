import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/reminder_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/reminder_repository.dart';

import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/reminder_tile.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/skeleton_loader.dart';
import 'add_edit_reminder_sheet.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  void _openAddReminderSheet([ReminderModel? item]) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditReminderSheet(reminderToEdit: item),
    );
  }

  Future<void> _markAsPaid(ReminderWithCategory item) async {
    final reminder = item.reminder;
    final amountRupees = reminder.amountRupees;
    bool createTransaction = true;

    final isIncome = reminder.frequency == 'monthly' && reminder.title.toLowerCase().contains('salary');
    final typeLabel = isIncome ? 'Income' : 'Expense';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Mark "${reminder.title}" as Paid?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ₹${amountRupees.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: createTransaction,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Add to $typeLabel transactions automatically?'),
                    subtitle: const Text('Updates balance and dashboard instantly'),
                    onChanged: (val) {
                      setModalState(() {
                        createTransaction = val ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    HapticFeedbackUtil.heavyImpact();
    final reminderRepo = ref.read(reminderRepositoryProvider);

    await reminderRepo.updateStatus(reminder.id, true);

    if (createTransaction) {
      final txRepo = ref.read(transactionRepositoryProvider);
      String? categoryId = reminder.categoryId;

      if (categoryId == null) {
        final categories = isIncome
            ? await ref.read(categoryRepositoryProvider).watchCategoriesByType('income').first
            : await ref.read(categoryRepositoryProvider).watchCategoriesByType('expense').first;
        if (categories.isNotEmpty) {
          categoryId = categories.first.id;
        }
      }

      if (categoryId != null) {
        await txRepo.insertTransaction(
          type: isIncome ? 'income' : 'expense',
          amountPaise: reminder.amountPaise,
          categoryId: categoryId,
          date: DateTime.now(),
          note: 'Auto-generated from reminder: ${reminder.title}',
          paymentMethod: 'upi',
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(createTransaction
              ? 'Reminder marked paid & transaction created!'
              : 'Reminder marked completed!'),
        ),
      );
    }
  }

  Future<void> _deleteReminder(ReminderWithCategory item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${item.reminder.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.mediumImpact();
      await ref.read(reminderRepositoryProvider).deleteReminder(item.reminder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Financial Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Reminder',
            onPressed: () => _openAddReminderSheet(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Due Today'),
            Tab(text: 'Overdue'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: remindersAsync.when(
        data: (allList) {
          final upcomingList = <ReminderWithCategory>[];
          final dueTodayList = <ReminderWithCategory>[];
          final overdueList = <ReminderWithCategory>[];
          final completedList = <ReminderWithCategory>[];

          for (final item in allList) {
            final r = item.reminder;
            if (r.isCompleted) {
              completedList.add(item);
              continue;
            }

            final dueDay = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);

            if (dueDay.isAtSameMomentAs(today)) {
              dueTodayList.add(item);
            } else if (dueDay.isBefore(today)) {
              overdueList.add(item);
            } else {
              upcomingList.add(item);
            }
          }

          Widget buildList(List<ReminderWithCategory> items, String sectionTitle, String emptyTitle, String emptyDesc) {
            if (items.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.notifications_none,
                title: emptyTitle,
                description: emptyDesc,
                actionLabel: 'Create Reminder',
                onAction: () => _openAddReminderSheet(),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SectionHeader(title: sectionTitle);
                }
                final item = items[index - 1];
                return ReminderTile(
                  reminder: item.reminder,
                  category: item.category,
                  onTap: () => _openAddReminderSheet(item.reminder),
                  onMarkPaid: () => _markAsPaid(item),
                  onDelete: () => _deleteReminder(item),
                );
              },
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              buildList(upcomingList, 'Scheduled Reminders', 'No Upcoming Reminders', 'All your upcoming financial events will be listed here.'),
              buildList(dueTodayList, 'Due Today', 'No Bills Due Today', 'Great! You have no financial reminders due today.'),
              buildList(overdueList, 'Action Required (Overdue)', 'No Overdue Bills', 'Awesome! All your payments are up to date.'),
              buildList(completedList, 'Past Reminders', 'No Completed Reminders', 'Completed financial reminders will appear here.'),
            ],
          );
        },
        loading: () => SkeletonLoader.tile(count: 4),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: EmptyStateWidget(
              icon: Icons.wifi_off_rounded,
              title: 'Sync Warning',
              description: 'Unable to connect to real-time sync. Tap to reload financial reminders.',
              actionLabel: 'Retry Sync',
              onAction: () => ref.invalidate(allRemindersProvider),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddReminderSheet(),
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}
