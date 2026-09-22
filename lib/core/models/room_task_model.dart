class RoomTaskModel {
  final String id;
  final String? roomId;
  final String title;
  final String? description;
  final String? assignedToUserId;
  final DateTime? dueDate;
  final String priority; // 'Normal', 'Medium', 'High', 'Urgent'
  final bool isCompleted;
  final String taskType; // 'Short Term' or 'Long Term'
  final String category; // 'General', 'Work', 'Personal', 'Shopping', 'Finance', 'Health', 'Chore', 'Urgent'
  final String? createdBy;
  final DateTime createdAt;

  RoomTaskModel({
    required this.id,
    this.roomId,
    required this.title,
    this.description,
    this.assignedToUserId,
    this.dueDate,
    this.priority = 'Medium',
    this.isCompleted = false,
    this.taskType = 'Short Term',
    this.category = 'General',
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RoomTaskModel.fromMap(Map<String, dynamic> map) {
    String? rawDesc = map['description'] as String? ?? (map['notes'] as String?);
    String parsedType = map['task_type'] as String? ?? 'Short Term';
    String parsedCat = map['category'] as String? ?? 'General';

    if (rawDesc != null && rawDesc.startsWith('[Meta: type=')) {
      final reg = RegExp(r'^\[Meta: type=(Short Term|Long Term), cat=([^\]]+)\]\s*');
      final match = reg.firstMatch(rawDesc);
      if (match != null) {
        parsedType = match.group(1) ?? parsedType;
        parsedCat = match.group(2) ?? parsedCat;
        rawDesc = rawDesc.substring(match.end).trim();
        if (rawDesc.isEmpty) rawDesc = null;
      }
    }

    return RoomTaskModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString(),
      title: map['title'] as String? ?? '',
      description: rawDesc,
      assignedToUserId: map['assigned_to_user_id']?.toString() ?? (map['assigned_member_id']?.toString()),
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      priority: map['priority'] as String? ?? 'Medium',
      isCompleted: map['is_completed'] as bool? ?? (map['status'] == 'Completed'),
      taskType: parsedType,
      category: parsedCat,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'title': title,
      'description': description,
      'assigned_to_user_id': assignedToUserId,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority,
      'is_completed': isCompleted,
      'task_type': taskType,
      'category': category,
      'created_by': createdBy,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
