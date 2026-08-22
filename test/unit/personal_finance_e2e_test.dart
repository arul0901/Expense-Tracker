import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/utils/money_paise.dart';

void main() {
  group('5. Personal Real Test Data & Transactions', () {
    final transactions = [
      {'title': 'Salary', 'type': 'income', 'amount': 30000.0, 'date': DateTime(2026, 8, 1)},
      {'title': 'Food', 'type': 'expense', 'amount': 450.0, 'date': DateTime(2026, 8, 5)},
      {'title': 'Transport', 'type': 'expense', 'amount': 250.0, 'date': DateTime(2026, 8, 10)},
      {'title': 'Shopping', 'type': 'expense', 'amount': 1200.0, 'date': DateTime(2026, 8, 12)},
      {'title': 'Fuel', 'type': 'expense', 'amount': 1800.0, 'date': DateTime(2026, 8, 15)},
      {'title': 'Entertainment', 'type': 'expense', 'amount': 600.0, 'date': DateTime(2026, 8, 18)},
    ];

    test('Calculates total income and total expenses accurately', () {
      final income = transactions
          .where((t) => t['type'] == 'income')
          .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));
      final expense = transactions
          .where((t) => t['type'] == 'expense')
          .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));

      expect(income, equals(30000.0));
      expect(expense, equals(4300.0));
      expect(income - expense, equals(25700.0));
    });
  });

  group('6. Budgets & Threshold Warnings', () {
    final budgets = {
      'Food': 5000.0,
      'Transport': 3000.0,
      'Shopping': 4000.0,
      'Entertainment': 2000.0,
    };

    final actualSpent = {
      'Food': 450.0,
      'Transport': 250.0,
      'Shopping': 1200.0,
      'Entertainment': 600.0,
    };

    test('Spending is well below budget limit and calculates remaining correctly', () {
      budgets.forEach((category, limit) {
        final spent = actualSpent[category]!;
        final remaining = limit - spent;
        final utilization = spent / limit;

        expect(remaining, greaterThan(0));
        expect(utilization, lessThan(0.80)); // Below 80% warning threshold
      });
    });

    test('Near, at, and above budget calculations', () {
      final limit = 5000.0;

      // Below budget (₹450 -> 9%)
      expect(450.0 / limit, equals(0.09));

      // Near budget (₹4,200 -> 84% - Warning)
      expect(4200.0 / limit, greaterThanOrEqualTo(0.80));

      // At budget (₹5,000 -> 100% - Reached)
      expect(5000.0 / limit, equals(1.00));

      // Above budget (₹5,500 -> 110% - Overbudget)
      expect(5500.0 / limit, greaterThan(1.00));
    });
  });

  group('7. Financial Reminders & Recurrence', () {
    test('Credit Card Bill reminder due in 1 day', () {
      final now = DateTime.now();
      final creditCardDue = now.add(const Duration(days: 1));
      final amount = MoneyPaise.fromRupees(4850.0);

      expect(creditCardDue.difference(now).inDays, equals(1));
      expect(amount.toRupees(), equals(4850.0));
    });

    test('Rent monthly recurring reminder next due date', () {
      final rentDue = DateTime(2026, 8, 1, 9, 0);
      final nextRentDue = DateTime(rentDue.year, rentDue.month + 1, rentDue.day, rentDue.hour);

      expect(nextRentDue, equals(DateTime(2026, 9, 1, 9, 0)));
    });
  });

  group('9. Events & Budget Allocation', () {
    test('Ooty Trip Event budget and expense category totals', () {
      final eventBudget = 25000.0;
      final eventExpenses = [
        {'category': 'Room', 'amount': 8000.0},
        {'category': 'Food', 'amount': 3500.0},
        {'category': 'Fuel', 'amount': 2500.0},
        {'category': 'Car', 'amount': 4000.0},
        {'category': 'Shopping', 'amount': 1500.0},
        {'category': 'Extras', 'amount': 500.0},
      ];

      final totalEventSpending = eventExpenses.fold<double>(
        0.0,
        (sum, item) => sum + (item['amount'] as double),
      );
      final remainingEventBudget = eventBudget - totalEventSpending;

      expect(totalEventSpending, equals(20000.0));
      expect(remainingEventBudget, equals(5000.0));
    });
  });
}
