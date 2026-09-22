import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/member_financial_summary.dart';
import '../../../core/models/room_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';

class MemberDetailSheet extends ConsumerStatefulWidget {
  final MemberFinancialSummary summary;
  final RoomModel room;
  final VoidCallback? onUpdated;

  const MemberDetailSheet({
    super.key,
    required this.summary,
    required this.room,
    this.onUpdated,
  });

  @override
  ConsumerState<MemberDetailSheet> createState() => _MemberDetailSheetState();
}

class _MemberDetailSheetState extends ConsumerState<MemberDetailSheet> {
  bool _isIncludingInExpenses = false;

  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    HapticFeedbackUtil.mediumImpact();
    final notif = ref.read(notificationServiceProvider);
    final member = widget.summary.member;
    final rupees = widget.summary.oweRupees.toStringAsFixed(0);
    await notif.showNotification(
      id: member.name.hashCode,
      title: '🔔 Payment Reminder Sent',
      body: 'Reminder sent to ${member.name} for ₹$rupees pending in ${widget.room.name}.',
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

  Color _getStatusColor(MemberDueStatus status) {
    switch (status) {
      case MemberDueStatus.paid:
        return AppColors.income;
      case MemberDueStatus.partiallyPaid:
        return Colors.orange;
      case MemberDueStatus.due:
        return AppColors.expense;
      case MemberDueStatus.receivable:
        return Colors.blue;
      case MemberDueStatus.unassigned:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = widget.summary.member;
    final expensesAsync = ref.watch(roomExpensesProvider(widget.room.id));
    final statusColor = _getStatusColor(widget.summary.status);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Member Header Card
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(member.avatarColor),
                child: Text(
                  member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : 'M',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: member.role == 'Owner' ? Colors.amber.withValues(alpha: 0.2) : theme.dividerColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            member.role,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: member.role == 'Owner' ? Colors.amber.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${DateFormat('dd MMM yyyy').format(member.joinedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Due Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.summary.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Financial Summary Metrics Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Total Dues
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL DUES', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          AmountText(
                            amount: widget.summary.totalDuesRupees,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 36, width: 1, color: theme.dividerColor),
                    const SizedBox(width: 12),
                    // Total Paid
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL PAID', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          AmountText(
                            amount: widget.summary.totalPaidRupees,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.income),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Outstanding Owe / Net Balance Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.summary.isOwed
                              ? 'Group Owes Member'
                              : widget.summary.isOwes
                                  ? 'Member Owes Group'
                                  : 'Settled',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.summary.isOwes ? AppColors.expense : (widget.summary.isOwed ? AppColors.income : Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.summary.isSettled
                              ? 'Fully Settled (₹0.00)'
                              : widget.summary.isOwed
                                  ? '+₹${widget.summary.receivableRupees.toStringAsFixed(2)}'
                                  : '-₹${widget.summary.oweRupees.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: widget.summary.isSettled ? Colors.grey : (widget.summary.isOwed ? AppColors.income : AppColors.expense),
                          ),
                        ),
                      ],
                    ),

                    if (widget.summary.isOwes && !widget.summary.member.isCurrentUser)
                      ElevatedButton.icon(
                        onPressed: () {
                          _sendReminder(context, ref);
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 16),
                        label: const Text('Remind'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Expense History', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Expenses List for this member
          Expanded(
            child: expensesAsync.when(
              data: (expensesList) {
                final memberExpenses = expensesList.where((e) {
                  final isPayer = e.payer.name == member.name || e.expense.paidByMemberName == member.name;
                  final hasSplit = e.splits.any((s) => s.memberName == member.name);
                  return isPayer || hasSplit;
                }).toList();

                if (memberExpenses.isEmpty) {
                  return const Center(
                    child: Text('No expense transactions recorded for this member yet.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: memberExpenses.length,
                  itemBuilder: (context, index) {
                    final item = memberExpenses[index];
                    final exp = item.expense;
                    final isPayer = item.payer.name == member.name || exp.paidByMemberName == member.name;
                    final memberSplit = item.splits.firstWhere(
                      (s) => s.memberName == member.name,
                      orElse: () => item.splits.first,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isPayer ? AppColors.incomeLight : Colors.blue.shade50,
                          child: Icon(
                            isPayer ? Icons.north_east : Icons.south_west,
                            size: 18,
                            color: isPayer ? AppColors.income : Colors.blue,
                          ),
                        ),
                        title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isPayer
                              ? 'Paid total ₹${exp.amountRupees.toStringAsFixed(0)} • ${DateFormat('dd MMM').format(exp.date)}'
                              : 'Assigned share: ₹${memberSplit.amountRupees.toStringAsFixed(0)} • ${DateFormat('dd MMM').format(exp.date)}',
                        ),
                        trailing: Text(
                          isPayer ? '+₹${exp.amountRupees.toStringAsFixed(2)}' : '-₹${memberSplit.amountRupees.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPayer ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),

          const SizedBox(height: 12),
          expensesAsync.when(
            data: (expensesList) {
              final currentUserPaidExpenses = expensesList.where((e) => e.payer.isCurrentUser).toList();
              final hasCurrentUserPaid = currentUserPaidExpenses.isNotEmpty;
              final currentUserName = hasCurrentUserPaid ? currentUserPaidExpenses.first.payer.name : '';

              if (hasCurrentUserPaid && !member.isCurrentUser) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _isIncludingInExpenses
                        ? null
                        : () async {
                            setState(() => _isIncludingInExpenses = true);
                            try {
                              await ref.read(roomRepositoryProvider).addMemberToPastExpenses(
                                    roomId: widget.room.id,
                                    payerMemberName: currentUserName,
                                    newMemberName: member.name,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Member added to your past expenses'),
                                    backgroundColor: AppColors.income,
                                  ),
                                );
                                widget.onUpdated?.call();
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isIncludingInExpenses = false);
                            }
                          },
                    icon: _isIncludingInExpenses
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.group_add_outlined),
                    label: Text(_isIncludingInExpenses ? 'Including...' : 'Include in my past expenses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close Summary'),
          ),
        ],
      ),
    );
  }
}
