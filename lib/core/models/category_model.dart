class CategoryModel {
  final String id;
  final String? userId;
  final String name;
  final String icon;
  final int color;
  final String type; // 'income' | 'expense'
  final bool isSystem;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isSystem = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name'] as String? ?? 'General',
      icon: map['icon'] as String? ?? 'category',
      color: (map['color'] as num?)?.toInt() ?? 0xFF0D9488,
      type: map['type'] as String? ?? 'expense',
      isSystem: map['is_system'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'is_system': isSystem,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
