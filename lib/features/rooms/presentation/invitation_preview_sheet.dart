import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_util.dart';

import '../../../providers/app_providers.dart';

class InvitationPreviewSheet extends ConsumerStatefulWidget {
  final String roomName;
  final String createdBy;
  final int memberCount;
  final double totalExpenseRupees;
  final String token;
  final Future<bool> Function(String userName) onAcceptJoin;

  const InvitationPreviewSheet({
    super.key,
    required this.roomName,
    required this.createdBy,
    required this.memberCount,
    required this.totalExpenseRupees,
    required this.token,
    required this.onAcceptJoin,
  });

  @override
  ConsumerState<InvitationPreviewSheet> createState() => _InvitationPreviewSheetState();
}

class _InvitationPreviewSheetState extends ConsumerState<InvitationPreviewSheet> {
  late TextEditingController _nameController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    final defaultName = user?.userMetadata?['display_name'] ??
        (user?.email != null ? user!.email!.split('@').first : 'Member');
    _nameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isJoining = true);
    HapticFeedbackUtil.mediumImpact();

    final success = await widget.onAcceptJoin(name);

    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        HapticFeedbackUtil.heavyImpact();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Joined "${widget.roomName}" successfully!'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to join room. Invitation may be expired or invalid.'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.incomeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups, color: AppColors.income, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "YOU'VE BEEN INVITED",
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.roomName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Created By', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(widget.createdBy, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: theme.dividerColor),
                Column(
                  children: [
                    Text('Members', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${widget.memberCount} members', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: theme.dividerColor),
                Column(
                  children: [
                    Text('Shared Expense', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('₹${widget.totalExpenseRupees.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.income)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('You will be able to:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const CapabilityRow(icon: Icons.receipt_long, title: 'View shared group expenses'),
          const CapabilityRow(icon: Icons.add_circle_outline, title: 'Add & split expenses instantly'),
          const CapabilityRow(icon: Icons.account_balance_wallet_outlined, title: 'Track live balances & settle up'),
          const CapabilityRow(icon: Icons.task_alt, title: 'Collaborate on room tasks & to-dos'),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Your Display Name in Room',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isJoining ? null : _handleJoin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: AppColors.income,
              foregroundColor: Colors.white,
            ),
            child: _isJoining
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Join Room Workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const CapabilityRow({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.income),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
