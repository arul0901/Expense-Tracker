import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/models/reminder_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/category_icon_widget.dart';

class AddEditReminderSheet extends ConsumerStatefulWidget {
  final ReminderModel? reminderToEdit;

  const AddEditReminderSheet({
    super.key,
    this.reminderToEdit,
  });

  @override
  ConsumerState<AddEditReminderSheet> createState() => _AddEditReminderSheetState();
}

class _AddEditReminderSheetState extends ConsumerState<AddEditReminderSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;

  late RepeatType _selectedRepeat;
  late DateTime _dueDate;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final item = widget.reminderToEdit;

    _titleController = TextEditingController(text: item?.title ?? '');
    _amountController = TextEditingController(
      text: item != null ? item.amountRupees.toStringAsFixed(2) : '',
    );

    _selectedRepeat = item != null
        ? RepeatType.values.firstWhere(
            (r) => r.name == item.frequency,
            orElse: () => RepeatType.monthly,
          )
        : RepeatType.monthly;

    _dueDate = item?.dueDate ?? DateTime.now().add(const Duration(days: 3));
    _selectedCategoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          9,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final amountPaise = (amount * 100).round();
    final repo = ref.read(reminderRepositoryProvider);

    try {
      if (widget.reminderToEdit == null) {
        await repo.insertReminder(
          title: _titleController.text.trim(),
          amountPaise: amountPaise,
          dueDate: _dueDate,
          frequency: _selectedRepeat.name,
          categoryId: _selectedCategoryId,
        );
      } else {
        await repo.updateStatus(widget.reminderToEdit!.id, widget.reminderToEdit!.isCompleted);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You\'re offline. Reconnect to continue. ($e)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.reminderToEdit == null ? 'Add Reminder' : 'Edit Reminder',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  hintText: 'e.g. Credit Card Bill, Rent, Loan EMI',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter reminder title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Amount',
                  hintText: '0.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter an amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Enter valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormatter.formatShortDate(_dueDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<RepeatType>(
                      initialValue: _selectedRepeat,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: RepeatType.values.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRepeat = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String?>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category (Optional)',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None')),
                    ...categories.map(
                      (cat) => DropdownMenuItem<String?>(
                        value: cat.id,
                        child: Row(
                          children: [
                            CategoryIconWidget(
                              iconName: cat.icon,
                              colorValue: cat.color,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Text(cat.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) => setState(() => _selectedCategoryId = id),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const SizedBox(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.reminderToEdit == null ? 'Create Reminder' : 'Update Reminder',
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
