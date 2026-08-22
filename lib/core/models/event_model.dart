class EventModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final int budgetPaise;
  final String status; // 'Upcoming', 'Active', 'Completed'
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.budgetPaise = 0,
    this.status = 'Upcoming',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get budgetRupees => budgetPaise / 100.0;

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title'] as String? ?? (map['name'] as String? ?? ''),
      description: map['description'] as String?,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date'].toString()) ?? DateTime.now() : DateTime.now(),
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'].toString()) : null,
      budgetPaise: (map['budget_paise'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'Upcoming',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'budget_paise': budgetPaise,
      'status': status,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
