import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/auth/providers/auth_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/sign_in_required_dialog.dart';
import 'create_room_sheet.dart';
import 'qr_scanner_screen.dart';

class RoomsLandingScreen extends ConsumerWidget {
  const RoomsLandingScreen({super.key});

  bool _checkAuth(BuildContext context, WidgetRef ref, {required String actionMessage}) {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated && isAnonymousUser()) {
      showSignInRequiredDialog(
        context,
        message: actionMessage,
      );
      return false;
    }
    return true;
  }

  void _openCreateRoom(BuildContext context, WidgetRef ref) async {
    if (!_checkAuth(context, ref, actionMessage: 'Please sign in first to create a room workspace.')) return;
    HapticFeedbackUtil.selectionClick();
    final roomId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateRoomSheet(),
    );

    if (roomId != null && context.mounted) {
      context.push('/rooms/$roomId');
    }
  }

  void _openQrScanner(BuildContext context, WidgetRef ref) {
    if (!_checkAuth(context, ref, actionMessage: 'Please sign in first to scan or join rooms.')) return;
    HapticFeedbackUtil.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search ProFin',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Room QR',
            onPressed: () => _openQrScanner(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Room',
            onPressed: () => _openCreateRoom(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header title banner
          Text(
            'ROOMS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: AppColors.income,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shared finances\nmade simple.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),

          roomsAsync.when(
            data: (rooms) {
              if (rooms.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.incomeLight,
                        child: const Icon(Icons.groups, size: 36, color: AppColors.income),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO ROOMS YET',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a shared space for flatmates, trips, friends, and families to track expenses, balances & tasks.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openQrScanner(context, ref),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan QR Code'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openCreateRoom(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Room'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.income,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: rooms.map((roomDetails) {
                  final room = roomDetails.room;
                  final members = roomDetails.members;
                  final totalRupees = roomDetails.totalRoomExpensesPaise / 100.0;
                  final netRupees = roomDetails.currentUserBalance.netBalancePaise / 100.0;
                  final isOwed = netRupees > 0;
                  final isSettled = netRupees == 0;
                  final accentColor = Color(room.colorAccent);

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    onTap: () {
                      if (!_checkAuth(context, ref, actionMessage: 'Please sign in first to open room workspaces.')) return;
                      context.push('/rooms/${room.id}');
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        room.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          room.type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${members.length} members • ₹${totalRupees.toStringAsFixed(0)} shared expenses',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: theme.dividerColor),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // User net balance status pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSettled
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : (isOwed ? AppColors.incomeLight : AppColors.expenseLight),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSettled ? Icons.check_circle : (isOwed ? Icons.arrow_downward : Icons.arrow_upward),
                                    size: 14,
                                    color: isSettled ? Colors.grey : (isOwed ? AppColors.income : AppColors.expense),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isSettled
                                        ? 'All Settled ✓'
                                        : (isOwed ? 'You are owed ' : 'You owe '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSettled ? Colors.grey : (isOwed ? AppColors.income : AppColors.expense),
                                    ),
                                  ),
                                  if (!isSettled)
                                    AmountText(
                                      amount: netRupees.abs(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isOwed ? AppColors.income : AppColors.expense,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (roomDetails.unpaidMembersCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${roomDetails.unpaidMembersCount} unpaid',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (roomDetails.lastActivity != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last activity: ${roomDetails.lastActivity!.details}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('Unable to load rooms'),
                    TextButton(
                      onPressed: () => ref.invalidate(allRoomsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateRoom(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
      ),
    );
  }
}
