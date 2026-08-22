import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../core/utils/split_engine.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/room_repository.dart';

import '../../../core/utils/form_draft_manager.dart';

class AddRoomExpenseSheet extends ConsumerStatefulWidget {
  final RoomWithDetails roomDetails;

  const AddRoomExpenseSheet({
    super.key,
    required this.roomDetails,
  });

  @override
  ConsumerState<AddRoomExpenseSheet> createState() => _AddRoomExpenseSheetState();
}

class _AddRoomExpenseSheetState extends ConsumerState<AddRoomExpenseSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late String _selectedPayerName;
  String? _selectedCategoryId;
  String _splitType = 'equal';
  DateTime _selectedDate = DateTime.now();
  XFile? _receiptImage;

  Future<void> _pickReceiptImage(ImageSource source) async {
    HapticFeedbackUtil.selectionClick();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          _receiptImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select receipt image: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    HapticFeedbackUtil.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  final Map<int, bool> _selectedMembersEqual = {};
  final Map<int, TextEditingController> _exactControllers = {};
  final Map<int, TextEditingController> _percentControllers = {};
  final Map<int, TextEditingController> _sharesControllers = {};

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: RoomExpenseFormDraft.description);
    _amountController = TextEditingController(text: RoomExpenseFormDraft.amount);
    _selectedPayerName = widget.roomDetails.members.first.name;
    _selectedCategoryId = RoomExpenseFormDraft.categoryId?.toString();
    _splitType = RoomExpenseFormDraft.splitType;

    int idx = 1;
    for (final _ in widget.roomDetails.members) {
      _selectedMembersEqual[idx] = true;
      _exactControllers[idx] = TextEditingController(text: '0');
      _percentControllers[idx] = TextEditingController(text: (100.0 / widget.roomDetails.members.length).toStringAsFixed(1));
      _sharesControllers[idx] = TextEditingController(text: '1');
      idx++;
    }

    _amountController.addListener(_updateDraft);
    _descriptionController.addListener(_updateDraft);
  }

  void _updateDraft() {
    RoomExpenseFormDraft.amount = _amountController.text;
    RoomExpenseFormDraft.description = _descriptionController.text;
    RoomExpenseFormDraft.splitType = _splitType;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    for (final c in _sharesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amountRupees = double.tryParse(_amountController.text) ?? 0.0;
    final totalPaise = (amountRupees * 100).round();

    final selectedMemberIds = _selectedMembersEqual.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member to split with')),
      );
      return;
    }

    List<CalculatedSplit> splits = [];
    final payerIdx = widget.roomDetails.members.indexWhere((m) => m.name == _selectedPayerName);
    final payerMemberId = payerIdx != -1 ? payerIdx + 1 : 1;

    if (_splitType == 'equal') {
      splits = SplitEngine.calculateEqualSplit(
        totalPaise: totalPaise,
        memberIds: selectedMemberIds,
        payerMemberId: payerMemberId,
      );
    } else if (_splitType == 'exact') {
      final exactPaiseMap = <int, int>{};
      int sumPaise = 0;
      for (final mId in selectedMemberIds) {
        final val = double.tryParse(_exactControllers[mId]?.text ?? '0') ?? 0.0;
        final p = (val * 100).round();
        exactPaiseMap[mId] = p;
        sumPaise += p;
      }

      if (sumPaise != totalPaise) {
        HapticFeedbackUtil.heavyImpact();
        final diff = ((totalPaise - sumPaise) / 100.0).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Split total doesn\'t match expense amount. Difference: ₹$diff'),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      splits = SplitEngine.calculateExactSplit(memberExactPaise: exactPaiseMap);
    } else if (_splitType == 'percentage') {
      final percentMap = <int, double>{};
      double sumPercent = 0.0;
      for (final mId in selectedMemberIds) {
        final val = double.tryParse(_percentControllers[mId]?.text ?? '0') ?? 0.0;
        percentMap[mId] = val;
        sumPercent += val;
      }

      if ((sumPercent - 100.0).abs() > 0.1) {
        HapticFeedbackUtil.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Percentages must sum to 100%. Current sum: ${sumPercent.toStringAsFixed(1)}%'),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      splits = SplitEngine.calculatePercentageSplit(
        totalPaise: totalPaise,
        memberPercentages: percentMap,
        payerMemberId: payerMemberId,
      );
    } else if (_splitType == 'shares') {
      final sharesMap = <int, int>{};
      for (final mId in selectedMemberIds) {
        final val = int.tryParse(_sharesControllers[mId]?.text ?? '1') ?? 1;
        sharesMap[mId] = val;
      }
      splits = SplitEngine.calculateShareSplit(
        totalPaise: totalPaise,
        memberShares: sharesMap,
        payerMemberId: payerMemberId,
      );
    }

    setState(() => _isSaving = true);
    final description = _descriptionController.text.trim();
    RoomExpenseFormDraft.clear();
    HapticFeedbackUtil.mediumImpact();
    final roomRepo = ref.read(roomRepositoryProvider);

    String? receiptUrl;
    if (_receiptImage != null) {
      final bytes = await _receiptImage!.readAsBytes();
      receiptUrl = await roomRepo.uploadReceiptImage(
        roomId: widget.roomDetails.room.id,
        bytes: bytes,
        fileName: _receiptImage!.name,
      );
    }

    try {
      await roomRepo.addRoomExpense(
        roomId: widget.roomDetails.room.id,
        paidByMemberName: _selectedPayerName,
        amountPaise: totalPaise,
        description: description,
        splitType: _splitType,
        splits: splits,
        categoryId: _selectedCategoryId,
        receiptUrl: receiptUrl,
        date: _selectedDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Expense "$description" added successfully!')),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = widget.roomDetails.members;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Shared Expense', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.income),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Total Amount',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Enter valid amount > 0';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'What was this expense for?',
                  hintText: 'e.g. Hotel Booking, Dinner, Fuel',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),
              categoriesAsync.maybeWhen(
                data: (cats) {
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category (Optional)',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')),
                      ...cats.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (id) => setState(() => _selectedCategoryId = id),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPayerName,
                decoration: const InputDecoration(
                  labelText: 'Paid By',
                  prefixIcon: Icon(Icons.person_pin_outlined),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.name,
                    child: Text(m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPayerName = val);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 22, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Date', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMMM yyyy (EEEE)').format(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bill / Receipt Attachment Tile
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Bill / Receipt Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        if (_receiptImage != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                            tooltip: 'Remove receipt',
                            onPressed: () => setState(() => _receiptImage = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_receiptImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List>(
                          future: _receiptImage!.readAsBytes(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                            return Image.memory(
                              snap.data!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickReceiptImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickReceiptImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Split Method', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: 'equal', label: FittedBox(child: Text('Equal'))),
                  ButtonSegment(value: 'exact', label: FittedBox(child: Text('Exact'))),
                  ButtonSegment(value: 'percentage', label: FittedBox(child: Text('%'))),
                  ButtonSegment(value: 'shares', label: FittedBox(child: Text('Shares'))),
                ],
                selected: {_splitType},
                onSelectionChanged: (set) => setState(() => _splitType = set.first),
              ),
              const SizedBox(height: 16),
              Text('Participants & Shares', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...members.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final m = entry.value;
                final isSelected = _selectedMembersEqual[idx] ?? false;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) => setState(() => _selectedMembersEqual[idx] = val ?? false),
                      ),
                      Expanded(
                        child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (isSelected && _splitType == 'exact')
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _exactControllers[idx],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '₹ ', isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      if (isSelected && _splitType == 'percentage')
                        SizedBox(
                          width: 85,
                          child: TextField(
                            controller: _percentControllers[idx],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(suffixText: '%', isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      if (isSelected && _splitType == 'shares')
                        SizedBox(
                          width: 95,
                          child: TextField(
                            controller: _sharesControllers[idx],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: ' share',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Add Shared Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
