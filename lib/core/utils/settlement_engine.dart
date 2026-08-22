import 'dart:math';
import '../models/room_member_model.dart';
import '../models/settlement_model.dart';
import '../../repositories/room_repository.dart';

class SettlementSuggestion {
  final String fromMemberName;
  final String toMemberName;
  final int amountPaise;

  SettlementSuggestion({
    required this.fromMemberName,
    required this.toMemberName,
    required this.amountPaise,
  });
}

class MemberNetBalance {
  final String memberName;
  final int totalPaidPaise;
  final int totalSharePaise;
  final int totalSettledPaidPaise;
  final int totalSettledReceivedPaise;

  MemberNetBalance({
    required this.memberName,
    required this.totalPaidPaise,
    required this.totalSharePaise,
    required this.totalSettledPaidPaise,
    required this.totalSettledReceivedPaise,
  });

  /// Positive balance = Owed to member (Creditor)
  /// Negative balance = Member owes to room (Debtor)
  int get netBalancePaise {
    return (totalPaidPaise + totalSettledPaidPaise) - (totalSharePaise + totalSettledReceivedPaise);
  }
}

class SettlementEngine {
  /// Computes exact pairwise direct settlements between members based on actual expense splits.
  /// Guarantees that no uninvolved member pays for items consumed by another member!
  static List<SettlementSuggestion> calculatePairwiseSettlements({
    required List<RoomMemberModel> members,
    required List<ExpenseWithPayerAndSplits> expenses,
    required List<SettlementModel> settlements,
  }) {
    final pairBalances = <String, int>{}; // Key: "debtor__creditor" -> amount debtor owes creditor in paise

    String pairKey(String from, String to) => '${from.trim().toLowerCase()}__${to.trim().toLowerCase()}';

    // 1. Calculate direct debt from expense splits
    for (final expItem in expenses) {
      final payerName = expItem.expense.paidByMemberName.trim();
      if (payerName.isEmpty) continue;

      for (final split in expItem.splits) {
        if (split.isPaid) continue; // Skip splits already marked paid
        final consumerName = split.memberName.trim();
        if (consumerName.isEmpty || consumerName.toLowerCase() == payerName.toLowerCase()) {
          continue; // Payer doesn't owe themselves
        }

        // consumerName owes payerName split.amountPaise
        final key = pairKey(consumerName, payerName);
        pairBalances[key] = (pairBalances[key] ?? 0) + split.amountPaise.toInt();
      }
    }

    // 2. Subtract completed settlements
    for (final s in settlements) {
      if (s.undoneAt != null) continue;
      final key = pairKey(s.fromMemberName, s.toMemberName);
      pairBalances[key] = (pairBalances[key] ?? 0) - s.amountPaise.toInt();
    }

    // 3. Net out mutual debts between every pair of members
    final suggestions = <SettlementSuggestion>[];
    final memberNames = members.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toSet().toList();

    for (int i = 0; i < memberNames.length; i++) {
      for (int j = i + 1; j < memberNames.length; j++) {
        final nameA = memberNames[i];
        final nameB = memberNames[j];

        final keyAtoB = pairKey(nameA, nameB);
        final keyBtoA = pairKey(nameB, nameA);

        final debtAtoB = pairBalances[keyAtoB] ?? 0;
        final debtBtoA = pairBalances[keyBtoA] ?? 0;

        final netAtoB = debtAtoB - debtBtoA;

        if (netAtoB > 0) {
          suggestions.add(SettlementSuggestion(
            fromMemberName: nameA,
            toMemberName: nameB,
            amountPaise: netAtoB,
          ));
        } else if (netAtoB < 0) {
          suggestions.add(SettlementSuggestion(
            fromMemberName: nameB,
            toMemberName: nameA,
            amountPaise: -netAtoB,
          ));
        }
      }
    }

    return suggestions;
  }

  /// Global greedy consolidation algorithm fallback.
  static List<SettlementSuggestion> calculateMinimumSettlements(List<MemberNetBalance> memberBalances) {
    final creditors = <_AccountBalance>[];
    final debtors = <_AccountBalance>[];

    for (final m in memberBalances) {
      final net = m.netBalancePaise;
      if (net > 0) {
        creditors.add(_AccountBalance(m.memberName, net));
      } else if (net < 0) {
        debtors.add(_AccountBalance(m.memberName, -net));
      }
    }

    creditors.sort((a, b) => b.balance.compareTo(a.balance));
    debtors.sort((a, b) => b.balance.compareTo(a.balance));

    final suggestions = <SettlementSuggestion>[];

    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final settlementAmount = min(debtor.balance, creditor.balance);

      if (settlementAmount > 0) {
        suggestions.add(SettlementSuggestion(
          fromMemberName: debtor.memberName,
          toMemberName: creditor.memberName,
          amountPaise: settlementAmount,
        ));
      }

      debtor.balance -= settlementAmount;
      creditor.balance -= settlementAmount;

      if (debtor.balance == 0) i++;
      if (creditor.balance == 0) j++;
    }

    return suggestions;
  }
}

class _AccountBalance {
  final String memberName;
  int balance;

  _AccountBalance(this.memberName, this.balance);
}
