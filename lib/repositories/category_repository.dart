import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/category_model.dart';
import '../core/utils/safe_stream.dart';

class CategoryRepository {
  final SupabaseClient _client;

  CategoryRepository(this._client);

  static final List<CategoryModel> defaultCategories = [
    // Expense Categories
    CategoryModel(id: '11111111-1111-4111-a111-111111111111', name: 'Food & Dining', icon: 'restaurant', color: 0xFFE53935, type: 'expense', isSystem: true),
    CategoryModel(id: '22222222-2222-4222-a222-222222222222', name: 'Shopping', icon: 'shopping_bag', color: 0xFF8E24AA, type: 'expense', isSystem: true),
    CategoryModel(id: '33333333-3333-4333-a333-333333333333', name: 'Transport', icon: 'directions_bus', color: 0xFF1E88E5, type: 'expense', isSystem: true),
    CategoryModel(id: '44444444-4444-4444-a444-444444444444', name: 'Bills', icon: 'receipt_long', color: 0xFFFB8C00, type: 'expense', isSystem: true),
    CategoryModel(id: '55555555-5555-4555-a555-555555555555', name: 'Entertainment', icon: 'movie', color: 0xFFD81B60, type: 'expense', isSystem: true),
    CategoryModel(id: '66666666-6666-4666-a666-666666666666', name: 'Healthcare', icon: 'medical_services', color: 0xFF00ACC1, type: 'expense', isSystem: true),
    CategoryModel(id: '77777777-7777-4777-a777-777777777777', name: 'Education', icon: 'school', color: 0xFF3F51B5, type: 'expense', isSystem: true),
    CategoryModel(id: '88888888-8888-4888-a888-888888888888', name: 'Other Expense', icon: 'category', color: 0xFF757575, type: 'expense', isSystem: true),
    // Income Categories
    CategoryModel(id: '99999999-9999-4999-a999-999999999999', name: 'Salary', icon: 'account_balance_wallet', color: 0xFF43A047, type: 'income', isSystem: true),
    CategoryModel(id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', name: 'Freelance', icon: 'laptop_mac', color: 0xFF00ACC1, type: 'income', isSystem: true),
    CategoryModel(id: 'bbbbbbbb-bbbb-4bbb-abbb-bbbbbbbbbbbb', name: 'Investments', icon: 'trending_up', color: 0xFF7CB342, type: 'income', isSystem: true),
    CategoryModel(id: 'cccccccc-cccc-4ccc-accc-cccccccccccc', name: 'Gifts', icon: 'card_giftcard', color: 0xFFFDD835, type: 'income', isSystem: true),
    CategoryModel(id: 'dddddddd-dddd-4ddd-addd-dddddddddddd', name: 'Other Income', icon: 'category', color: 0xFF009688, type: 'income', isSystem: true),
  ];

  Stream<List<CategoryModel>> watchAllCategories() {
    final session = _client.auth.currentSession;
    if (session != null && session.isExpired) {
      return Stream.value(defaultCategories);
    }
    return safeSupabaseStream<List<CategoryModel>>(
      fetchRest: () => getAllCategories(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        return _client
            .from('categories')
            .stream(primaryKey: ['id'])
            .map((maps) {
              final dbList = maps.map((map) => CategoryModel.fromMap(map)).toList();
              final filtered = dbList.where((c) => c.isSystem || c.userId == userId).toList();
              return _mergeWithDefaults(filtered);
            });
      },
    );
  }

  Stream<List<CategoryModel>> watchCategoriesByType(String type) async* {
    yield defaultCategories.where((c) => c.type == type).toList();
    try {
      await for (final list in watchAllCategories()) {
        yield list.where((c) => c.type == type).toList();
      }
    } catch (_) {
      yield defaultCategories.where((c) => c.type == type).toList();
    }
  }

  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null && session.isExpired) {
        return defaultCategories;
      }
      final response = await _client
          .from('categories')
          .select()
          .timeout(const Duration(seconds: 1));
      final dbList = (response as List).map((map) => CategoryModel.fromMap(map as Map<String, dynamic>)).toList();
      final userId = _client.auth.currentUser?.id;
      final filtered = dbList.where((c) => c.isSystem || c.userId == userId).toList();
      return _mergeWithDefaults(filtered);
    } catch (_) {
      return defaultCategories;
    }
  }

  static List<CategoryModel> _mergeWithDefaults(List<CategoryModel> dbList) {
    if (dbList.isEmpty) return defaultCategories;
    final dbIds = dbList.map((c) => c.id).toSet();
    final dbNames = dbList.map((c) => c.name.toLowerCase()).toSet();
    final missingDefaults = defaultCategories
        .where((d) => !dbIds.contains(d.id) && !dbNames.contains(d.name.toLowerCase()))
        .toList();
    return [...missingDefaults, ...dbList];
  }

  Future<CategoryModel> insertCategory({
    required String name,
    required String icon,
    required int color,
    required String type,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Network or Authentication error. Reconnect to continue.');
    }

    final response = await _client.from('categories').insert({
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'is_system': false,
    }).select().single();

    return CategoryModel.fromMap(response);
  }

  Future<void> deleteCategory(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('categories').delete().eq('id', id).eq('user_id', userId);
  }

  Future<void> ensureCategoryExists(String categoryId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await _client.from('categories').select('id').eq('id', categoryId).maybeSingle();
      if (existing == null) {
        final defaultCat = defaultCategories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => CategoryModel(
            id: categoryId,
            name: 'General',
            icon: 'category',
            color: 0xFF0D9488,
            type: 'expense',
          ),
        );
        await _client.from('categories').insert({
          'id': defaultCat.id,
          'user_id': userId,
          'name': defaultCat.name,
          'icon': defaultCat.icon,
          'color': defaultCat.color,
          'type': defaultCat.type,
          'is_system': false,
        });
      }
    } catch (_) {}
  }
}

