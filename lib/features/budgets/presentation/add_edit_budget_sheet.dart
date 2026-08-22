import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/budget_model.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/category_icon_widget.dart';

class AddEditBudgetSheet extends ConsumerStatefulWidget {
  final BudgetModel? budgetToEdit;

  const AddEditBudgetSheet({
    super.key,
    this.budgetToEdit,
  });

  @override
  ConsumerState<AddEditBudgetSheet> createState() => _AddEditBudgetSheetState();
}

class _AddEditBudgetSheetState extends ConsumerState<AddEditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _amountController;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final item = widget.budgetToEdit;
    _nameController = TextEditingController(text: item?.category?.name ?? 'Monthly Budget');
    _amountController = TextEditingController(
      text: item != null ? item.limitRupees.toStringAsFixed(0) : '',
    );
    _selectedCategoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final amountPaise = (amount * 100).round();
    final now = DateTime.now();
    final repo = ref.read(budgetRepositoryProvider);

    try {
      await repo.insertOrUpdateBudget(
        id: widget.budgetToEdit?.id,
        categoryId: _selectedCategoryId,
        amountPaise: amountPaise,
        month: now.month,
        year: now.year,
      );

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.budgetToEdit == null ? 'Set Budget' : 'Edit Budget',
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Budget Name',
                hintText: 'e.g. Total Monthly Budget, Food Limit',
                prefixIcon: Icon(Icons.label_outlined),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter budget name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Target Limit Amount',
                hintText: '5000',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter budget limit';
                final parsed = double.tryParse(val);
                if (parsed == null || parsed <= 0) return 'Enter valid limit > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String?>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Scope / Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Overall Monthly Budget (All Expenses)'),
                  ),
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
                widget.budgetToEdit == null ? 'Create Budget' : 'Save Budget',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
