import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/room_member_model.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';

class CreateEditTaskSheet extends ConsumerStatefulWidget {
  final String? roomId;
  final List<RoomMemberModel>? roomMembers;

  const CreateEditTaskSheet({
    super.key,
    this.roomId,
    this.roomMembers,
  });

  @override
  ConsumerState<CreateEditTaskSheet> createState() => _CreateEditTaskSheetState();
}

class _CreateEditTaskSheetState extends ConsumerState<CreateEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedAssignedUserId;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  String _priority = 'Normal';
  final int _reminderMinutes = 60;

  final List<String> _priorities = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDueTime ?? TimeOfDay.now(),
      );

      if (mounted) {
        setState(() {
          _selectedDueDate = pickedDate;
          if (pickedTime != null) {
            _selectedDueTime = pickedTime;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedbackUtil.mediumImpact();

    DateTime? dueDateTime;
    if (_selectedDueDate != null) {
      final time = _selectedDueTime ?? const TimeOfDay(hour: 12, minute: 0);
      dueDateTime = DateTime(
        _selectedDueDate!.year,
        _selectedDueDate!.month,
        _selectedDueDate!.day,
        time.hour,
        time.minute,
      );
    }

    final taskRepo = ref.read(taskRepositoryProvider);
    try {
      await taskRepo.createTask(
        roomId: widget.roomId,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        assignedToUserId: _selectedAssignedUserId,
        dueDate: dueDateTime,
        priority: _priority,
      );

      if (dueDateTime != null) {
        final notif = ref.read(notificationServiceProvider);
        final reminderTime = dueDateTime.subtract(Duration(minutes: _reminderMinutes));
        await notif.scheduleReminderNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🔔 Task Due: ${_titleController.text.trim()}',
          body: 'Task is due at ${DateFormat('hh:mm a').format(dueDateTime)}',
          scheduledDate: reminderTime,
        );
      }

      if (mounted) {
        Navigator.pop(context);
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
    final members = widget.roomMembers ?? [];

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
                  Text('Add Room Task', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'e.g. Refuel car, Book hotel, Buy snacks',
                  prefixIcon: Icon(Icons.task_alt),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter task title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional details or instructions',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),
              if (members.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedAssignedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Assign To',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ...members.map((m) => DropdownMenuItem<String?>(value: m.userId, child: Text(m.name))),
                  ],
                  onChanged: (id) => setState(() => _selectedAssignedUserId = id),
                ),
                const SizedBox(height: 16),
              ],
              Text('Priority', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: _priorities.map((p) {
                  final isSelected = p == _priority;
                  Color color = Colors.grey;
                  if (p == 'High') color = Colors.orange;
                  if (p == 'Urgent') color = AppColors.expense;
                  if (p == 'Normal') color = Colors.blue;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p, style: TextStyle(color: isSelected ? Colors.white : null, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: color,
                        onSelected: (selected) {
                          if (selected) setState(() => _priority = p);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: AppColors.income),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDueDate == null
                              ? 'Set Due Date & Time'
                              : 'Due: ${DateFormat('dd MMM yyyy').format(_selectedDueDate!)} ${_selectedDueTime != null ? _selectedDueTime!.format(context) : ''}',
                          style: TextStyle(
                            fontWeight: _selectedDueDate == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_selectedDueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _selectedDueDate = null;
                            _selectedDueTime = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Add Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
