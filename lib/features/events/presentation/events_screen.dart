import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/sign_in_required_dialog.dart';
import '../../../widgets/skeleton_loader.dart';
import 'add_edit_event_sheet.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  void _openAddEvent(BuildContext context, [EventModel? item]) {
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditEventSheet(eventToEdit: item),
    );
  }

  void _openAddRoomModal(BuildContext context, WidgetRef ref) {
    if (isAnonymousUser()) {
      showSignInRequiredDialog(
        context,
        message: 'Please sign in first to create a room.',
      );
      return;
    }
    HapticFeedbackUtil.selectionClick();
    final nameController = TextEditingController();
    final member1Controller = TextEditingController(text: 'Rahul');
    final member2Controller = TextEditingController(text: 'Karthik');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g. Trip Room, Flat Mates, Dinner',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: member1Controller,
              decoration: const InputDecoration(
                labelText: 'Member 1 Name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: member2Controller,
              decoration: const InputDecoration(
                labelText: 'Member 2 Name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final roomName = nameController.text.trim();
              if (roomName.isEmpty) return;
              final members = [
                member1Controller.text.trim(),
                member2Controller.text.trim(),
              ].where((n) => n.isNotEmpty).toList();

              final roomRepo = ref.read(roomRepositoryProvider);
              await roomRepo.createRoom(
                name: roomName,
                memberNames: members,
              );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create Room'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(activeEventsWithStatsProvider);
    final roomsAsync = ref.watch(allRoomsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Events & Group Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Event',
            onPressed: () => _openAddEvent(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Events Section
            SectionHeader(
              title: 'Active Events Workspace',
              actionLabel: '+ Create Event',
              onAction: () => _openAddEvent(context),
            ),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.event_note_outlined,
                    title: 'No Active Events',
                    description: 'Plan your trip, wedding, or vacation budget with financial tracking.',
                    actionLabel: 'Create Event',
                    onAction: () => _openAddEvent(context),
                  );
                }

                return Column(
                  children: events.map((item) {
                    final ev = item.event;
                    final totalSpent = item.totalSpentPaise / 100.0;
                    final budget = ev.budgetRupees;
                    final ratio = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ev.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormatter.formatShortDate(ev.startDate)}${ev.endDate != null ? " - ${DateFormatter.formatShortDate(ev.endDate!)}" : ""}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              AmountText(
                                amount: totalSpent,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          if (budget > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ratio >= 0.9 ? AppColors.expense : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${(ratio * 100).toInt()}% of budget spent', style: theme.textTheme.bodySmall),
                                Text('Budget: ₹${budget.toStringAsFixed(0)}', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => SkeletonLoader.bar(height: 8),
              error: (e, s) => Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(activeEventsWithStatsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tap to reload events'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Expense Splitting Rooms Section
            SectionHeader(
              title: 'Expense Splitting Rooms',
              actionLabel: '+ Create Room',
              onAction: () => _openAddRoomModal(context, ref),
            ),
            roomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('No group rooms created yet. Create a room to split expenses with friends.'),
                        ),
                        TextButton(
                          onPressed: () => _openAddRoomModal(context, ref),
                          child: const Text('Create Room'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: rooms.map((r) {
                    final memberNames = r.members.map((m) => m.isCurrentUser ? 'You' : m.name).join(', ');
                    final totalPaise = r.totalRoomExpensesPaise;

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      onTap: () {
                        if (isAnonymousUser()) {
                          showSignInRequiredDialog(
                            context,
                            message: 'Please sign in first to open room workspaces.',
                          );
                          return;
                        }
                        HapticFeedbackUtil.selectionClick();
                        context.push('/rooms/${r.room.id}');
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                            child: const Icon(Icons.group_outlined, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(memberNames, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AmountText(
                                amount: totalPaise / 100.0,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text('Group Spent', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => SkeletonLoader.tile(count: 3),
              error: (e, s) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
