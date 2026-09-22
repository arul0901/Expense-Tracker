import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/providers/auth_provider.dart';
import '../core/models/category_model.dart';
import '../core/models/event_model.dart';
import '../core/models/member_financial_summary.dart';
import '../core/models/room_activity_model.dart';
import '../core/models/room_member_model.dart';
import '../core/models/search_result_model.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/room_repository.dart';
import '../repositories/search_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/ai_assistant_service.dart';
import '../services/notification_service.dart';

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Active User ID Provider for Data Isolation
final activeUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.user?.id ?? ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

// Services
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return AiAssistantService(ref.watch(supabaseClientProvider));
});

// Repositories
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(supabaseClientProvider));
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(supabaseClientProvider));
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(supabaseClientProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(supabaseClientProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.watch(supabaseClientProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider));
});

// Data Stream & Future Providers

final expenseCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesByType('expense');
});

final incomeCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesByType('income');
});

final allTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactionsWithCategory();
});

final recentTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactionsWithCategory().map((list) => list.take(5).toList());
});

final currentMonthBudgetsProvider = StreamProvider<List<BudgetWithCategory>>((ref) {
  final now = DateTime.now();
  return ref.watch(budgetRepositoryProvider).watchBudgetsForMonth(now.month, now.year);
});

final allRemindersProvider = StreamProvider<List<ReminderWithCategory>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchAllReminders();
});

final allEventsProvider = StreamProvider<List<EventModel>>((ref) {
  return ref.watch(eventRepositoryProvider).watchAllEvents();
});

final activeEventsWithStatsProvider = StreamProvider<List<EventWithStats>>((ref) {
  return ref.watch(eventRepositoryProvider).watchActiveEventsWithStats();
});

final allRoomsProvider = StreamProvider<List<RoomWithDetails>>((ref) {
  return ref.watch(roomRepositoryProvider).watchAllRooms();
});

final roomMembersProvider = StreamProvider.family<List<RoomMemberModel>, String>((ref, roomId) {
  return ref.watch(roomRepositoryProvider).watchRoomMembers(roomId);
});

final roomMemberFinancialsProvider = StreamProvider.family<List<MemberFinancialSummary>, String>((ref, roomId) {
  return ref.watch(roomRepositoryProvider).watchRoomMemberFinancials(roomId);
});

final roomExpensesProvider = StreamProvider.family<List<ExpenseWithPayerAndSplits>, String>((ref, roomId) {
  return ref.watch(roomRepositoryProvider).watchRoomExpenses(roomId);
});

final roomActivitiesProvider = StreamProvider.family<List<RoomActivityModel>, String>((ref, roomId) {
  return ref.watch(roomRepositoryProvider).watchRoomActivities(roomId);
});

final roomTasksProvider = StreamProvider.family<List<TaskWithMemberAndRoom>, String>((ref, roomId) {
  return ref.watch(taskRepositoryProvider).watchTasksForRoom(roomId);
});

final globalTasksProvider = StreamProvider<List<TaskWithMemberAndRoom>>((ref) {
  return ref.watch(taskRepositoryProvider).watchGlobalTasks();
});

// Global Search Providers
final recentSearchesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(searchRepositoryProvider).getRecentSearches();
});

class SearchParams {
  final String query;
  final SearchCategory category;

  SearchParams({required this.query, required this.category});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams && runtimeType == other.runtimeType && query == other.query && category == other.category;

  @override
  int get hashCode => query.hashCode ^ category.hashCode;
}

final searchResultsProvider = FutureProvider.family<List<SearchResultModel>, SearchParams>((ref, params) {
  return ref.watch(searchRepositoryProvider).searchEverything(
        query: params.query,
        categoryFilter: params.category,
      );
});

// Real-Time Calculated Balance Providers
final totalIncomeProvider = Provider<double>((ref) {
  final asyncTransactions = ref.watch(allTransactionsProvider);
  return asyncTransactions.maybeWhen(
    data: (transactions) {
      return transactions
          .where((t) => t.transaction.type == 'income')
          .fold(0.0, (sum, t) => sum + t.transaction.amountRupees);
    },
    orElse: () => 0.0,
  );
});

final totalExpenseProvider = Provider<double>((ref) {
  final asyncTransactions = ref.watch(allTransactionsProvider);
  return asyncTransactions.maybeWhen(
    data: (transactions) {
      return transactions
          .where((t) => t.transaction.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.transaction.amountRupees);
    },
    orElse: () => 0.0,
  );
});

final netBalanceProvider = Provider<double>((ref) {
  final income = ref.watch(totalIncomeProvider);
  final expense = ref.watch(totalExpenseProvider);
  return income - expense;
});
