import 'category_model.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'income' | 'expense'
  final int amountPaise;
  final String? categoryId;
  final DateTime date;
  final String? note;
  final String paymentMethod;
  final String? eventId;
  final String? roomId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CategoryModel? category;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amountPaise,
    this.categoryId,
    required this.date,
    this.note,
    this.paymentMethod = 'upi',
    this.eventId,
    this.roomId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.category,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get amountRupees => amountPaise / 100.0;

  factory TransactionModel.fromMap(Map<String, dynamic> map, {CategoryModel? category}) {
    return TransactionModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type'] as String? ?? 'expense',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      categoryId: map['category_id']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
      note: map['note'] as String?,
      paymentMethod: map['payment_method'] as String? ?? 'upi',
      eventId: map['event_id']?.toString(),
      roomId: map['room_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      category: category ?? (map['categories'] != null ? CategoryModel.fromMap(map['categories'] as Map<String, dynamic>) : null),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'user_id': userId,
      'type': type,
      'amount_paise': amountPaise,
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'note': note,
      'payment_method': paymentMethod,
      'event_id': eventId,
      'room_id': roomId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
