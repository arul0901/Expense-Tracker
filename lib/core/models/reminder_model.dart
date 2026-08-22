import 'category_model.dart';

class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final int amountPaise;
  final DateTime dueDate;
  final String frequency; // 'one_time', 'monthly', 'weekly'
  final bool isCompleted;
  final String? categoryId;
  final DateTime createdAt;
  final CategoryModel? category;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amountPaise,
    required this.dueDate,
    this.frequency = 'one_time',
    this.isCompleted = false,
    this.categoryId,
    DateTime? createdAt,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  double get amountRupees => amountPaise / 100.0;

  factory ReminderModel.fromMap(Map<String, dynamic> map, {CategoryModel? category}) {
    return ReminderModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title'] as String? ?? '',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) ?? DateTime.now() : DateTime.now(),
      frequency: map['frequency'] as String? ?? 'one_time',
      isCompleted: map['is_completed'] as bool? ?? false,
      categoryId: map['category_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      category: category ?? (map['categories'] != null ? CategoryModel.fromMap(map['categories'] as Map<String, dynamic>) : null),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount_paise': amountPaise,
      'due_date': dueDate.toIso8601String(),
      'frequency': frequency,
      'is_completed': isCompleted,
      'category_id': categoryId,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
