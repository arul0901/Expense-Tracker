enum TransactionType {
  income,
  expense;

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
    }
  }
}

enum PaymentMethod {
  upi,
  cash,
  card,
  bankTransfer,
  other;

  String get label {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Credit/Debit Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

enum ReminderType {
  bill,
  rent,
  emi,
  subscription,
  insurance,
  salary,
  investment,
  plannedPurchase,
  custom;

  String get label {
    switch (this) {
      case ReminderType.bill:
        return 'Bill';
      case ReminderType.rent:
        return 'Rent';
      case ReminderType.emi:
        return 'EMI';
      case ReminderType.subscription:
        return 'Subscription';
      case ReminderType.insurance:
        return 'Insurance';
      case ReminderType.salary:
        return 'Salary';
      case ReminderType.investment:
        return 'Investment';
      case ReminderType.plannedPurchase:
        return 'Planned Purchase';
      case ReminderType.custom:
        return 'Custom Event';
    }
  }
}

enum RepeatType {
  never,
  daily,
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case RepeatType.never:
        return 'Never';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.yearly:
        return 'Yearly';
    }
  }
}

enum ReminderStatus {
  upcoming,
  due,
  overdue,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case ReminderStatus.upcoming:
        return 'Upcoming';
      case ReminderStatus.due:
        return 'Due Today';
      case ReminderStatus.overdue:
        return 'Overdue';
      case ReminderStatus.completed:
        return 'Completed';
      case ReminderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
