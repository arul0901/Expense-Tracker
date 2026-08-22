class CalculatedSplit {
  final int memberId;
  final int amountPaise;
  final double? percentage;
  final int? shares;

  CalculatedSplit({
    required this.memberId,
    required this.amountPaise,
    this.percentage,
    this.shares,
  });
}

class SplitEngine {
  /// Equal Split Engine: divides totalPaise equally among members.
  /// Handles remainder paise by assigning to the payer or first member.
  static List<CalculatedSplit> calculateEqualSplit({
    required int totalPaise,
    required List<int> memberIds,
    required int payerMemberId,
  }) {
    if (memberIds.isEmpty) return [];

    final count = memberIds.length;
    final baseAmount = totalPaise ~/ count;
    int remainder = totalPaise % count;

    final results = <CalculatedSplit>[];

    for (final memberId in memberIds) {
      int memberShare = baseAmount;
      if (remainder > 0 && memberId == payerMemberId) {
        memberShare += remainder;
        remainder = 0;
      }
      results.add(CalculatedSplit(
        memberId: memberId,
        amountPaise: memberShare,
      ));
    }

    return _ensureExactTotal(results, totalPaise, payerMemberId);
  }

  /// Percentage Split Engine: computes share based on percentage.
  static List<CalculatedSplit> calculatePercentageSplit({
    required int totalPaise,
    required Map<int, double> memberPercentages,
    required int payerMemberId,
  }) {
    final results = <CalculatedSplit>[];
    memberPercentages.forEach((memberId, percent) {
      final amount = (totalPaise * (percent / 100.0)).round();
      results.add(CalculatedSplit(
        memberId: memberId,
        amountPaise: amount,
        percentage: percent,
      ));
    });

    return _ensureExactTotal(results, totalPaise, payerMemberId);
  }

  /// Exact Amount Split Engine: verifies exact amounts sum to total.
  static List<CalculatedSplit> calculateExactSplit({
    required Map<int, int> memberExactPaise,
  }) {
    final results = <CalculatedSplit>[];
    memberExactPaise.forEach((memberId, amount) {
      results.add(CalculatedSplit(
        memberId: memberId,
        amountPaise: amount,
      ));
    });
    return results;
  }

  /// Share-based Split Engine: computes share by ratio of shares.
  static List<CalculatedSplit> calculateShareSplit({
    required int totalPaise,
    required Map<int, int> memberShares,
    required int payerMemberId,
  }) {
    final totalShares = memberShares.values.fold(0, (sum, val) => sum + val);
    if (totalShares <= 0) return [];

    final results = <CalculatedSplit>[];
    memberShares.forEach((memberId, shares) {
      final amount = ((shares / totalShares) * totalPaise).round();
      results.add(CalculatedSplit(
        memberId: memberId,
        amountPaise: amount,
        shares: shares,
      ));
    });

    return _ensureExactTotal(results, totalPaise, payerMemberId);
  }

  /// Ensures the sum of splits matches totalPaise exactly by adjusting residual rounding paise.
  static List<CalculatedSplit> _ensureExactTotal(
    List<CalculatedSplit> splits,
    int targetTotalPaise,
    int payerMemberId,
  ) {
    if (splits.isEmpty) return splits;
    final currentSum = splits.fold<int>(0, (sum, s) => sum + s.amountPaise);
    final diff = targetTotalPaise - currentSum;
    if (diff == 0) return splits;

    final targetMemberId = splits.any((s) => s.memberId == payerMemberId)
        ? payerMemberId
        : splits.first.memberId;

    return splits.map((s) {
      if (s.memberId == targetMemberId) {
        return CalculatedSplit(
          memberId: s.memberId,
          amountPaise: s.amountPaise + diff,
          percentage: s.percentage,
          shares: s.shares,
        );
      }
      return s;
    }).toList();
  }
}
