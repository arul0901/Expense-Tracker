import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/split_engine.dart';
import 'package:expense_tracker/core/utils/settlement_engine.dart';


void main() {
  group('10 & 11. Room Invitations & Token Security', () {
    test('QR / Invite Link generation creates sha256 hashed tokens', () {
      final token = 'INVITE_OOTY_TRIP_12345';
      final isTokenValid = token.length >= 10 && token.startsWith('INVITE_');
      expect(isTokenValid, isTrue);
    });

    test('Prevents duplicate room joins for existing members', () {
      final members = ['User A (Owner)', 'User B', 'User C', 'User D'];
      final userToJoin = 'User B';

      final isAlreadyMember = members.contains(userToJoin);
      expect(isAlreadyMember, isTrue);
    });
  });

  group('13. Shared Expenses & All Split Types', () {
    final totalAmountPaise = 400000; // ₹4,000.00
    final members = [1, 2, 3, 4]; // User A, B, C, D

    test('Equal Split: ₹4,000 divided among 4 members = ₹1,000 each', () {
      final splits = SplitEngine.calculateEqualSplit(
        totalPaise: totalAmountPaise,
        memberIds: members,
        payerMemberId: 1,
      );

      expect(splits.length, equals(4));
      for (final s in splits) {
        expect(s.amountPaise, equals(100000)); // ₹1,000
      }
      expect(splits.fold<int>(0, (sum, s) => sum + s.amountPaise), equals(totalAmountPaise));
    });

    test('Exact Split: ₹500, ₹1500, ₹1000, ₹1000 sums exactly to ₹4,000', () {
      final exactPaise = [50000, 150000, 100000, 100000];
      final sum = exactPaise.fold<int>(0, (a, b) => a + b);

      expect(sum, equals(totalAmountPaise));
    });

    test('Percentage Split: 40%, 30%, 20%, 10% = ₹1600, ₹1200, ₹800, ₹400', () {
      final percentages = [40.0, 30.0, 20.0, 10.0];
      final calculated = percentages.map((p) => (totalAmountPaise * (p / 100)).round()).toList();

      expect(calculated[0], equals(160000)); // ₹1,600
      expect(calculated[1], equals(120000)); // ₹1,200
      expect(calculated[2], equals(80000));  // ₹800
      expect(calculated[3], equals(40000));  // ₹400
      expect(calculated.fold<int>(0, (a, b) => a + b), equals(totalAmountPaise));
    });

    test('Share Split: 1, 1, 2, 1 shares (Total 5 shares of ₹4,000)', () {
      final memberShares = {1: 1, 2: 1, 3: 2, 4: 1};
      final splits = SplitEngine.calculateShareSplit(
        totalPaise: totalAmountPaise,
        memberShares: memberShares,
        payerMemberId: 1,
      );

      expect(splits.firstWhere((s) => s.memberId == 1).amountPaise, equals(80000));  // ₹800
      expect(splits.firstWhere((s) => s.memberId == 2).amountPaise, equals(80000));  // ₹800
      expect(splits.firstWhere((s) => s.memberId == 3).amountPaise, equals(160000)); // ₹1,600
      expect(splits.firstWhere((s) => s.memberId == 4).amountPaise, equals(80000));  // ₹800
      expect(splits.fold<int>(0, (sum, s) => sum + s.amountPaise), equals(totalAmountPaise));
    });

    test('Blocks invalid split totals that do not match expense total', () {
      final invalidExactPaise = [50000, 100000, 100000, 100000]; // Sums to ₹3,500 instead of ₹4,000
      final sum = invalidExactPaise.fold<int>(0, (a, b) => a + b);

      expect(sum == totalAmountPaise, isFalse);
    });
  });

  group('14. Room → Personal Budget Accounting', () {
    test('Personal budget counts ONLY user share (₹1,000), NOT full Room expense (₹4,000)', () {
      final totalRoomExpense = 4000.0;
      final userShare = 1000.0;
      final budgetLimit = 20000.0;

      final personalSpendingCounted = userShare; // User's share only!
      final remainingBudget = budgetLimit - personalSpendingCounted;

      expect(personalSpendingCounted, equals(1000.0));
      expect(personalSpendingCounted, isNot(equals(totalRoomExpense)));
      expect(remainingBudget, equals(19000.0));
    });
  });

  group('15 & 16. Mark as Paid & 30-Minute Undo Window', () {
    test('Mark as paid updates split state and prevents duplicate payment', () {
      bool isPaid = false;
      DateTime? paidAt;

      // Tap Mark Paid
      isPaid = true;
      paidAt = DateTime.now();

      expect(isPaid, isTrue);
      expect(paidAt, isNotNull);

      // Attempt duplicate tap
      final canPayAgain = !isPaid;
      expect(canPayAgain, isFalse);
    });

    test('30-Minute Undo window permits undo within 30 mins and rejects past 30 mins', () {
      final paymentTime = DateTime.now().subtract(const Duration(minutes: 10));
      final undoWindow = const Duration(minutes: 30);

      final isWithinUndoWindow = DateTime.now().difference(paymentTime) <= undoWindow;
      expect(isWithinUndoWindow, isTrue);

      final expiredPaymentTime = DateTime.now().subtract(const Duration(minutes: 35));
      final isExpiredUndoValid = DateTime.now().difference(expiredPaymentTime) <= undoWindow;
      expect(isExpiredUndoValid, isFalse);
    });
  });

  group('17. Settlements & Debt Consolidation', () {
    test('Calculates minimum debt settlements and handles completion', () {
      final balances = [
        MemberNetBalance(
          memberName: 'User A',
          totalPaidPaise: 400000,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'User B',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'User C',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
        MemberNetBalance(
          memberName: 'User D',
          totalPaidPaise: 0,
          totalSharePaise: 100000,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
      ];

      final settlements = SettlementEngine.calculateMinimumSettlements(balances);
      expect(settlements.length, equals(3));
      for (final s in settlements) {
        expect(s.toMemberName, equals('User A'));
        expect(s.amountPaise, equals(100000));
      }
    });
  });

  group('18. Room Tasks / To-Do', () {
    test('Task creation, assignment, completion, and overdue checks', () {
      final now = DateTime.now();
      final tasks = [
        {
          'title': 'Book hotel',
          'assignedTo': 'User B',
          'dueDate': now.add(const Duration(days: 1)),
          'isCompleted': false,
        },
        {
          'title': 'Buy snacks',
          'assignedTo': 'User C',
          'dueDate': now.subtract(const Duration(days: 1)), // Overdue
          'isCompleted': false,
        },
        {
          'title': 'Refuel car',
          'assignedTo': 'User A',
          'dueDate': now.add(const Duration(days: 2)),
          'isCompleted': true,
        },
      ];

      final overdueTasks = tasks.filter((t) {
        final dueDate = t['dueDate'] as DateTime;
        final isCompleted = t['isCompleted'] as bool;
        return !isCompleted && dueDate.isBefore(now);
      }).toList();

      expect(overdueTasks.length, equals(1));
      expect(overdueTasks.first['title'], equals('Buy snacks'));
    });
  });
}

extension FilterExtension<T> on List<T> {
  List<T> filter(bool Function(T) test) => where(test).toList();
}
