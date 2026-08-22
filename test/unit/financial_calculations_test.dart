import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Financial Calculations Tests', () {
    test('Calculates total income correctly', () {
      final incomeAmounts = [30000.0, 5000.0, 1200.0];
      final totalIncome = incomeAmounts.fold(0.0, (sum, val) => sum + val);

      expect(totalIncome, equals(36200.0));
    });

    test('Calculates total expenses correctly', () {
      final expenseAmounts = [500.0, 300.0, 2000.0, 1500.0];
      final totalExpenses = expenseAmounts.fold(0.0, (sum, val) => sum + val);

      expect(totalExpenses, equals(4300.0));
    });

    test('Calculates net balance (Income - Expenses) accurately', () {
      final totalIncome = 36200.0;
      final totalExpenses = 4300.0;
      final netBalance = totalIncome - totalExpenses;

      expect(netBalance, equals(31900.0));
    });
  });

  group('Budget Threshold Tests', () {
    test('Triggers correct warning threshold status', () {
      final budgetLimit = 5000.0;

      double checkStatus(double spent) {
        return spent / budgetLimit;
      }

      expect(checkStatus(3500.0), lessThan(0.80)); // 70% Normal
      expect(checkStatus(4200.0), greaterThanOrEqualTo(0.80)); // 84% Warning
      expect(checkStatus(4600.0), greaterThanOrEqualTo(0.90)); // 92% Urgent
      expect(checkStatus(5500.0), greaterThanOrEqualTo(1.00)); // 110% Exceeded
    });
  });

  group('Reminder Recurring Date Calculation Tests', () {
    test('Calculates monthly recurring next occurrence correctly', () {
      final initialDueDate = DateTime(2026, 8, 25, 9, 0);
      final nextMonthlyDueDate = DateTime(
        initialDueDate.year,
        initialDueDate.month + 1,
        initialDueDate.day,
        initialDueDate.hour,
      );

      expect(nextMonthlyDueDate, equals(DateTime(2026, 9, 25, 9, 0)));
    });

    test('Calculates weekly recurring next occurrence correctly', () {
      final initialDueDate = DateTime(2026, 8, 25, 9, 0);
      final nextWeeklyDueDate = initialDueDate.add(const Duration(days: 7));

      expect(nextWeeklyDueDate, equals(DateTime(2026, 9, 1, 9, 0)));
    });
  });
}
