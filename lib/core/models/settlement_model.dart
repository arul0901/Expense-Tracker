class SettlementModel {
  final String id;
  final String roomId;
  final String? fromUserId;
  final String? toUserId;
  final String fromMemberName;
  final String toMemberName;
  final int amountPaise;
  final DateTime settledAt;
  final String? note;
  final DateTime? undoExpiresAt;
  final DateTime? undoneAt;
  final String? undoneBy;

  SettlementModel({
    required this.id,
    required this.roomId,
    this.fromUserId,
    this.toUserId,
    required this.fromMemberName,
    required this.toMemberName,
    required this.amountPaise,
    DateTime? settledAt,
    this.note,
    this.undoExpiresAt,
    this.undoneAt,
    this.undoneBy,
  }) : settledAt = settledAt ?? DateTime.now();

  double get amountRupees => amountPaise / 100.0;

  bool get canUndo {
    if (undoneAt != null) return false;
    final expires = undoExpiresAt ?? settledAt.add(const Duration(minutes: 30));
    return DateTime.now().isBefore(expires);
  }

  factory SettlementModel.fromMap(Map<String, dynamic> map) {
    final sAt = map['settled_at'] != null ? DateTime.tryParse(map['settled_at'].toString()) ?? DateTime.now() : DateTime.now();

    return SettlementModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      fromUserId: map['from_user_id']?.toString(),
      toUserId: map['to_user_id']?.toString(),
      fromMemberName: map['from_member_name'] as String? ?? 'Member',
      toMemberName: map['to_member_name'] as String? ?? 'Member',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      settledAt: sAt,
      note: map['note'] as String?,
      undoExpiresAt: map['undo_expires_at'] != null ? DateTime.tryParse(map['undo_expires_at'].toString()) : sAt.add(const Duration(minutes: 30)),
      undoneAt: map['undone_at'] != null ? DateTime.tryParse(map['undone_at'].toString()) : null,
      undoneBy: map['undone_by']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_id': roomId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'from_member_name': fromMemberName,
      'to_member_name': toMemberName,
      'amount_paise': amountPaise,
      'settled_at': settledAt.toIso8601String(),
      'note': note,
      'undo_expires_at': undoExpiresAt?.toIso8601String() ?? settledAt.add(const Duration(minutes: 30)).toIso8601String(),
      'undone_at': undoneAt?.toIso8601String(),
      'undone_by': undoneBy,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
