import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/event_model.dart';
import '../core/utils/safe_stream.dart';

class EventWithStats {
  final EventModel event;
  final int totalSpentPaise;

  EventWithStats({
    required this.event,
    required this.totalSpentPaise,
  });
}

class EventRepository {
  final SupabaseClient _client;

  EventRepository(this._client);

  Future<List<EventModel>> getAllEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('events')
          .select()
          .order('created_at', ascending: false);
      return (rows as List).map((r) => EventModel.fromMap(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('EventRepository: REST fetch for all events failed: $e');
      return [];
    }
  }

  Future<List<EventWithStats>> getActiveEventsWithStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('events')
          .select()
          .order('created_at', ascending: false);

      final activeEvents = (rows as List)
          .map((r) => EventModel.fromMap(r as Map<String, dynamic>))
          .where((e) => e.status.toLowerCase() == 'active' || e.status.toLowerCase() == 'upcoming')
          .toList();

      final list = <EventWithStats>[];
      for (final event in activeEvents) {
        int spent = 0;
        try {
          final txs = await _client.from('transactions').select('amount_paise').eq('event_id', event.id).eq('type', 'expense');
          spent = (txs as List).fold<int>(0, (sum, t) => sum + ((t['amount_paise'] as num?)?.toInt() ?? 0));
        } catch (_) {}
        list.add(EventWithStats(event: event, totalSpentPaise: spent));
      }
      return list;
    } catch (e) {
      debugPrint('EventRepository: REST fetch for active events stats failed: $e');
      return [];
    }
  }

  Stream<List<EventModel>> watchAllEvents() {
    return safeSupabaseStream<List<EventModel>>(
      fetchRest: () => getAllEvents(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('events')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((rows) => rows.map((r) => EventModel.fromMap(r)).toList());
      },
    );
  }

  Stream<List<EventWithStats>> watchActiveEventsWithStats() {
    return safeSupabaseStream<List<EventWithStats>>(
      fetchRest: () => getActiveEventsWithStats(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('events')
            .stream(primaryKey: ['id'])
            .asyncMap((rows) async {
              final activeEvents = rows.map((r) => EventModel.fromMap(r)).where((e) => e.status.toLowerCase() == 'active' || e.status.toLowerCase() == 'upcoming').toList();
              final list = <EventWithStats>[];
              for (final event in activeEvents) {
                int spent = 0;
                try {
                  final txs = await _client.from('transactions').select('amount_paise').eq('event_id', event.id).eq('type', 'expense');
                  spent = (txs as List).fold<int>(0, (sum, t) => sum + ((t['amount_paise'] as num?)?.toInt() ?? 0));
                } catch (_) {}
                list.add(EventWithStats(event: event, totalSpentPaise: spent));
              }
              return list;
            });
      },
    );
  }

  Future<EventModel> insertEvent({
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    int budgetPaise = 0,
    String status = 'active',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final response = await _client.from('events').insert({
      'user_id': userId,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'budget_paise': budgetPaise,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return EventModel.fromMap(response);
  }

  Future<void> updateEvent(EventModel event) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('events').update({
      'title': event.title,
      'description': event.description,
      'start_date': event.startDate.toIso8601String(),
      'end_date': event.endDate?.toIso8601String(),
      'budget_paise': event.budgetPaise,
      'status': event.status,
    }).eq('id', event.id).eq('user_id', userId);
  }

  Future<void> deleteEvent(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('events').delete().eq('id', id).eq('user_id', userId);
  }
}
