import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/budget_model.dart';
import '../../../providers/app_providers.dart';

import '../../budgets/presentation/add_edit_budget_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _openAddBudget(BuildContext context, [BudgetModel? budget]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditBudgetSheet(budgetToEdit: budget),
    );
  }

  Future<void> _testNotification(WidgetRef ref, BuildContext context) async {
    final notificationService = ref.read(notificationServiceProvider);
    final granted = await notificationService.requestPermissions();

    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied. Enable in Settings.')),
        );
      }
      return;
    }

    await notificationService.scheduleReminderNotification(
      id: 9999,
      title: '🔔 Test Financial Reminder',
      body: 'Notifications are working perfectly!',
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification scheduled in 5 seconds!')),
      );
    }
  }

  Future<void> _setupDailyCheck(WidgetRef ref, BuildContext context) async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.requestPermissions();

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
    );

    if (time != null) {
      await notificationService.scheduleDailyCheckNotification(time: time);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily expense check scheduled every evening at ${time.format(context)}!')),
        );
      }
    }
  }

  Future<void> _confirmResetData(WidgetRef ref, BuildContext context) async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear User Data?'),
        content: const Text(
          'This will delete your transactions and financial records from Supabase Cloud. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (context.mounted) {
      final confirm2 = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: const Text('Are you 100% sure you want to clear your data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text('DELETE MY DATA'),
            ),
          ],
        ),
      );

      if (confirm2 == true) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client.from('transactions').delete().eq('user_id', userId);
          await client.from('financial_reminders').delete().eq('user_id', userId);
          await client.from('budgets').delete().eq('user_id', userId);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data cleared from Supabase Cloud.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgetsAsync = ref.watch(currentMonthBudgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Account & Security Section
          Text('ACCOUNT & SECURITY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Profile & Security', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Account info, password, biometrics & deletion'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile'),
            ),
          ),
          const SizedBox(height: 24),

          // Budgets Section
          Text('FINANCIAL BUDGETS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                budgetsAsync.when(
                  data: (budgets) {
                    if (budgets.isEmpty) {
                      return ListTile(
                        leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                        title: const Text('Set Monthly Budget'),
                        subtitle: const Text('Set spending targets to control expenses'),
                        trailing: const Icon(Icons.add),
                        onTap: () => _openAddBudget(context),
                      );
                    }
                    return Column(
                      children: [
                        ...budgets.map(
                          (b) => ListTile(
                            leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                            title: Text(b.category?.name ?? 'Monthly Budget'),
                            subtitle: Text('Limit: ₹${b.budget.limitRupees.toStringAsFixed(0)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openAddBudget(context, b.budget),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          title: const Text('Add Another Budget'),
                          onTap: () => _openAddBudget(context),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Preferences & Notifications
          Text('PREFERENCES & NOTIFICATIONS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                  title: const Text('Financial Reminders & Bills'),
                  subtitle: const Text('Manage bill payment alerts, EMI & subscription reminders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/reminders'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alarm_on, color: AppColors.primary),
                  title: const Text('Daily Expense Check Reminder'),
                  subtitle: const Text('Configure evening prompt to record expenses'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _setupDailyCheck(ref, context),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.currency_rupee, color: AppColors.income),
                  title: Text('Currency & Formatting'),
                  subtitle: Text('Indian Rupee (₹ INR) • en_IN'),
                  trailing: Icon(Icons.check, color: AppColors.income),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                  title: const Text('Test Local Notification'),
                  subtitle: const Text('Schedule instant 5-sec financial alert test'),
                  trailing: const Icon(Icons.send_outlined),
                  onTap: () => _testNotification(ref, context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          Text('DATA MANAGEMENT', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.expense, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.expense),
              title: const Text('Reset My Data', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
              subtitle: const Text('Clear cloud transactions, budgets & reminders'),
              onTap: () => _confirmResetData(ref, context),
            ),
          ),
          const SizedBox(height: 32),

          // App Info Footer
          Center(
            child: Column(
              children: [
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'PROFIN v2.0.0 • Supabase Cloud Architecture',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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

