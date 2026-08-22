import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/member_financial_summary.dart';
import '../../../core/models/room_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/upi_payment_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';

class MemberDetailSheet extends ConsumerWidget {
  final MemberFinancialSummary summary;
  final RoomModel room;
  final VoidCallback? onUpdated;

  const MemberDetailSheet({
    super.key,
    required this.summary,
    required this.room,
    this.onUpdated,
  });

  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    HapticFeedbackUtil.mediumImpact();
    final notif = ref.read(notificationServiceProvider);
    final member = summary.member;
    final rupees = summary.oweRupees.toStringAsFixed(0);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final member = summary.member;
    final expensesAsync = ref.watch(roomExpensesProvider(room.id));
    final statusColor = _getStatusColor(summary.status);

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
                  summary.statusLabel,
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
                            amount: summary.totalDuesRupees,
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
                            amount: summary.totalPaidRupees,
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
                          summary.isOwed
                              ? 'Group Owes Member'
                              : summary.isOwes
                                  ? 'Member Owes Group'
                                  : 'Settled',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: summary.isOwes ? AppColors.expense : (summary.isOwed ? AppColors.income : Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.isSettled
                              ? 'Fully Settled (₹0.00)'
                              : summary.isOwed
                                  ? '+₹${summary.receivableRupees.toStringAsFixed(2)}'
                                  : '-₹${summary.oweRupees.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: summary.isSettled ? Colors.grey : (summary.isOwed ? AppColors.income : AppColors.expense),
                          ),
                        ),
                      ],
                    ),
                    if (summary.isOwed && !summary.member.isCurrentUser)
                      ElevatedButton.icon(
                        onPressed: () {
                          UpiPaymentUtil.launchUpiPaymentWithPrompt(
                            context,
                            receiverName: member.name,
                            amountRupees: summary.netBalancePaise.abs() / 100.0,
                            note: 'Settlement for ${room.name}',
                          );
                        },
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                        label: const Text('Pay UPI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    if (summary.isOwes && !summary.member.isCurrentUser)
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
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close Summary'),
          ),
        ],
      ),
    );
  }
}
