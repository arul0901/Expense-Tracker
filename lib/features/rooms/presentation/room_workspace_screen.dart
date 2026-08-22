import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/member_financial_summary.dart';
import '../../../core/models/room_member_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/room_report_generator.dart';
import '../../../core/utils/settlement_engine.dart';
import '../../../core/utils/upi_payment_util.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/room_repository.dart';
import '../../../repositories/task_repository.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/sign_in_required_dialog.dart';
import 'add_room_expense_sheet.dart';
import 'create_edit_task_sheet.dart';
import 'expense_detail_sheet.dart';
import 'member_detail_sheet.dart';
import 'room_qr_display_dialog.dart';

class RoomWorkspaceScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomWorkspaceScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<RoomWorkspaceScreen> createState() => _RoomWorkspaceScreenState();
}

class _RoomWorkspaceScreenState extends ConsumerState<RoomWorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RoomWithDetails? _roomDetails;
  bool _isLoading = true;
  String _balanceTimeFilter = 'Total'; // 'Daily', 'Weekly', 'Monthly', 'Total'

  DateTime? _getFilterStartDate() {
    final now = DateTime.now();
    if (_balanceTimeFilter == 'Daily') {
      return DateTime(now.year, now.month, now.day);
    } else if (_balanceTimeFilter == 'Weekly') {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    } else if (_balanceTimeFilter == 'Monthly') {
      return DateTime(now.year, now.month, 1);
    }
    return null;
  }

  DateTime? _getFilterEndDate() {
    final now = DateTime.now();
    if (_balanceTimeFilter == 'Daily') {
      return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
    return null;
  }

  Widget _buildTimeFilterSegment() {
    final options = ['Daily', 'Weekly', 'Monthly', 'Total'];
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _balanceTimeFilter == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedbackUtil.selectionClick();
                setState(() {
                  _balanceTimeFilter = opt;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadRoomDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomDetails() async {
    final repo = ref.read(roomRepositoryProvider);
    final details = await repo.getRoomWithDetails(widget.roomId);
    if (mounted) {
      setState(() {
        _roomDetails = details;
        _isLoading = false;
      });
    }
  }

  void _showQrCode() async {
    if (_roomDetails == null) return;
    HapticFeedbackUtil.selectionClick();
    final repo = ref.read(roomRepositoryProvider);
    final invite = await repo.getOrCreateActiveInvite(widget.roomId);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => RoomQrDisplayDialog(
          roomName: _roomDetails!.room.name,
          token: invite.token,
          roomId: widget.roomId,
          expiresAt: invite.expiresAt,
        ),
      );
    }
  }

  void _openAddExpense() async {
    if (_roomDetails == null) return;
    HapticFeedbackUtil.selectionClick();
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddRoomExpenseSheet(roomDetails: _roomDetails!),
    );

    if (added == true && mounted) {
      _loadRoomDetails();
      ref.invalidate(roomExpensesProvider(widget.roomId));
      ref.invalidate(roomMemberFinancialsProvider(widget.roomId));
      ref.invalidate(roomActivitiesProvider(widget.roomId));
    }
  }

  void _openAddTask() {
    if (_roomDetails == null) return;
    HapticFeedbackUtil.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEditTaskSheet(
        roomId: widget.roomId,
        roomMembers: _roomDetails!.members,
      ),
    );
  }

  Future<void> _recordSettlement(SettlementSuggestion suggestion) async {
    if (_roomDetails == null) return;
    final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
    final isPayerOrReceiverOrOwner = _roomDetails!.members.any((m) =>
        (m.isCurrentUser || m.userId == currentUser?.id) &&
        (m.name == suggestion.fromMemberName || m.name == suggestion.toMemberName || m.role == 'Owner'));

    if (!isPayerOrReceiverOrOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${suggestion.fromMemberName}, ${suggestion.toMemberName}, or the room owner can mark this settlement as settled.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fromMember = _roomDetails!.members.firstWhere((m) => m.name == suggestion.fromMemberName, orElse: () => _roomDetails!.members.first);
    final toMember = _roomDetails!.members.firstWhere((m) => m.name == suggestion.toMemberName, orElse: () => _roomDetails!.members.first);
    final amountRupees = suggestion.amountPaise / 100.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Settlement?'),
        content: Text('Mark "${fromMember.name}" paying ₹${amountRupees.toStringAsFixed(2)} to "${toMember.name}" as Settled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.income),
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.heavyImpact();
      final repo = ref.read(roomRepositoryProvider);
      try {
        await repo.recordSettlement(
          roomId: widget.roomId,
          fromMemberName: fromMember.name,
          toMemberName: toMember.name,
          amountPaise: suggestion.amountPaise,
          note: 'Settled via ProFin Room Workspace',
        );
        await _loadRoomDetails();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You\'re offline. Reconnect to continue. ($e)')),
          );
        }
      }
    }
  }

  Future<void> _toggleTask(TaskWithMemberAndRoom taskItem) async {
    HapticFeedbackUtil.selectionClick();
    final repo = ref.read(taskRepositoryProvider);
    await repo.toggleTaskCompleted(taskItem.task.id);
  }

  Future<void> _handleRemoveMember(RoomMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: Text('Are you sure you want to remove ${member.name} from this room? Their past transactions will remain recorded for accuracy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('Remove Member'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedbackUtil.heavyImpact();
      final repo = ref.read(roomRepositoryProvider);
      await repo.removeRoomMember(widget.roomId, member.id);
      await _loadRoomDetails();
    }
  }

  Future<void> _handleDeleteRoom() async {
    if (_roomDetails == null) return;

    final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
    final isOwner = _roomDetails!.room.createdBy == currentUser?.id || _roomDetails!.members.any((m) => m.isCurrentUser && m.role == 'Owner');
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the room owner can delete this room.'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room Workspace?'),
        content: Text(
          'Are you sure you want to delete "${_roomDetails!.room.name}"?\n\n'
          'This action is permanent and will delete all associated expenses, splits, tasks, settlements, and member records. Only the room owner can perform this operation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Room'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedbackUtil.heavyImpact();
      try {
        final repo = ref.read(roomRepositoryProvider);
        await repo.deleteRoom(widget.roomId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room "${_roomDetails!.room.name}" deleted successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLeaveRoom() async {
    if (_roomDetails == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room Workspace?'),
        content: Text(
          'Are you sure you want to leave "${_roomDetails!.room.name}"?\n\n'
          'You can re-join anytime using an invite link or QR code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedbackUtil.heavyImpact();
      try {
        final repo = ref.read(roomRepositoryProvider);
        await repo.leaveRoom(widget.roomId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You left "${_roomDetails!.room.name}"')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
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

    // Listen for real-time room member and expense changes to auto-refresh room workspace details
    ref.listen(roomMembersProvider(widget.roomId), (previous, next) {
      _loadRoomDetails();
    });
    ref.listen(roomExpensesProvider(widget.roomId), (previous, next) {
      _loadRoomDetails();
    });

    if (isAnonymousUser()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.expenseLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 48, color: AppColors.expense),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sign In Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You must sign in first to access room workspaces.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In First'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_roomDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.expense),
                const SizedBox(height: 16),
                const Text(
                  'Room Unavailable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load room details. Please check your internet connection or try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _loadRoomDetails();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final room = _roomDetails!.room;
    final members = _roomDetails!.members;
    final accentColor = Color(room.colorAccent);
    final expensesAsync = ref.watch(roomExpensesProvider(widget.roomId));
    final tasksAsync = ref.watch(roomTasksProvider(widget.roomId));
    final activitiesAsync = ref.watch(roomActivitiesProvider(widget.roomId));
    final membersAsync = ref.watch(roomMembersProvider(widget.roomId));
    final memberFinancialsAsync = ref.watch(roomMemberFinancialsProvider(widget.roomId));

    final activeMembers = membersAsync.value ?? members;
    final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
    final isOwner = room.createdBy == currentUser?.id || activeMembers.any((m) => m.isCurrentUser && m.role == 'Owner');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${members.length} members • ${room.type}', style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Invite Members QR',
            onPressed: _showQrCode,
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'qr') _showQrCode();
              if (val == 'export_pdf') {
                final expList = expensesAsync.value ?? [];
                final repo = ref.read(roomRepositoryProvider);
                final balancesList = await repo.calculateRoomBalances(widget.roomId);
                if (context.mounted && _roomDetails != null) {
                  RoomReportGenerator.exportPdfReport(
                    context,
                    roomDetails: _roomDetails!,
                    expenses: expList,
                    balances: balancesList,
                  );
                }
              }
              if (val == 'export_csv') {
                final expList = expensesAsync.value ?? [];
                if (context.mounted && _roomDetails != null) {
                  RoomReportGenerator.exportCsvReport(
                    context,
                    roomDetails: _roomDetails!,
                    expenses: expList,
                  );
                }
              }
              if (val == 'leave') _handleLeaveRoom();
              if (val == 'delete') _handleDeleteRoom();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text('Export Statement (PDF)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: AppColors.income, size: 20),
                    SizedBox(width: 10),
                    Text('Export Expenses (CSV)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'qr', child: Text('Show QR Invite Token')),
              if (!isOwner)
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave Room Workspace', style: TextStyle(color: AppColors.expense)),
                ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Room (Owner)', style: TextStyle(color: AppColors.expense)),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Tasks'),
            Tab(text: 'Members'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Expenses Tab
          expensesAsync.when(
            data: (expensesList) {
              if (expensesList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No Room Expenses Yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Add group expenses to start auto-splitting balances.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openAddExpense,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                      ),
                    ],
                  ),
                );
              }

              final listTotalPaise = expensesList.fold<int>(0, (sum, e) => sum + e.expense.amountPaise);
              final totalListRupees = listTotalPaise / 100.0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Group Expenses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            AmountText(amount: totalListRupees, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: accentColor)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAddExpense,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Expense'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...expensesList.map((e) {
                    final exp = e.expense;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ExpenseDetailSheet(
                              expenseDetails: e,
                              members: members,
                              room: room,
                              onUpdated: () {
                                _loadRoomDetails();
                                ref.invalidate(roomExpensesProvider(widget.roomId));
                                ref.invalidate(roomMemberFinancialsProvider(widget.roomId));
                                ref.invalidate(roomActivitiesProvider(widget.roomId));
                              },
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: accentColor.withValues(alpha: 0.2),
                          child: Icon(Icons.shopping_bag_outlined, color: accentColor),
                        ),
                        title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Paid by ${e.payer.name} • ${DateFormat('dd MMM').format(exp.date)}'),
                        trailing: AmountText(
                          amount: exp.amountRupees,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading expenses: $e')),
          ),

          // 2. Balances Tab
          FutureBuilder<List<MemberNetBalance>>(
            future: ref.read(roomRepositoryProvider).calculateRoomBalances(
              widget.roomId,
              startDate: _getFilterStartDate(),
              endDate: _getFilterEndDate(),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final balances = snapshot.data ?? [];
              final suggestions = SettlementEngine.calculateMinimumSettlements(balances);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('RECOMMENDED PAYMENTS TO SETTLE UP', style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (suggestions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('🎉 All group expenses are fully settled! No pending balances.')),
                      ),
                    )
                  else
                    ...suggestions.map(
                      (s) {
                        final currentMember = activeMembers.firstWhere(
                          (m) => m.isCurrentUser,
                          orElse: () => RoomMemberModel(id: '', roomId: widget.roomId, name: '', isCurrentUser: false, role: 'Member', avatarColor: 0),
                        );
                        final currentNameClean = currentMember.name.trim().toLowerCase();
                        final fromNameClean = s.fromMemberName.trim().toLowerCase();
                        final toNameClean = s.toMemberName.trim().toLowerCase();

                        final isCurrentOwer = currentNameClean.isNotEmpty && currentNameClean == fromNameClean;
                        final isCurrentReceiver = currentNameClean.isNotEmpty && currentNameClean == toNameClean;

                        String subtitleText;
                        if (isCurrentOwer) {
                          subtitleText = 'You owe ${s.toMemberName}';
                        } else if (isCurrentReceiver) {
                          subtitleText = '${s.fromMemberName} owes you';
                        } else {
                          subtitleText = '${s.fromMemberName} owes ${s.toMemberName}';
                        }

                        final showUpiButton = isCurrentOwer;

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.swap_horiz_outlined, color: AppColors.income),
                            title: Text('${s.fromMemberName} ➔ ${s.toMemberName}'),
                            subtitle: Text(subtitleText),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AmountText(amount: s.amountPaise / 100.0, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                if (showUpiButton)
                                  IconButton(
                                    icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                                    tooltip: 'Pay ${s.toMemberName} via UPI App (GPay/PhonePe/Paytm)',
                                    onPressed: () {
                                      UpiPaymentUtil.launchUpiPaymentWithPrompt(
                                        context,
                                        receiverName: s.toMemberName,
                                        amountRupees: s.amountPaise / 100.0,
                                        note: 'Settlement for ${_roomDetails?.room.name ?? "Room"}',
                                        onPaymentLaunched: () => _recordSettlement(s),
                                      );
                                    },
                                  ),
                                ElevatedButton(
                                  onPressed: () => _recordSettlement(s),
                                  child: const Text('Mark Settled'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('MEMBER BALANCE OVERVIEW', style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Tap card for details', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  _buildTimeFilterSegment(),
                  // Explainer Banner for New Users
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('How Room Balances Work', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Net Balance = (Paid Upfront) - (Personal Share)\n'
                          '• 🟢 Gets Back: Spent cash upfront for group expenses (Group owes them)\n'
                          '• 🔴 Owes: Consumed food/services without paying upfront (They owe group)\n'
                          '• Tap any member card to view history, send reminders, or settle dues.',
                          style: TextStyle(fontSize: 11, height: 1.45, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  ...balances.map((b) {
                    final matchingMember = members.firstWhere(
                      (m) => m.name == b.memberName,
                      orElse: () => RoomMemberModel(
                        id: b.memberName,
                        roomId: widget.roomId,
                        name: b.memberName,
                        isCurrentUser: false,
                        role: 'Member',
                        avatarColor: 0xFF3B82F6,
                      ),
                    );

                    final finSums = memberFinancialsAsync.value ?? [];
                    final finSum = finSums.firstWhere(
                      (s) => s.member.name == b.memberName,
                      orElse: () => MemberFinancialSummary(
                        member: matchingMember,
                        totalDuesPaise: b.totalSharePaise,
                        totalPaidPaise: b.totalPaidPaise,
                        netBalancePaise: b.netBalancePaise,
                      ),
                    );

                    return _MemberBalanceOverviewCard(
                      balance: b,
                      member: matchingMember,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MemberDetailSheet(
                            summary: finSum,
                            room: room,
                            onUpdated: _loadRoomDetails,
                          ),
                        );
                      },
                    );
                  }),
                ],
              );
            },
          ),

          // 3. Tasks Tab
          tasksAsync.when(
            data: (tasks) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ROOM TASKS', style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.bold, fontSize: 12)),
                      ElevatedButton.icon(onPressed: _openAddTask, icon: const Icon(Icons.add, size: 16), label: const Text('Add Task')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No tasks created for this room.')))
                  else
                    ...tasks.map((t) {
                      final task = t.task;
                      final isComp = task.isCompleted;
                      return Card(
                        child: CheckboxListTile(
                          value: isComp,
                          onChanged: (_) => _toggleTask(t),
                          title: Text(task.title, style: TextStyle(decoration: isComp ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold)),
                          subtitle: Text(t.assignedMember != null ? 'Assigned: ${t.assignedMember!.name}' : 'Unassigned'),
                        ),
                      );
                    }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading tasks: $e')),
          ),

          // 4. Members Tab (Real-Time Synchronized & Financial Metrics)
          memberFinancialsAsync.when(
            data: (financialSummaries) {
              if (financialSummaries.isEmpty) {
                return const Center(child: Text('No members in room.'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ROOM MEMBERS & FINANCIAL DUES',
                        style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${financialSummaries.length} Members',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...financialSummaries.map((sum) {
                    final m = sum.member;
                    final isOwed = sum.isOwed;
                    final isOwes = sum.isOwes;
                    final isSettled = sum.isSettled;

                    Color statusColor = AppColors.income;
                    if (isOwes) statusColor = AppColors.expense;
                    if (isSettled) statusColor = Colors.grey;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => MemberDetailSheet(
                              summary: sum,
                              room: room,
                              onUpdated: _loadRoomDetails,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(m.avatarColor),
                                    child: Text(
                                      m.name.isNotEmpty ? m.name.substring(0, 1).toUpperCase() : 'M',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Row(
                                           children: [
                                             Flexible(
                                               child: Text(
                                                 m.name,
                                                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                 overflow: TextOverflow.ellipsis,
                                               ),
                                             ),
                                             const SizedBox(width: 6),
                                             if (m.role == 'Owner' || room.createdBy == m.userId) ...[
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                 decoration: BoxDecoration(
                                                   color: Colors.amber.withValues(alpha: 0.2),
                                                   borderRadius: BorderRadius.circular(6),
                                                   border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                                                 ),
                                                 child: Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Icon(Icons.star, size: 11, color: Colors.amber.shade900),
                                                     const SizedBox(width: 3),
                                                     Text(
                                                       'Owner',
                                                       style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                               const SizedBox(width: 4),
                                             ],
                                             if (m.isCurrentUser)
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                 decoration: BoxDecoration(
                                                   color: AppColors.incomeLight,
                                                   borderRadius: BorderRadius.circular(6),
                                                   border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                                                 ),
                                                 child: const Text(
                                                   'You',
                                                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.income),
                                                 ),
                                               ),
                                           ],
                                         ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Joined ${DateFormat('dd MMM').format(m.joinedAt)}',
                                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      sum.statusLabel,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                  if (m.role != 'Owner' && isOwner)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove_outlined, color: AppColors.expense, size: 20),
                                      onPressed: () => _handleRemoveMember(m),
                                      tooltip: 'Remove ${m.name}',
                                    ),
                                ],
                              ),
                              const Divider(height: 18),
                              // Dues, Paid, and Owe Metrics Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Dues', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${sum.totalDuesRupees.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Paid', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${sum.totalPaidRupees.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.income),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isOwed ? 'Receivable' : (isOwes ? 'Owes' : 'Balance'),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isOwes ? AppColors.expense : (isOwed ? AppColors.income : Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isSettled
                                            ? 'Settled'
                                            : (isOwed ? '+₹${sum.receivableRupees.toStringAsFixed(2)}' : '-₹${sum.oweRupees.toStringAsFixed(2)}'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isSettled ? Colors.grey : (isOwed ? AppColors.income : AppColors.expense),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showQrCode,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Invite Members via QR / Token'),
                  ),
                  if (!isOwner) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _handleLeaveRoom,
                      icon: const Icon(Icons.exit_to_app, color: AppColors.expense),
                      label: const Text('Leave Room Workspace', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _handleDeleteRoom,
                      icon: const Icon(Icons.delete_forever, color: AppColors.expense),
                      label: const Text('Delete Room Workspace (Owner)', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading member financials: $e')),
          ),

          // 5. Activity Tab
          activitiesAsync.when(
            data: (activities) {
              if (activities.isEmpty) {
                return const Center(child: Text('No room activity recorded yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final act = activities[index];
                  return ListTile(
                    leading: const Icon(Icons.history_outlined, color: AppColors.primary),
                    title: Text(act.details),
                    subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(act.createdAt)),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading activities: $e')),
          ),
        ],
      ),
    );
  }
}

class _MemberBalanceOverviewCard extends StatelessWidget {
  final MemberNetBalance balance;
  final RoomMemberModel? member;
  final VoidCallback onTap;

  const _MemberBalanceOverviewCard({
    required this.balance,
    this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwed = balance.netBalancePaise > 0;
    final isBalanced = balance.netBalancePaise == 0;

    final paidRupees = (balance.totalPaidPaise / 100.0).toStringAsFixed(2);
    final shareRupees = (balance.totalSharePaise / 100.0).toStringAsFixed(2);
    final netRupees = (balance.netBalancePaise.abs() / 100.0).toStringAsFixed(2);

    final statusColor = isBalanced
        ? Colors.grey
        : (isOwed ? AppColors.income : AppColors.expense);

    final statusBgColor = isBalanced
        ? Colors.grey.withValues(alpha: 0.1)
        : (isOwed ? AppColors.incomeLight : AppColors.expenseLight);

    final avatarColor = member != null ? Color(member!.avatarColor) : AppColors.primary;
    final isYou = member?.isCurrentUser == true;

    // Plain English explanation banner for beginners
    String humanExplanation = '';
    if (isBalanced) {
      humanExplanation = 'Everything is settled! Paid amount matches personal share.';
    } else if (isOwed) {
      humanExplanation = '${balance.memberName} paid ₹$paidRupees upfront for group expenses. After their ₹$shareRupees share, the group owes them ₹$netRupees.';
    } else {
      humanExplanation = '${balance.memberName}\'s share is ₹$shareRupees, but paid ₹$paidRupees upfront. ${balance.memberName} owes ₹$netRupees to the group.';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Avatar, Name, Status Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarColor,
                    child: Text(
                      balance.memberName.isNotEmpty ? balance.memberName[0].toUpperCase() : 'M',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            balance.memberName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isYou) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.incomeLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.income),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBalanced
                              ? Icons.check_circle_outline
                              : (isOwed ? Icons.arrow_upward : Icons.arrow_downward),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBalanced
                              ? 'Settled (₹0.00)'
                              : (isOwed ? 'Gets Back ₹$netRupees' : 'Owes ₹$netRupees'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Two breakdown boxes: Total Paid Upfront & Personal Share
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Paid Upfront',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹$paidRupees',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Cash spent for group',
                            style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_outline, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Their Share',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹$shareRupees',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Personal consumption',
                            style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Plain English explanation note banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 13, color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        humanExplanation,
                        style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85)),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
