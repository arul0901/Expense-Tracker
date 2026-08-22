import 'room_member_model.dart';

enum MemberDueStatus {
  paid,
  partiallyPaid,
  due,
  receivable,
  unassigned,
}

class MemberFinancialSummary {
  final RoomMemberModel member;
  final int totalDuesPaise; // Total assigned share of room expenses
  final int totalPaidPaise; // Amount paid directly for expenses + settlements paid
  final int netBalancePaise; // Positive = receivable/overpaid, Negative = owes, 0 = settled

  MemberFinancialSummary({
    required this.member,
    required this.totalDuesPaise,
    required this.totalPaidPaise,
    required this.netBalancePaise,
  });

  double get totalDuesRupees => totalDuesPaise / 100.0;
  double get totalPaidRupees => totalPaidPaise / 100.0;
  double get netBalanceRupees => netBalancePaise / 100.0;

  /// Absolute amount owed if member is in debt, otherwise 0.0
  double get oweRupees => netBalancePaise < 0 ? (-netBalancePaise / 100.0) : 0.0;

  /// Absolute receivable amount if group owes this member, otherwise 0.0
  double get receivableRupees => netBalancePaise > 0 ? (netBalancePaise / 100.0) : 0.0;

  bool get isOwed => netBalancePaise > 0;
  bool get isOwes => netBalancePaise < 0;
  bool get isSettled => netBalancePaise == 0;

  MemberDueStatus get status {
    if (totalDuesPaise == 0 && totalPaidPaise == 0 && netBalancePaise == 0) {
      return MemberDueStatus.unassigned;
    }
    if (netBalancePaise > 0) {
      return MemberDueStatus.receivable;
    }
    if (netBalancePaise == 0) {
      return MemberDueStatus.paid;
    }
    if (totalPaidPaise > 0 && netBalancePaise < 0) {
      return MemberDueStatus.partiallyPaid;
    }
    return MemberDueStatus.due;
  }

  String get statusLabel {
    switch (status) {
      case MemberDueStatus.paid:
        return 'Paid';
      case MemberDueStatus.partiallyPaid:
        return 'Partially Paid';
      case MemberDueStatus.due:
        return 'Due';
      case MemberDueStatus.receivable:
        return 'Receivable';
      case MemberDueStatus.unassigned:
        return 'No Expenses';
    }
  }
}
