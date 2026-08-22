import '../enums/app_enums.dart';

class TransactionFormDraft {
  static String amount = '';
  static String note = '';
  static TransactionType type = TransactionType.expense;
  static int? categoryId;
  static PaymentMethod paymentMethod = PaymentMethod.upi;
  static int? eventId;

  static bool get hasDraft => amount.isNotEmpty || note.isNotEmpty;

  static void clear() {
    amount = '';
    note = '';
    type = TransactionType.expense;
    categoryId = null;
    paymentMethod = PaymentMethod.upi;
    eventId = null;
  }
}

class RoomExpenseFormDraft {
  static String amount = '';
  static String description = '';
  static String splitType = 'equal';
  static int? categoryId;

  static bool get hasDraft => amount.isNotEmpty || description.isNotEmpty;

  static void clear() {
    amount = '';
    description = '';
    splitType = 'equal';
    categoryId = null;
  }
}
