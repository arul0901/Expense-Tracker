import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/category_model.dart';
import '../core/models/transaction_model.dart';
import '../core/utils/safe_stream.dart';
import 'category_repository.dart';


class TransactionWithCategory {
  final TransactionModel transaction;
  final CategoryModel category;

  TransactionWithCategory({
    required this.transaction,
    required this.category,
  });
}

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  Future<List<TransactionWithCategory>> getAllTransactionsWithCategory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('transactions')
          .select()
          .order('date', ascending: false);

      final list = <TransactionWithCategory>[];
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
        cat ??= CategoryModel(id: 'default', name: 'General', icon: 'category', color: 0xFF0D9488, type: map['type'] ?? 'expense');
        final tx = TransactionModel.fromMap(map, category: cat);
        list.add(TransactionWithCategory(transaction: tx, category: cat));
      }
      return list;
    } catch (e) {
      debugPrint('TransactionRepository: REST fetch for transactions failed: $e');
      return [];
    }
  }

  Stream<List<TransactionWithCategory>> watchAllTransactionsWithCategory() {
    return safeSupabaseStream<List<TransactionWithCategory>>(
      fetchRest: () => getAllTransactionsWithCategory(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('transactions')
            .stream(primaryKey: ['id'])
            .order('date', ascending: false)
            .asyncMap((rows) async {
              final list = <TransactionWithCategory>[];
              for (final row in rows) {
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
                cat ??= CategoryModel(id: 'default', name: 'General', icon: 'category', color: 0xFF0D9488, type: row['type'] ?? 'expense');
                final tx = TransactionModel.fromMap(row, category: cat);
                list.add(TransactionWithCategory(transaction: tx, category: cat));
              }
              return list;
            }).handleError((error, stackTrace) async* {
              if (error.toString().contains('InvalidJWTToken') || error.toString().contains('expired')) {
                try {
                  await _client.auth.refreshSession();
                } catch (_) {}
              }
              yield <TransactionWithCategory>[];
            });
      },
    );
  }

  Stream<List<TransactionWithCategory>> watchRecentTransactionsWithCategory({int limit = 5}) {
    return watchAllTransactionsWithCategory().map((list) => list.take(limit).toList());
  }

  Future<TransactionModel> insertTransaction({
    required String type,
    required int amountPaise,
    required DateTime date,
    String? categoryId,
    String? note,
    String paymentMethod = 'upi',
    String? eventId,
    String? roomId,
  }) async {
    User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      try {
        final res = await _client.auth.signInAnonymously();
        currentUser = res.user;
      } catch (_) {}
    }
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('Unauthenticated. Please sign in or check network connection.');
    }

    String? validCatId = categoryId;
    if (validCatId != null && !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(validCatId)) {
      validCatId = null;
    }

    if (validCatId != null) {
      try {
        final catRepo = CategoryRepository(_client);
        await catRepo.ensureCategoryExists(validCatId);
      } catch (_) {}
    }

    try {
      final response = await _client.from('transactions').insert({
        'user_id': userId,
        'type': type,
        'amount_paise': amountPaise,
        'category_id': validCatId,
        'date': date.toIso8601String(),
        'note': note,
        'payment_method': paymentMethod,
        'event_id': eventId,
        'room_id': roomId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      return TransactionModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == '23503' || e.message.contains('transactions_category_id_fkey') || e.message.contains('categories')) {
        // Fallback: save transaction without category_id if FK check still fails
        final response = await _client.from('transactions').insert({
          'user_id': userId,
          'type': type,
          'amount_paise': amountPaise,
          'category_id': null,
          'date': date.toIso8601String(),
          'note': note,
          'payment_method': paymentMethod,
          'event_id': eventId,
          'room_id': roomId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
        return TransactionModel.fromMap(response);
      }
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    String? validCatId = transaction.categoryId;
    if (validCatId != null) {
      try {
        final catRepo = CategoryRepository(_client);
        await catRepo.ensureCategoryExists(validCatId);
      } catch (_) {}
    }

    try {
      await _client.from('transactions').update({
        'type': transaction.type,
        'amount_paise': transaction.amountPaise,
        'category_id': validCatId,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
        'payment_method': transaction.paymentMethod,
        'event_id': transaction.eventId,
        'room_id': transaction.roomId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', transaction.id).eq('user_id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23503' || e.message.contains('transactions_category_id_fkey') || e.message.contains('categories')) {
        await _client.from('transactions').update({
          'type': transaction.type,
          'amount_paise': transaction.amountPaise,
          'category_id': null,
          'date': transaction.date.toIso8601String(),
          'note': transaction.note,
          'payment_method': transaction.paymentMethod,
          'event_id': transaction.eventId,
          'room_id': transaction.roomId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', transaction.id).eq('user_id', userId);
        return;
      }
      rethrow;
    }
  }


  Future<void> deleteTransaction(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Delete any linked room expenses first
    try {
      final linkedExpenses = await _client.from('room_expenses').select('id').eq('linked_transaction_id', id);
      for (final row in (linkedExpenses as List)) {
        final expId = row['id'].toString();
        await _client.from('expense_splits').delete().eq('room_expense_id', expId);
        await _client.from('room_expenses').delete().eq('id', expId);
      }
    } catch (_) {}

    await _client.from('transactions').delete().eq('id', id).eq('user_id', userId);
  }
}
