import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/category_model.dart';
import '../core/models/reminder_model.dart';
import '../core/utils/safe_stream.dart';
import '../services/notification_service.dart';

class ReminderWithCategory {
  final ReminderModel reminder;
  final CategoryModel? category;

  ReminderWithCategory({
    required this.reminder,
    this.category,
  });
}

class ReminderRepository {
  final SupabaseClient _client;

  ReminderRepository(this._client);

  Future<List<ReminderWithCategory>> getAllReminders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('financial_reminders')
          .select()
          .order('due_date', ascending: true)
          .timeout(const Duration(seconds: 2));

      final list = <ReminderWithCategory>[];
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
        final r = ReminderModel.fromMap(map, category: cat);
        list.add(ReminderWithCategory(reminder: r, category: cat));
      }
      return list;
    } catch (e) {
      debugPrint('ReminderRepository: REST fetch failed: $e');
      return [];
    }
  }

  Stream<List<ReminderWithCategory>> watchAllReminders() {
    return safeSupabaseStream<List<ReminderWithCategory>>(
      fetchRest: () => getAllReminders(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('financial_reminders')
            .stream(primaryKey: ['id'])
            .order('due_date', ascending: true)
            .asyncMap((rows) async {
              final list = <ReminderWithCategory>[];
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
                final r = ReminderModel.fromMap(row, category: cat);
                list.add(ReminderWithCategory(reminder: r, category: cat));
              }
              return list;
            });
      },
    );
  }

  Future<ReminderModel> insertReminder({
    required String title,
    required int amountPaise,
    required DateTime dueDate,
    String frequency = 'one_time',
    String? categoryId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final response = await _client.from('financial_reminders').insert({
      'user_id': userId,
      'title': title,
      'amount_paise': amountPaise,
      'due_date': dueDate.toIso8601String(),
      'frequency': frequency,
      'is_completed': false,
      'category_id': categoryId,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    final model = ReminderModel.fromMap(response);
    _scheduleSystemNotification(model.id, title, amountPaise, dueDate);
    return model;
  }

  Future<void> updateStatus(String id, bool isCompleted) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('financial_reminders').update({
      'is_completed': isCompleted,
    }).eq('id', id).eq('user_id', userId);

    if (isCompleted) {
      try {
        NotificationService().cancelNotification(id.hashCode);
      } catch (_) {}
    }
  }

  Future<void> deleteReminder(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      NotificationService().cancelNotification(id.hashCode);
    } catch (_) {}

    await _client.from('financial_reminders').delete().eq('id', id).eq('user_id', userId);
  }

  void _scheduleSystemNotification(String id, String title, int amountPaise, DateTime dueDate) {
    try {
      final rupees = (amountPaise / 100.0).toStringAsFixed(0);
      final notificationTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      NotificationService().scheduleReminderNotification(
        id: id.hashCode,
        title: '🔔 Payment Due: $title',
        body: '₹$rupees for $title is due today. Tap to view and mark as paid.',
        scheduledDate: notificationTime,
      );
    } catch (_) {}
  }
}
