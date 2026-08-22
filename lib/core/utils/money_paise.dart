import 'package:intl/intl.dart';

/// Class for precise financial operations without floating-point rounding errors.
/// Internal storage is in integer paise (1 Rupee = 100 Paise).
class MoneyPaise {
  final int paise;

  const MoneyPaise(this.paise);

  factory MoneyPaise.fromRupees(double rupees) {
    return MoneyPaise((rupees * 100).round());
  }

  factory MoneyPaise.fromPaise(int paise) {
    return MoneyPaise(paise);
  }

  static const MoneyPaise zero = MoneyPaise(0);

  double toRupees() => paise / 100.0;

  String format({String symbol = '₹', bool compact = false}) {
    final rupees = toRupees();
    if (compact) {
      return NumberFormat.compactCurrency(
        locale: 'en_IN',
        symbol: symbol,
        decimalDigits: 0,
      ).format(rupees);
    }
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: 2,
    ).format(rupees);
  }

  MoneyPaise operator +(MoneyPaise other) => MoneyPaise(paise + other.paise);
  MoneyPaise operator -(MoneyPaise other) => MoneyPaise(paise - other.paise);
  MoneyPaise operator *(num multiplier) => MoneyPaise((paise * multiplier).round());
  MoneyPaise operator /(num divisor) => MoneyPaise((paise / divisor).round());

  bool operator <(MoneyPaise other) => paise < other.paise;
  bool operator <=(MoneyPaise other) => paise <= other.paise;
  bool operator >(MoneyPaise other) => paise > other.paise;
  bool operator >=(MoneyPaise other) => paise >= other.paise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MoneyPaise && paise == other.paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}
