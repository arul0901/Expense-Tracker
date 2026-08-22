import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/split_engine.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/category_repository.dart';
import '../../../widgets/category_chip.dart';

import '../../../core/utils/form_draft_manager.dart';

class AddEditTransactionSheet extends ConsumerStatefulWidget {
  final TransactionModel? transactionToEdit;
  final TransactionType? initialType;

  const AddEditTransactionSheet({
    super.key,
    this.transactionToEdit,
    this.initialType,
  });

  @override
  ConsumerState<AddEditTransactionSheet> createState() => _AddEditTransactionSheetState();
}

class _AddEditTransactionSheetState extends ConsumerState<AddEditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _amountFocusNode = FocusNode();

  late TransactionType _selectedType;

  // Separate State Memory for Expense & Income
  late TextEditingController _expenseAmountController;
  late TextEditingController _incomeAmountController;

  late TextEditingController _expenseNoteController;
  late TextEditingController _incomeNoteController;

  String? _expenseCategoryId;
  String? _incomeCategoryId;

  PaymentMethod _expensePaymentMethod = PaymentMethod.upi;
  PaymentMethod _incomePaymentMethod = PaymentMethod.upi;

  late DateTime _selectedDate;
  String? _selectedEventId;
  String? _selectedTargetId; // Can be eventId or "room_ROOMID"
  bool _showMoreFields = false;

  TextEditingController get _activeAmountController =>
      _selectedType == TransactionType.expense ? _expenseAmountController : _incomeAmountController;

  TextEditingController get _activeNoteController =>
      _selectedType == TransactionType.expense ? _expenseNoteController : _incomeNoteController;

  String? get _activeCategoryId =>
      _selectedType == TransactionType.expense ? _expenseCategoryId : _incomeCategoryId;

  PaymentMethod get _activePaymentMethod =>
      _selectedType == TransactionType.expense ? _expensePaymentMethod : _incomePaymentMethod;

  void _setActiveCategoryId(String? catId) {
    if (_selectedType == TransactionType.expense) {
      _expenseCategoryId = catId;
    } else {
      _incomeCategoryId = catId;
    }
  }

  void _setActivePaymentMethod(PaymentMethod method) {
    if (_selectedType == TransactionType.expense) {
      _expensePaymentMethod = method;
    } else {
      _incomePaymentMethod = method;
    }
  }

  @override
  void initState() {
    super.initState();
    final item = widget.transactionToEdit;

    if (item != null) {
      _selectedType = item.type == 'income' ? TransactionType.income : TransactionType.expense;
      final parsedPayment = PaymentMethod.values.firstWhere(
        (m) => m.name == item.paymentMethod,
        orElse: () => PaymentMethod.upi,
      );

      if (_selectedType == TransactionType.expense) {
        _expenseAmountController = TextEditingController(text: item.amountRupees.toStringAsFixed(2));
        _incomeAmountController = TextEditingController();
        _expenseNoteController = TextEditingController(text: item.note ?? '');
        _incomeNoteController = TextEditingController();
        _expenseCategoryId = item.categoryId;
        _expensePaymentMethod = parsedPayment;
      } else {
        _expenseAmountController = TextEditingController();
        _incomeAmountController = TextEditingController(text: item.amountRupees.toStringAsFixed(2));
        _expenseNoteController = TextEditingController();
        _incomeNoteController = TextEditingController(text: item.note ?? '');
        _incomeCategoryId = item.categoryId;
        _incomePaymentMethod = parsedPayment;
      }
      _selectedEventId = item.eventId;
    } else {
      _selectedType = widget.initialType ?? (TransactionFormDraft.hasDraft ? TransactionFormDraft.type : TransactionType.expense);
      _expenseAmountController = TextEditingController(text: _selectedType == TransactionType.expense ? TransactionFormDraft.amount : '');
      _incomeAmountController = TextEditingController(text: _selectedType == TransactionType.income ? TransactionFormDraft.amount : '');
      _expenseNoteController = TextEditingController(text: _selectedType == TransactionType.expense ? TransactionFormDraft.note : '');
      _incomeNoteController = TextEditingController(text: _selectedType == TransactionType.income ? TransactionFormDraft.note : '');

      if (_selectedType == TransactionType.expense) {
        _expenseCategoryId = TransactionFormDraft.categoryId?.toString();
      } else {
        _incomeCategoryId = TransactionFormDraft.categoryId?.toString();
      }

      if (TransactionFormDraft.hasDraft) {
        if (_selectedType == TransactionType.expense) {
          _expensePaymentMethod = TransactionFormDraft.paymentMethod;
        } else {
          _incomePaymentMethod = TransactionFormDraft.paymentMethod;
        }
      }
      _selectedEventId = TransactionFormDraft.eventId?.toString();
    }

    _selectedDate = item?.date ?? DateTime.now();

    if (item?.note != null || item?.eventId != null || TransactionFormDraft.note.isNotEmpty) {
      _showMoreFields = true;
    }

    _expenseAmountController.addListener(_updateDraft);
    _incomeAmountController.addListener(_updateDraft);
    _expenseNoteController.addListener(_updateDraft);
    _incomeNoteController.addListener(_updateDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  void _updateDraft() {
    if (widget.transactionToEdit == null) {
      TransactionFormDraft.amount = _activeAmountController.text;
      TransactionFormDraft.note = _activeNoteController.text;
      TransactionFormDraft.type = _selectedType;
      TransactionFormDraft.paymentMethod = _activePaymentMethod;
    }
  }

  @override
  void dispose() {
    _expenseAmountController.dispose();
    _incomeAmountController.dispose();
    _expenseNoteController.dispose();
    _incomeNoteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _activeCategoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    HapticFeedbackUtil.heavyImpact();

    final amount = double.tryParse(_activeAmountController.text) ?? 0.0;
    final amountPaise = (amount * 100).round();
    final repo = ref.read(transactionRepositoryProvider);

    try {
      final currentUser = ref.read(supabaseClientProvider).auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primaryInk,
              duration: const Duration(seconds: 4),
              content: const Text(
                'Please sign in to save your transactions to your ProFin account.',
                style: TextStyle(color: Colors.white),
              ),
              action: SnackBarAction(
                label: 'SIGN IN',
                textColor: AppColors.income,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/welcome');
                },
              ),
            ),
          );
        }
        return;
      }

      final effectiveEventId = (_selectedTargetId != null && !_selectedTargetId!.startsWith('room_'))
          ? _selectedTargetId
          : _selectedEventId;

      if (widget.transactionToEdit == null) {
        TransactionFormDraft.clear();
        final insertedTx = await repo.insertTransaction(
          type: _selectedType.name,
          amountPaise: amountPaise,
          categoryId: categoryId,
          date: _selectedDate,
          note: _activeNoteController.text.trim().isEmpty ? null : _activeNoteController.text.trim(),
          paymentMethod: _activePaymentMethod.name,
          eventId: effectiveEventId,
          roomId: _selectedTargetId != null && _selectedTargetId!.startsWith('room_')
              ? _selectedTargetId!.replaceFirst('room_', '')
              : null,
        );

        // If a Room Workspace was selected as the event/target, sync to Room with linkedTransactionId
        if (_selectedTargetId != null && _selectedTargetId!.startsWith('room_')) {
          final roomId = _selectedTargetId!.replaceFirst('room_', '');
          final roomRepo = ref.read(roomRepositoryProvider);
          final roomDetails = await roomRepo.getRoomWithDetails(roomId);

          if (roomDetails != null && roomDetails.members.isNotEmpty) {
            final currentUserId = currentUser.id;
            final payer = roomDetails.members.firstWhere(
              (m) => m.userId == currentUserId || m.isCurrentUser,
              orElse: () => roomDetails.members.first,
            );
            final noteText = _activeNoteController.text.trim();
            final desc = noteText.isNotEmpty ? noteText : 'Expense from Main App';
            final memberIds = List.generate(roomDetails.members.length, (i) => i + 1);
            final splits = SplitEngine.calculateEqualSplit(
              totalPaise: amountPaise,
              memberIds: memberIds,
              payerMemberId: 1,
            );

            await roomRepo.addRoomExpense(
              roomId: roomId,
              paidByMemberName: payer.name,
              amountPaise: amountPaise,
              description: desc,
              splitType: 'equal',
              splits: splits,
              categoryId: categoryId,
              notes: noteText.isNotEmpty ? noteText : null,
              linkedTransactionId: insertedTx.id,
            );
          }
        }
      } else {
        await repo.updateTransaction(
          TransactionModel(
            id: widget.transactionToEdit!.id,
            userId: widget.transactionToEdit!.userId,
            type: _selectedType.name,
            amountPaise: amountPaise,
            categoryId: categoryId,
            date: _selectedDate,
            note: _activeNoteController.text.trim().isEmpty ? null : _activeNoteController.text.trim(),
            paymentMethod: _activePaymentMethod.name,
            eventId: effectiveEventId,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    }
  }

  Widget _buildCategorySelector(List<CategoryModel> categories) {
    final effectiveCategories = categories.isEmpty
        ? CategoryRepository.defaultCategories.where((c) => c.type == _selectedType.name).toList()
        : categories;

    final currentId = _activeCategoryId;
    if (currentId == null && effectiveCategories.isNotEmpty) {
      _setActiveCategoryId(effectiveCategories.first.id);
    } else if (currentId != null && effectiveCategories.isNotEmpty) {
      final exists = effectiveCategories.any((c) => c.id == currentId);
      if (!exists) {
        _setActiveCategoryId(effectiveCategories.first.id);
      }
    }

    final activeId = _activeCategoryId;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: effectiveCategories.map((cat) {
        final isSelected = cat.id == activeId;
        return CategoryChip(
          category: cat,
          isSelected: isSelected,
          onTap: () {
            HapticFeedbackUtil.selectionClick();
            setState(() => _setActiveCategoryId(cat.id));
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = _selectedType == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    final eventsAsync = ref.watch(allEventsProvider);
    final roomsAsync = ref.watch(allRoomsProvider);

    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.transactionToEdit == null
                        ? (_selectedType == TransactionType.expense ? 'Add Expense' : 'Add Income')
                        : 'Edit Transaction',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Type Selector
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_downward, color: AppColors.expense),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_upward, color: AppColors.income),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  HapticFeedbackUtil.selectionClick();
                  setState(() {
                    _selectedType = set.first;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Large Numeric Amount Input (Auto-Focused)
              TextFormField(
                key: ValueKey(_selectedType),
                controller: _activeAmountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  hintText: '0.00',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter an amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fast Category Chips Row
              Text('Category', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => _buildCategorySelector(categories),
                loading: () => _buildCategorySelector([]),
                error: (e, s) => _buildCategorySelector([]),
              ),
              const SizedBox(height: 20),

              // Date Picker & Payment Method Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          DateFormatter.formatShortDate(_selectedDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PaymentMethod>(
                      key: ValueKey('${_selectedType.name}_payment'),
                      isExpanded: true,
                      initialValue: _activePaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment_outlined),
                      ),
                      items: PaymentMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _setActivePaymentMethod(val));
                        }
                      },
                    ),
                  ),
                ],
              ),

              // Optional Collapsible More Fields Toggle
              if (!_showMoreFields) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _showMoreFields = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Note or Link Event (Optional)'),
                ),
              ],

              if (_showMoreFields) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey('${_selectedType.name}_note'),
                  controller: _activeNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    hintText: 'e.g. Lunch with team',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedTargetId ?? _selectedEventId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Link to Room / Event (Optional)',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None (Personal Expense)')),
                    ...roomsAsync.maybeWhen(
                      data: (rooms) => rooms.map(
                        (r) => DropdownMenuItem<String?>(
                          value: 'room_${r.room.id}',
                          child: Text('🏠 Room: ${r.room.name}'),
                        ),
                      ),
                      orElse: () => const [],
                    ),
                    ...eventsAsync.maybeWhen(
                      data: (events) => events.map(
                        (ev) => DropdownMenuItem<String?>(
                          value: ev.id,
                          child: Text('🎉 Event: ${ev.title}'),
                        ),
                      ),
                      orElse: () => const [],
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedTargetId = val;
                      if (val != null && !val.startsWith('room_')) {
                        _selectedEventId = val;
                      } else {
                        _selectedEventId = null;
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Save Action Button
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.transactionToEdit == null ? 'Save Transaction' : 'Update Transaction',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
