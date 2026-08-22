class RoomModel {
  final String id;
  final String createdBy;
  final String name;
  final String? description;
  final String type; // 'Trip', 'Flat', 'Friends', 'Family', 'Event', 'Other'
  final int colorAccent;
  final String currency;
  final bool paymentRemindersEnabled;
  final bool taskRemindersEnabled;
  final int reminderAfterDays;
  final String? eventId;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.createdBy,
    required this.name,
    this.description,
    this.type = 'Trip',
    this.colorAccent = 0xFF0D9488,
    this.currency = '₹ INR',
    this.paymentRemindersEnabled = true,
    this.taskRemindersEnabled = true,
    this.reminderAfterDays = 3,
    this.eventId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      name: map['name'] as String? ?? 'Shared Room',
      description: map['description'] as String?,
      type: map['type'] as String? ?? 'Trip',
      colorAccent: (map['color_accent'] as num?)?.toInt() ?? 0xFF0D9488,
      currency: map['currency'] as String? ?? '₹ INR',
      paymentRemindersEnabled: map['payment_reminders_enabled'] as bool? ?? true,
      taskRemindersEnabled: map['task_reminders_enabled'] as bool? ?? true,
      reminderAfterDays: (map['reminder_after_days'] as num?)?.toInt() ?? 3,
      eventId: map['event_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'created_by': createdBy,
      'name': name,
      'description': description,
      'type': type,
      'color_accent': colorAccent,
      'currency': currency,
      'payment_reminders_enabled': paymentRemindersEnabled,
      'task_reminders_enabled': taskRemindersEnabled,
      'reminder_after_days': reminderAfterDays,
      'event_id': eventId,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
