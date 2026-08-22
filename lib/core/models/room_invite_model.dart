class RoomInviteModel {
  final String id;
  final String roomId;
  final String token;
  final String? createdBy;
  final String role;
  final String state; // 'Active', 'Revoked', 'Expired'
  final DateTime expiresAt;
  final DateTime createdAt;

  RoomInviteModel({
    required this.id,
    required this.roomId,
    required this.token,
    this.createdBy,
    this.role = 'Member',
    this.state = 'Active',
    required this.expiresAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RoomInviteModel.fromMap(Map<String, dynamic> map) {
    return RoomInviteModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      token: map['token_hash'] as String? ?? (map['token'] as String? ?? ''),
      createdBy: map['created_by']?.toString(),
      role: map['role'] as String? ?? 'Member',
      state: map['state'] as String? ?? 'Active',
      expiresAt: map['expires_at'] != null ? DateTime.tryParse(map['expires_at'].toString()) ?? DateTime.now() : DateTime.now(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'token_hash': token,
      'created_by': createdBy,
      'role': role,
      'state': state,
      'expires_at': expiresAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
