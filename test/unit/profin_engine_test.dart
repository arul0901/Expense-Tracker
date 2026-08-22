import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/money_paise.dart';
import 'package:expense_tracker/core/utils/split_engine.dart';
import 'package:expense_tracker/core/utils/settlement_engine.dart';

void main() {
  group('MoneyPaise Precision Tests', () {
    test('Converts rupees to paise and formats cleanly', () {
      final money = MoneyPaise.fromRupees(100.50);
      expect(money.paise, equals(10050));
      expect(money.toRupees(), equals(100.50));
      expect(money.format(), contains('100.50'));
    });

    test('Performs exact integer arithmetic without float drift', () {
      final m1 = MoneyPaise.fromRupees(50.25);
      final m2 = MoneyPaise.fromRupees(49.75);
      final sum = m1 + m2;
      expect(sum.paise, equals(10000));
      expect(sum.toRupees(), equals(100.0));
    });
  });

  group('SplitEngine Tests', () {
    test('Calculates equal split with remainder paise assigned to payer', () {
      // ₹100.00 (10000 paise) split 3 ways: 3333, 3333, 3334
      final splits = SplitEngine.calculateEqualSplit(
        totalPaise: 10000,
        memberIds: [1, 2, 3],
        payerMemberId: 1,
      );

      expect(splits.length, equals(3));
      expect(splits.firstWhere((s) => s.memberId == 1).amountPaise, equals(3334));
      expect(splits.firstWhere((s) => s.memberId == 2).amountPaise, equals(3333));
      expect(splits.firstWhere((s) => s.memberId == 3).amountPaise, equals(3333));
      expect(splits.fold<int>(0, (sum, s) => sum + s.amountPaise), equals(10000));
    });

    test('Calculates share-based split correctly', () {
      // 1 share, 2 shares, 1 share (Total 4 shares of ₹4,000)
      final splits = SplitEngine.calculateShareSplit(
        totalPaise: 400000,
        memberShares: {1: 1, 2: 2, 3: 1},
        payerMemberId: 1,
      );

      expect(splits.firstWhere((s) => s.memberId == 1).amountPaise, equals(100000));
      expect(splits.firstWhere((s) => s.memberId == 2).amountPaise, equals(200000));
      expect(splits.firstWhere((s) => s.memberId == 3).amountPaise, equals(100000));
    });
  });

  group('SettlementEngine Debt Consolidation Tests', () {
    test('Calculates minimum direct settlements correctly', () {
      // Arul paid ₹4,000, share ₹1,000 -> Net +₹3,000 (Creditor)
      // Rahul share ₹1,000 -> Net -₹1,000 (Debtor)
      // Karthik share ₹1,000 -> Net -₹1,000 (Debtor)
      // Sanjay share ₹1,000 -> Net -₹1,000 (Debtor)
      final memberBalances = [
        MemberNetBalance(
          memberName: 'Arul',
          totalPaidPaise: 400000,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'Rahul',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'Karthik',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'Sanjay',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
      ];

      final suggestions = SettlementEngine.calculateMinimumSettlements(memberBalances);

      expect(suggestions.length, equals(3));
      for (final s in suggestions) {
        expect(s.toMemberName, equals('Arul')); // All pay Arul
        expect(s.amountPaise, equals(100000)); // ₹1,000 each
      }
    });
  });
}
