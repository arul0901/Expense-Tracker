# Professional Expense Tracker — Flutter Application

A production-quality personal finance and expense tracking application built in Flutter with Dart, Riverpod, GoRouter, Drift (SQLite), `fl_chart`, `intl`, and `flutter_local_notifications`.

---

## 🚀 Key Features

* **Real Financial Dashboard**: Live calculation of Net Balance (`Income - Expense`), recent transactions, budget progress, and upcoming reminders without hardcoded values.
* **Offline-First SQLite Persistence**: Powered by Drift ORM for type-safe local database storage.
* **Full Transaction System**: Create, edit, search, filter, and sort income and expense transactions.
* **Financial Reminders & Notifications**: Create due-date alerts for bills, rent, EMIs, and subscriptions with local notifications.
* **Automated Reminder → Transaction Integration**: Mark financial reminders as paid and automatically generate corresponding expense/income transactions in SQLite while rescheduling recurring dates.
* **Analytics & Donut Charts**: Interactive `fl_chart` breakdown of spending across categories.
* **Budget Tracking**: Configure monthly and category-specific budget limits with dynamic alert thresholds (80% Warning, 90%+ Exceeded).
* **Data Management**: Data reset flows with double confirmation protection.

---

## 🏛️ Technology Stack & Architecture

```text
lib/
├── main.dart                          # Application entry point with ProviderScope
├── app/
│   ├── app.dart                       # MaterialApp.router configuration
│   ├── routes/
│   │   └── app_router.dart            # GoRouter with ShellRoute for Bottom Navigation
│   └── theme/
│       └── app_theme.dart             # Material 3 light & dark theme system
├── core/
│   ├── constants/                     # App constants (thresholds, default currency)
│   ├── enums/                         # TransactionType, ReminderType, RepeatType, ReminderStatus
│   ├── utils/                         # Currency & date formatters via intl
│   └── extensions/                    # Theme & context extensions
├── database/
│   ├── app_database.dart              # Drift database connection & seed data
│   └── tables/                        # Categories, Transactions, FinancialReminders, Budgets
├── repositories/                      # CategoryRepository, TransactionRepository, ReminderRepository, BudgetRepository
├── providers/                         # Riverpod reactive providers & DB streams
├── services/
│   └── notification_service.dart     # flutter_local_notifications manager
├── features/
│   ├── dashboard/                     # Financial overview widgets
│   ├── transactions/                  # Searchable, filterable transactions list
│   ├── reminders/                     # Due today, overdue, upcoming, completed tabs
│   ├── analytics/                     # fl_chart pie/donut category breakdown
│   ├── budgets/                       # Monthly & category target budget management
│   └── settings/                      # Preferences, notifications test & data reset
└── widgets/                           # Reusable UI cards, icons, and empty states
```

---

## 🛠️ Getting Started

### Prerequisites
* Flutter SDK (3.44+)
* Dart SDK (3.12+)
* Android Studio / VS Code

### Run Application

1. Clone or open the workspace:
   ```bash
   cd C:\Users\arulb\FlutterProjects\expense_tracker
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Generate Drift database bindings:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run on connected Android device/emulator:
   ```bash
   flutter run -d emulator-5554
   ```

---

## 🧪 Testing

Run unit tests covering financial balance calculations, budget thresholds, and recurring reminder logic:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```
