import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

class FcmService {
  final NotificationService _localNotifications = NotificationService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize Firebase Messaging, request permissions, and register FCM token
  Future<void> initializeFcm() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await registerDeviceToken(token);
        }

        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          await registerDeviceToken(newToken);
        });
      }

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && notification.title != null && notification.body != null) {
          handleRemoteMessage(
            title: notification.title!,
            body: notification.body!,
            data: message.data,
          );
        }
      });
    } catch (e) {
      debugPrint('FCM Initialization error: $e');
    }
  }

  /// Register FCM Push Token for the authenticated user into Supabase user_devices table
  Future<void> registerDeviceToken(String fcmToken) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final platformStr = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'));

      await Supabase.instance.client.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': fcmToken,
          'platform': platformStr,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, fcm_token',
      );
      debugPrint('FCM Token registered in Supabase user_devices');
    } catch (e) {
      debugPrint('Failed to register FCM token in Supabase: $e');
    }
  }

  /// Remove FCM Push Token on user sign out
  Future<void> unregisterDeviceToken(String fcmToken) async {
    try {
      await Supabase.instance.client
          .from('user_devices')
          .delete()
          .eq('fcm_token', fcmToken);
      debugPrint('FCM Token deleted from Supabase user_devices');
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }
  }

  /// Handle incoming remote notification payloads
  Future<void> handleRemoteMessage({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Show local notification alert for foreground push events
    await _localNotifications.showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
    );
  }
}
