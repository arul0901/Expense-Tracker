import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/task_repository.dart';

class GlobalToDoScreen extends ConsumerStatefulWidget {
  const GlobalToDoScreen({super.key});

  @override
  ConsumerState<GlobalToDoScreen> createState() => _GlobalToDoScreenState();
}

class _GlobalToDoScreenState extends ConsumerState<GlobalToDoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSourceFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleTask(TaskWithMemberAndRoom taskItem) async {
    HapticFeedbackUtil.selectionClick();
    final repo = ref.read(taskRepositoryProvider);
    await repo.toggleTaskCompleted(taskItem.task.id);

    if (mounted) {
      final isDone = !taskItem.task.isCompleted;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDone ? '✓ Task marked as completed' : 'Task restored'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.toggleTaskCompleted(taskItem.task.id),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<TaskWithMemberAndRoom> _filterTasks(List<TaskWithMemberAndRoom> tasks, int tabIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var filtered = tasks;

    if (_selectedSourceFilter == 'Room') {
      filtered = filtered.where((t) => t.task.roomId != null).toList();
    } else if (_selectedSourceFilter == 'Personal') {
      filtered = filtered.where((t) => t.task.roomId == null).toList();
    }

    switch (tabIndex) {
      case 0:
        return filtered.where((t) {
          if (t.task.isCompleted) return false;
          if (t.task.dueDate == null) return false;
          final d = DateTime(t.task.dueDate!.year, t.task.dueDate!.month, t.task.dueDate!.day);
          return d.isAtSameMomentAs(today);
        }).toList();

      case 1:
        return filtered.where((t) {
          if (t.task.isCompleted) return false;
          if (t.task.dueDate == null) return true;
          final d = DateTime(t.task.dueDate!.year, t.task.dueDate!.month, t.task.dueDate!.day);
          return d.isAfter(today);
        }).toList();

      case 2:
        return filtered.where((t) {
          if (t.task.isCompleted) return false;
          if (t.task.dueDate == null) return false;
          final d = DateTime(t.task.dueDate!.year, t.task.dueDate!.month, t.task.dueDate!.day);
          return d.isBefore(today);
        }).toList();

      case 3:
        return filtered.where((t) => t.task.isCompleted).toList();

      case 4:
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(globalTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global To-Do List'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Overdue'),
            Tab(text: 'Completed'),
            Tab(text: 'All Tasks'),
          ],
        ),
      ),
      body: tasksAsync.when(
        data: (allTasks) {
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: ['All', 'Room', 'Personal'].map((source) {
                    final isSelected = source == _selectedSourceFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(source == 'All' ? 'All Tasks' : '$source Tasks'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedSourceFilter = source);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(5, (tabIdx) {
                    final items = _filterTasks(allTasks, tabIdx);

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              tabIdx == 3 ? 'NO COMPLETED TASKS YET' : 'YOU\'RE ALL CAUGHT UP',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tabIdx == 3 ? 'Completed tasks will be archived here' : 'No pending tasks match this filter',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final task = item.task;
                        final isCompleted = task.isCompleted;

                        Color priorityColor = Colors.transparent;
                        if (task.priority == 'Urgent') priorityColor = AppColors.expense;
                        if (task.priority == 'High') priorityColor = Colors.orange;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: (_) => _toggleTask(item),
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (item.room != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Color(item.room!.colorAccent).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.room!.name,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(item.room!.colorAccent)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (item.assignedMember != null) ...[
                                  Text('Assigned: ${item.assignedMember!.name}', style: theme.textTheme.bodySmall),
                                  const SizedBox(width: 6),
                                ],
                                if (task.dueDate != null) ...[
                                  Text(
                                    'Due: ${DateFormat('d MMM').format(task.dueDate!)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.income),
                                  ),
                                ],
                              ],
                            ),
                            trailing: task.priority == 'Urgent' || task.priority == 'High'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      task.priority.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Unable to sync tasks', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(globalTasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
