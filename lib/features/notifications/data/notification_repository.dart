import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/notification_model.dart';


final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  Stream<List<NotificationModel>> getNotificationsStream() {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    final query = _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_user_id', currentUser.id)
        .order('created_at', ascending: false);

    return query.map(
      (data) => data.map((json) => NotificationModel.fromJson(json)).toList(),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('recipient_user_id', currentUser.id);
  }

  Future<void> markAllAsRead() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_user_id', currentUser.id)
        .eq('is_read', false);
  }
}
