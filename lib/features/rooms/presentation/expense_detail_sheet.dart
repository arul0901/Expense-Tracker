import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/room_member_model.dart';
import '../../../core/models/room_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/room_repository.dart';

class ExpenseDetailSheet extends ConsumerWidget {
  final ExpenseWithPayerAndSplits expenseDetails;
  final List<RoomMemberModel> members;
  final RoomModel room;
  final VoidCallback? onUpdated;

  const ExpenseDetailSheet({
    super.key,
    required this.expenseDetails,
    required this.members,
    required this.room,
    this.onUpdated,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close & Delete Expense?'),
        content: Text('Delete "${expenseDetails.expense.description}"? Balances will be recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('Close / Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.heavyImpact();
      final repo = ref.read(roomRepositoryProvider);
      await repo.deleteRoomExpense(expenseDetails.expense.id);
      if (context.mounted) {
        Navigator.pop(context);
        onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Expense "${expenseDetails.expense.description}" deleted')),
              ],
            ),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _editSplits(BuildContext context, WidgetRef ref) async {
    final currentSplitMembers = expenseDetails.splits.map((s) => s.memberName).toSet();
    final selectedMembers = Set<String>.from(currentSplitMembers);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.group_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Edit Split Members'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add or remove members from this expense split:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              ...members.map((m) {
                final isIncluded = selectedMembers.contains(m.name);
                return CheckboxListTile(
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  value: isIncluded,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selectedMembers.add(m.name);
                      } else {
                        if (selectedMembers.length > 1) {
                          selectedMembers.remove(m.name);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('At least one member must remain in the split.')),
                          );
                        }
                      }
                    });
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Save Split'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && context.mounted) {
      HapticFeedbackUtil.heavyImpact();
      final repo = ref.read(roomRepositoryProvider);
      await repo.updateRoomExpenseSplits(
        expenseId: expenseDetails.expense.id,
        selectedMemberNames: selectedMembers.toList(),
      );
      if (context.mounted) {
        Navigator.pop(context);
        onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Expense split members updated successfully!'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    }
  }

  Future<void> _remindUnpaid(BuildContext context, WidgetRef ref, RoomMemberModel member, int unpaidPaise) async {
    HapticFeedbackUtil.mediumImpact();
    final notif = ref.read(notificationServiceProvider);
    final rupees = (unpaidPaise / 100.0).toStringAsFixed(0);
    await notif.showNotification(
      id: member.name.hashCode,
      title: '🔔 Payment Reminder Sent',
      body: 'Reminder sent to ${member.name} for ₹$rupees pending in ${room.name}.',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Friendly payment reminder sent to ${member.name}!'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(imageUrl.split(',').last),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expense = expenseDetails.expense;
    final totalRupees = expense.amountRupees;
    final splits = expenseDetails.splits;

    final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
    final isInitiator = expenseDetails.payer.isCurrentUser ||
        expense.paidByUserId == currentUser?.id ||
        members.any((m) => m.name == expense.paidByMemberName && (m.isCurrentUser || m.userId == currentUser?.id));
    final isOwnerOrAdmin = members.any((m) => (m.isCurrentUser || m.userId == currentUser?.id) && (m.role == 'Owner' || m.role == 'Admin'));
    final canManageExpense = isInitiator || isOwnerOrAdmin;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expense Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          Text(expense.description, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('₹${totalRupees.toStringAsFixed(2)} • Paid by ${expenseDetails.payer.name}', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.income, fontWeight: FontWeight.bold)),
          if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _showFullImageDialog(context, expense.receiptUrl!),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: expense.receiptUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(expense.receiptUrl!.split(',').last),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                expense.receiptUrl!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receipt Photo Attached 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          Text('Tap to view full screen & zoom bill', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.fullscreen, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('MEMBER SHARES', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...splits.map((s) {
            final member = members.firstWhere((m) => m.name == s.memberName, orElse: () => RoomMemberModel(id: s.id, roomId: room.id, name: s.memberName, isCurrentUser: false, role: 'Member', avatarColor: 0xFF3B82F6, isActive: true, joinedAt: DateTime.now()));
            final memberRupees = s.amountRupees;
            final isPayer = member.name == expense.paidByMemberName;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(member.avatarColor),
                    child: Text(member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : 'M', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (isPayer) Text('Paid full amount', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.income)),
                      ],
                    ),
                  ),
                  Text('₹${memberRupees.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (!isPayer) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (!canManageExpense) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Only ${expenseDetails.payer.name} (who initiated this expense) can mark shares as paid.'),
                              backgroundColor: AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        HapticFeedbackUtil.mediumImpact();
                        final repo = ref.read(roomRepositoryProvider);
                        final newPaidState = !s.isPaid;
                        await repo.toggleSplitPaymentStatus(
                          splitId: s.id,
                          isPaid: newPaidState,
                        );
                        if (context.mounted) {
                          onUpdated?.call();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newPaidState
                                    ? '✓ Marked ${member.name}\'s share (₹${memberRupees.toStringAsFixed(0)}) as Paid!'
                                    : 'Marked ${member.name}\'s share as Unpaid',
                              ),
                              backgroundColor: newPaidState ? AppColors.income : AppColors.expense,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: s.isPaid ? AppColors.incomeLight : AppColors.expenseLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: s.isPaid ? AppColors.income : AppColors.expense,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 14,
                              color: s.isPaid ? AppColors.income : AppColors.expense,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.isPaid ? 'Paid' : 'Mark Paid',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: s.isPaid ? AppColors.income : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!s.isPaid) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.notifications_active_outlined,
                          size: 20,
                          color: canManageExpense ? Colors.orange : Colors.grey,
                        ),
                        tooltip: canManageExpense ? 'Remind ${member.name}' : 'Only initiator can send reminders',
                        onPressed: () {
                          if (!canManageExpense) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Only ${expenseDetails.payer.name} (who initiated this expense) can send reminders.'),
                                backgroundColor: AppColors.warning,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _remindUnpaid(context, ref, member, s.amountPaise);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          if (canManageExpense)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editSplits(context, ref),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                    label: const Text('Edit Split Members'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                    label: const Text('Close / Delete', style: TextStyle(color: AppColors.expense)),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only ${expense.paidByMemberName} (who initiated this expense) can edit splits or remove/add members.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
