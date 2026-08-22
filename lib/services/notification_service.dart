import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
    await _createNotificationChannel();
    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    const financialChannel = AndroidNotificationChannel(
      'financial_reminders_channel',
      'Financial & Bill Reminders',
      description: 'Notifications for upcoming bills, rent, EMIs, and daily check-ins',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const roomChannel = AndroidNotificationChannel(
      'room_activity_channel',
      'Room & Shared Expense Alerts',
      description: 'Notifications for new shared expenses, settlements, splits, and room tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(financialChannel);
    await androidPlugin?.createNotificationChannel(roomChannel);
  }

  Future<bool> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
    return granted ?? false;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    final bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: 'ProFin Personal Finance',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'financial_reminders_channel',
      'Financial & Daily Reminders',
      channelDescription: 'Notifications for daily expense checks and upcoming financial bills',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0D9488),
      styleInformation: bigTextStyleInformation,
      subText: 'ProFin',
      enableVibration: true,
      playSound: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }

  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isInitialized) await initialize();
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    final bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: 'ProFin Payment Due',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'financial_reminders_channel',
      'Financial & Daily Reminders',
      channelDescription: 'Notifications for daily expense checks and upcoming financial bills',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0D9488),
      styleInformation: bigTextStyleInformation,
      subText: 'ProFin Reminder',
      enableVibration: true,
      playSound: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleDailyCheckNotification({required TimeOfDay time}) async {
    if (!_isInitialized) await initialize();

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const bigTextStyleInformation = BigTextStyleInformation(
      'Have you recorded today\'s expenses? Take 30 seconds to keep your balance updated on ProFin.',
      contentTitle: '📊 Daily Finance Check-in',
      summaryText: 'ProFin Evening Check',
    );

    const androidDetails = AndroidNotificationDetails(
      'financial_reminders_channel',
      'Financial & Daily Reminders',
      channelDescription: 'Daily evening check to record transactions',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF0D9488),
      styleInformation: bigTextStyleInformation,
      subText: 'Daily Check-in',
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin.zonedSchedule(
      8888, // Daily Check ID
      '📊 Daily Finance Check-in',
      'Have you recorded today\'s expenses? Take 30 seconds to keep your balance updated on ProFin.',
      tzDateTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
