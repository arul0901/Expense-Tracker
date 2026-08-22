class RoomMemberModel {
  final String id;
  final String roomId;
  final String? userId;
  final String name;
  final String role; // 'Owner', 'Admin', 'Member'
  final int avatarColor;
  final bool isCurrentUser;
  final bool isActive;
  final DateTime joinedAt;

  RoomMemberModel({
    required this.id,
    required this.roomId,
    this.userId,
    required this.name,
    this.role = 'Member',
    this.avatarColor = 0xFF3B82F6,
    this.isCurrentUser = false,
    this.isActive = true,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  factory RoomMemberModel.fromMap(Map<String, dynamic> map, {String? activeUserId}) {
    final uId = map['user_id']?.toString();
    final isCurr = map['is_current_user'] as bool? ?? (uId != null && uId == activeUserId);

    return RoomMemberModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      userId: uId,
      name: map['member_name'] as String? ?? (map['name'] as String? ?? 'Member'),
      role: map['role'] as String? ?? 'Member',
      avatarColor: (map['avatar_color'] as num?)?.toInt() ?? 0xFF3B82F6,
      isCurrentUser: isCurr,
      isActive: map['is_active'] as bool? ?? true,
      joinedAt: map['joined_at'] != null ? DateTime.tryParse(map['joined_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'user_id': userId,
      'member_name': name,
      'role': role,
      'avatar_color': avatarColor,
      'is_active': isActive,
      'joined_at': joinedAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
