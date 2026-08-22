import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/event_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/app_providers.dart';

class AddEditEventSheet extends ConsumerStatefulWidget {
  final EventModel? eventToEdit;

  const AddEditEventSheet({
    super.key,
    this.eventToEdit,
  });

  @override
  ConsumerState<AddEditEventSheet> createState() => _AddEditEventSheetState();
}

class _AddEditEventSheetState extends ConsumerState<AddEditEventSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;

  late DateTime _startDate;
  late DateTime _endDate;
  bool _createRoom = true;
  final List<TextEditingController> _memberControllers = [
    TextEditingController(text: 'Rahul'),
    TextEditingController(text: 'Karthik'),
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.eventToEdit;

    _nameController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _budgetController = TextEditingController(
      text: item != null ? item.budgetRupees.toStringAsFixed(0) : '',
    );

    _startDate = item?.startDate ?? DateTime.now();
    _endDate = item?.endDate ?? DateTime.now().add(const Duration(days: 4));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    for (final c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _save() async {

    if (!_formKey.currentState!.validate()) return;

    final budget = double.tryParse(_budgetController.text) ?? 0.0;
    final budgetPaise = (budget * 100).round();
    final eventRepo = ref.read(eventRepositoryProvider);
    final roomRepo = ref.read(roomRepositoryProvider);

    try {
      if (widget.eventToEdit == null) {
        final createdEvent = await eventRepo.insertEvent(
          title: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          budgetPaise: budgetPaise,
          status: 'active',
        );

        if (_createRoom) {
          final memberNames = _memberControllers
              .map((c) => c.text.trim())
              .where((n) => n.isNotEmpty)
              .toList();

          await roomRepo.createRoom(
            name: '${_nameController.text.trim()} Room',
            eventId: createdEvent.id,
            memberNames: memberNames,
          );
        }
      } else {
        await eventRepo.updateEvent(
          EventModel(
            id: widget.eventToEdit!.id,
            userId: widget.eventToEdit!.userId,
            title: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            budgetPaise: budgetPaise,
            status: widget.eventToEdit!.status,
          ),
        );
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
                    widget.eventToEdit == null ? 'Create Event' : 'Edit Event',
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
                  labelText: 'Event Name',
                  hintText: 'e.g. Ooty Trip, Wedding, Birthday Party',
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter event name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Total Event Budget Limit',
                  hintText: '25000',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(DateFormatter.formatShortDate(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(DateFormatter.formatShortDate(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),

              if (widget.eventToEdit == null) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Create Expense Splitting Room?'),
                  subtitle: const Text('Split hotel, food, fuel & tickets with friends'),
                  value: _createRoom,
                  onChanged: (val) => setState(() => _createRoom = val),
                ),
                if (_createRoom) ...[
                  const SizedBox(height: 8),
                  Text('Room Members (including You)', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  ..._memberControllers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Member #${idx + 1}',
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _memberControllers.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _memberControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Member'),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.eventToEdit == null ? 'Create Event' : 'Save Event',
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
