import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../widgets/expandable_fab.dart';
import '../../reminders/presentation/add_edit_reminder_sheet.dart';
import '../../rooms/presentation/create_room_sheet.dart';
import '../../transactions/presentation/add_edit_transaction_sheet.dart';

import '../../../services/notification_service.dart';

class MainShellScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermissions();
    });
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.paperBackground,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.paperBorder,
              width: 0.8,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'More',
            ),
          ],
        ),
      ),
      floatingActionButton: widget.navigationShell.currentIndex == 0
          ? ExpandableFab(
              onAddExpense: () => _openSheet(context, const AddEditTransactionSheet(initialType: TransactionType.expense)),
              onAddIncome: () => _openSheet(context, const AddEditTransactionSheet(initialType: TransactionType.income)),
              onAddReminder: () => _openSheet(context, const AddEditReminderSheet()),
              onCreateEvent: () => _openSheet(context, const CreateRoomSheet()),
            )
          : null,
    );
  }
}
