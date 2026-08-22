class ExpenseSplitModel {
  final String id;
  final String roomExpenseId;
  final String? userId;
  final String memberName;
  final int amountPaise;
  final double? percentage;
  final int? shares;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime? undoExpiresAt;
  final DateTime? undoneAt;
  final String? undoneBy;

  ExpenseSplitModel({
    required this.id,
    required this.roomExpenseId,
    this.userId,
    required this.memberName,
    required this.amountPaise,
    this.percentage,
    this.shares,
    this.isPaid = false,
    this.paidAt,
    this.undoExpiresAt,
    this.undoneAt,
    this.undoneBy,
  });

  double get amountRupees => amountPaise / 100.0;

  bool get canUndo {
    if (!isPaid || undoExpiresAt == null) return false;
    return DateTime.now().isBefore(undoExpiresAt!);
  }

  factory ExpenseSplitModel.fromMap(Map<String, dynamic> map) {
    return ExpenseSplitModel(
      id: map['id']?.toString() ?? '',
      roomExpenseId: map['room_expense_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      memberName: map['member_name'] as String? ?? 'Member',
      amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble(),
      shares: (map['shares'] as num?)?.toInt(),
      isPaid: map['is_paid'] as bool? ?? false,
      paidAt: map['paid_at'] != null ? DateTime.tryParse(map['paid_at'].toString()) : null,
      undoExpiresAt: map['undo_expires_at'] != null ? DateTime.tryParse(map['undo_expires_at'].toString()) : null,
      undoneAt: map['undone_at'] != null ? DateTime.tryParse(map['undone_at'].toString()) : null,
      undoneBy: map['undone_by']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'room_expense_id': roomExpenseId,
      'user_id': userId,
      'member_name': memberName,
      'amount_paise': amountPaise,
      'percentage': percentage,
      'shares': shares,
      'is_paid': isPaid,
      'paid_at': paidAt?.toIso8601String(),
      'undo_expires_at': undoExpiresAt?.toIso8601String(),
      'undone_at': undoneAt?.toIso8601String(),
      'undone_by': undoneBy,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }
}
