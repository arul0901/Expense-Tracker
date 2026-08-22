import 'package:flutter/material.dart';

import '../core/enums/app_enums.dart';

class FilterBottomSheet extends StatefulWidget {
  final TransactionType? initialType;
  final Function(TransactionType? type) onApply;

  const FilterBottomSheet({
    super.key,
    this.initialType,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late TransactionType? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Transactions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All Types'),
                selected: _selectedType == null,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedType = null);
                },
              ),
              ChoiceChip(
                label: const Text('Expenses'),
                selected: _selectedType == TransactionType.expense,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedType = TransactionType.expense);
                },
              ),
              ChoiceChip(
                label: const Text('Income'),
                selected: _selectedType == TransactionType.income,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedType = TransactionType.income);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.onApply(_selectedType);
              Navigator.pop(context);
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}
