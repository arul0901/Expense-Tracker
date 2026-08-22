import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/auth/providers/auth_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/upi_payment_util.dart';
import 'change_password_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _showEditNameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await ref.read(authNotifierProvider.notifier).updateProfile(displayName: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Profile updated successfully!')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of ProFin?'),
        content: const Text('You will need to log back in to access your financial dashboard and shared workspaces.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.heavyImpact();
      await ref.read(authNotifierProvider.notifier).logout();
      if (mounted) {
        context.go('/welcome');
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your user account and associated cloud data. This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                prefixIcon: Icon(Icons.lock_outline),
              ),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      HapticFeedbackUtil.heavyImpact();
      final success = await ref.read(authNotifierProvider.notifier).deleteAccount(passwordController.text);
      if (mounted) {
        if (success) {
          context.go('/welcome');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete account. Incorrect password.'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar & Basic Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.income,
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showEditNameDialog(user.displayName),
                      ),
                    ],
                  ),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: AppColors.income),
                        const SizedBox(width: 4),
                        Text(
                          user.isEmailVerified ? 'Verified Account' : 'Pending Verification',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.income),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Member since ${DateFormat('MMM yyyy').format(user.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // UPI Details Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                title: const Text('My Default UPI VPA ID', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: FutureBuilder<String?>(
                  future: UpiPaymentUtil.getSavedUpiId(user.displayName),
                  builder: (context, snapshot) {
                    final upiId = snapshot.data;
                    return Text(
                      upiId != null && upiId.isNotEmpty ? upiId : 'Not set (e.g. arul@okicici)',
                      style: TextStyle(
                        color: upiId != null && upiId.isNotEmpty ? AppColors.primary : Colors.grey,
                        fontWeight: upiId != null && upiId.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final currentUpi = await UpiPaymentUtil.getSavedUpiId(user.displayName) ?? '';
                  final controller = TextEditingController(text: currentUpi);
                  if (!context.mounted) return;
                  final newUpi = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Set Default UPI VPA ID'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'UPI VPA ID',
                          hintText: 'e.g. arul@okicici, phone@paytm',
                          prefixIcon: Icon(Icons.payment),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Save UPI ID'),
                        ),
                      ],
                    ),
                  );
                  if (newUpi != null) {
                    await UpiPaymentUtil.saveUpiId(user.displayName, newUpi);
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Saved UPI ID for settlements!')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Security Options Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SECURITY & LOCK',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Biometrics & Password Options
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Biometric App Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Protect ProFin with Fingerprint / Face ID on app reopen'),
                    secondary: const Icon(Icons.fingerprint, color: AppColors.income),
                    value: authState.isBiometricEnabled,
                    activeTrackColor: AppColors.income,
                    onChanged: (val) async {
                      HapticFeedbackUtil.selectionClick();
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await ref.read(authNotifierProvider.notifier).setBiometricEnabled(val);
                      if (!success) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Biometric authentication is not supported or was cancelled.'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: AppColors.income),
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Update your authentication password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      HapticFeedbackUtil.selectionClick();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ChangePasswordSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Actions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCOUNT ACTIONS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.orange),
                    title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleLogout,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.expense),
                    title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
                    subtitle: const Text('Permanently remove account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleDeleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
