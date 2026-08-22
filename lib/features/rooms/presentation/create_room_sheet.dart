import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/auth/providers/auth_provider.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/sign_in_required_dialog.dart';

class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'Trip';
  int _selectedColorAccent = 0xFF0D9488;
  final String _currency = '₹ INR';
  bool _paymentRemindersEnabled = true;
  bool _taskRemindersEnabled = true;
  final int _reminderAfterDays = 3;
  String? _selectedEventId;

  final List<String> _initialMemberNames = [];
  final _memberInputController = TextEditingController();

  final List<String> _roomTypes = ['Trip', 'Flat', 'Friends', 'Family', 'Event', 'Other'];
  final List<int> _colorAccents = [
    0xFF0D9488,
    0xFF3B82F6,
    0xFF8B5CF6,
    0xFF10B981,
    0xFFEF4444,
    0xFFF59E0B,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberInputController.dispose();
    super.dispose();
  }

  void _addMemberName() {
    final name = _memberInputController.text.trim();
    if (name.isNotEmpty && !_initialMemberNames.contains(name)) {
      HapticFeedbackUtil.selectionClick();
      setState(() {
        _initialMemberNames.add(name);
        _memberInputController.clear();
      });
    }
  }

  bool _isSubmitting = false;

  void _removeMemberName(String name) {
    HapticFeedbackUtil.selectionClick();
    setState(() {
      _initialMemberNames.remove(name);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated && isAnonymousUser()) {
      showSignInRequiredDialog(
        context,
        message: 'Please sign in first to create a room workspace.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    HapticFeedbackUtil.mediumImpact();

    setState(() => _isSubmitting = true);

    final roomRepo = ref.read(roomRepositoryProvider);
    try {
      final roomId = await roomRepo.createRoom(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        type: _selectedType,
        colorAccent: _selectedColorAccent,
        currency: _currency,
        paymentRemindersEnabled: _paymentRemindersEnabled,
        taskRemindersEnabled: _taskRemindersEnabled,
        reminderAfterDays: _reminderAfterDays,
        eventId: _selectedEventId,
        memberNames: _initialMemberNames,
      );

      if (mounted) {
        Navigator.of(context).pop(roomId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(allEventsProvider);

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
                  Text('Create Room', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                  labelText: 'Room Name',
                  hintText: 'e.g. Ooty Trip, Flatmates, Goa Vacation',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter room name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Shared expenses & tasks workspace',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),
              Text('Room Type', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _roomTypes.map((type) {
                  final isSelected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedType = type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Theme Color Accent', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: _colorAccents.map((colorHex) {
                  final isSelected = colorHex == _selectedColorAccent;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorAccent = colorHex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(colorHex),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: theme.textTheme.bodyLarge?.color ?? Colors.black, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              eventsAsync.maybeWhen(
                data: (events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedEventId,
                    decoration: const InputDecoration(
                      labelText: 'Link to Event (Optional)',
                      prefixIcon: Icon(Icons.event),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No linked event')),
                      ...events.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.title))),
                    ],
                    onChanged: (id) => setState(() => _selectedEventId = id),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text('Add Initial Members', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberInputController,
                      decoration: const InputDecoration(
                        hintText: 'Member name (e.g. Rahul)',
                        prefixIcon: Icon(Icons.person_add_outlined),
                      ),
                      onSubmitted: (_) => _addMemberName(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addMemberName,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_initialMemberNames.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _initialMemberNames.map((name) {
                    return Chip(
                      label: Text(name),
                      onDeleted: () => _removeMemberName(name),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  title: const Text('Room Settings & Reminders'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    SwitchListTile(
                      title: const Text('Payment Reminders'),
                      subtitle: const Text('Notify unpaid members after threshold'),
                      value: _paymentRemindersEnabled,
                      onChanged: (v) => setState(() => _paymentRemindersEnabled = v),
                    ),
                    SwitchListTile(
                      title: const Text('Task Reminders'),
                      subtitle: const Text('Notify members when tasks are due'),
                      value: _taskRemindersEnabled,
                      onChanged: (v) => setState(() => _taskRemindersEnabled = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Color(_selectedColorAccent),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create Room Workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
