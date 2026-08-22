import 'category_model.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String? categoryId;
  final int amountLimitPaise;
  final int month;
  final int year;
  final DateTime createdAt;
  final CategoryModel? category;

  BudgetModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.amountLimitPaise,
    required this.month,
    required this.year,
    DateTime? createdAt,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  double get limitRupees => amountLimitPaise / 100.0;

  factory BudgetModel.fromMap(Map<String, dynamic> map, {CategoryModel? category}) {
    return BudgetModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      categoryId: map['category_id']?.toString(),
      amountLimitPaise: (map['amount_limit_paise'] as num?)?.toInt() ?? 0,
      month: (map['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      category: category ?? (map['categories'] != null ? CategoryModel.fromMap(map['categories'] as Map<String, dynamic>) : null),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'user_id': userId,
      'category_id': categoryId,
      'amount_limit_paise': amountLimitPaise,
      'month': month,
      'year': year,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
