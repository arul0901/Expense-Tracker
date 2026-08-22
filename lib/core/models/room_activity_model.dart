class RoomActivityModel {
  final String id;
  final String roomId;
  final String? userId;
  final String memberName;
  final String actionType;
  final String details;
  final DateTime createdAt;

  RoomActivityModel({
    required this.id,
    required this.roomId,
    this.userId,
    required this.memberName,
    required this.actionType,
    required this.details,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RoomActivityModel.fromMap(Map<String, dynamic> map) {
    return RoomActivityModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      memberName: map['member_name'] as String? ?? 'Member',
      actionType: map['action_type'] as String? ?? (map['type'] as String? ?? 'activity'),
      details: map['details'] as String? ?? (map['description'] as String? ?? ''),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'user_id': userId,
      'member_name': memberName,
      'action_type': actionType,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
