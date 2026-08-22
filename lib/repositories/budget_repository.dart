import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/budget_model.dart';
import '../core/models/category_model.dart';
import '../core/utils/safe_stream.dart';

class BudgetWithCategory {
  final BudgetModel budget;
  final CategoryModel? category;

  BudgetWithCategory({
    required this.budget,
    this.category,
  });
}

class BudgetRepository {
  final SupabaseClient _client;

  BudgetRepository(this._client);

  Future<List<BudgetWithCategory>> getBudgetsForMonth(int year, int month) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('budgets')
          .select()
          .eq('year', year)
          .eq('month', month)
          .timeout(const Duration(seconds: 2));

      final list = <BudgetWithCategory>[];
      for (final row in (rows as List)) {
        final map = row as Map<String, dynamic>;
        final categoryId = map['category_id']?.toString();
        CategoryModel? cat;
        if (categoryId != null) {
          try {
            final catRow = await _client.from('categories').select().eq('id', categoryId).maybeSingle();
            if (catRow != null) {
              cat = CategoryModel.fromMap(catRow);
            }
          } catch (_) {}
        }
        final b = BudgetModel.fromMap(map, category: cat);
        list.add(BudgetWithCategory(budget: b, category: cat));
      }
      return list;
    } catch (e) {
      debugPrint('BudgetRepository: REST fetch for budgets failed: $e');
      return [];
    }
  }

  Stream<List<BudgetWithCategory>> watchBudgetsForMonth(int year, int month) {
    return safeSupabaseStream<List<BudgetWithCategory>>(
      fetchRest: () => getBudgetsForMonth(year, month),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('budgets')
            .stream(primaryKey: ['id'])
            .asyncMap((rows) async {
              final filtered = rows.where((r) => r['year'] == year && r['month'] == month).toList();
              final list = <BudgetWithCategory>[];
              for (final row in filtered) {
                final categoryId = row['category_id']?.toString();
                CategoryModel? cat;
                if (categoryId != null) {
                  try {
                    final catRow = await _client.from('categories').select().eq('id', categoryId).maybeSingle();
                    if (catRow != null) {
                      cat = CategoryModel.fromMap(catRow);
                    }
                  } catch (_) {}
                }
                final b = BudgetModel.fromMap(row, category: cat);
                list.add(BudgetWithCategory(budget: b, category: cat));
              }
              return list;
            });
      },
    );
  }

  Future<BudgetModel> insertOrUpdateBudget({
    String? id,
    String? categoryId,
    required int amountPaise,
    required int month,
    required int year,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'category_id': categoryId,
      'amount_limit_paise': amountPaise,
      'month': month,
      'year': year,
    };
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }

    final response = await _client.from('budgets').upsert(payload).select().single();
    return BudgetModel.fromMap(response);
  }

  Future<void> deleteBudget(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('budgets').delete().eq('id', id).eq('user_id', userId);
  }
}
