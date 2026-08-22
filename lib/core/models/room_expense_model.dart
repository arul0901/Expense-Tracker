import 'category_model.dart';

class RoomExpenseModel {
  final String id;
  final String roomId;
  final String? paidByUserId;
  final String paidByMemberName;
  final int amountPaise;
  final String description;
  final DateTime date;
  final String splitType; // 'equal', 'percentage', 'exact', 'shares'
  final String? categoryId;
  final String? notes;
  final DateTime createdAt;
  final CategoryModel? category;

  RoomExpenseModel({
    required this.id,
    required this.roomId,
    this.paidByUserId,
    required this.paidByMemberName,
    required this.amountPaise,
    required this.description,
    required this.date,
    this.splitType = 'equal',
    this.categoryId,
    this.notes,
    DateTime? createdAt,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  double get amountRupees => amountPaise / 100.0;

  factory RoomExpenseModel.fromMap(Map<String, dynamic> map, {CategoryModel? category}) {
    return RoomExpenseModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      paidByUserId: map['paid_by_user_id']?.toString(),
      paidByMemberName: map['paid_by_member_name'] as String? ?? 'Member',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      description: map['description'] as String? ?? 'Expense',
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
      splitType: map['split_type'] as String? ?? 'equal',
      categoryId: map['category_id']?.toString(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      category: category ?? (map['categories'] != null ? CategoryModel.fromMap(map['categories'] as Map<String, dynamic>) : null),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'paid_by_user_id': paidByUserId,
      'paid_by_member_name': paidByMemberName,
      'amount_paise': amountPaise,
      'description': description,
      'date': date.toIso8601String(),
      'split_type': splitType,
      'category_id': categoryId,
      'notes': notes,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
