import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomRealtimeServiceProvider = Provider<RoomRealtimeService>((ref) {
  return RoomRealtimeService();
});

class RoomRealtimeService {
  final Map<String, RealtimeChannel> _activeChannels = {};

  /// Subscribe to Realtime postgres changes for a specific Room ID
  RealtimeChannel? subscribeToRoom({
    required String roomId,
    required VoidCallback onRoomUpdated,
  }) {
    if (_activeChannels.containsKey(roomId)) {
      return _activeChannels[roomId];
    }

    try {
      final client = Supabase.instance.client;
      final channel = client.channel('public:rooms:id=$roomId');

      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_expenses',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              debugPrint('Realtime room expense event: ${payload.eventType}');
              onRoomUpdated();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'expense_splits',
            callback: (payload) {
              debugPrint('Realtime expense split event: ${payload.eventType}');
              onRoomUpdated();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'settlements',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              debugPrint('Realtime settlement event: ${payload.eventType}');
              onRoomUpdated();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_tasks',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              debugPrint('Realtime room task event: ${payload.eventType}');
              onRoomUpdated();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              debugPrint('Realtime room member event: ${payload.eventType}');
              onRoomUpdated();
            },
          )
          .subscribe();

      _activeChannels[roomId] = channel;
      debugPrint('Subscribed to Realtime channel for room: $roomId');
      return channel;
    } catch (e) {
      debugPrint('Failed to subscribe to room realtime: $e');
      return null;
    }
  }

  /// Unsubscribe from a specific room channel
  Future<void> unsubscribeFromRoom(String roomId) async {
    final channel = _activeChannels.remove(roomId);
    if (channel != null) {
      try {
        await Supabase.instance.client.removeChannel(channel);
        debugPrint('Unsubscribed from Realtime room: $roomId');
      } catch (e) {
        debugPrint('Error unsubscribing room channel: $e');
      }
    }
  }

  /// Unsubscribe from all active room channels
  Future<void> disposeAll() async {
    for (final roomId in _activeChannels.keys.toList()) {
      await unsubscribeFromRoom(roomId);
    }
  }
}
