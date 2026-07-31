import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  // Jipange's brand accent - tints the small status-bar icon on Android 5+
  // so notifications are recognizably "ours" at a glance.
  static const Color _brandColor = Color(0xFF7C86F5);

  // The large icon shown on the right of the notification (Android). This
  // is the full-color app logo - the small status-bar icon has to stay a
  // flat white silhouette per Android's own design guidelines, so branding
  // lives here instead.
  static const _largeIcon =
      DrawableResourceAndroidBitmap('@mipmap/ic_launcher');

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings - a dedicated flat/monochrome
    // drawable, not the full-color launcher icon. Android silently
    // discards unsuitable status-bar icons and falls back to its own
    // default bell icon, which is what was happening before.
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Android 13+ requires runtime permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to task details
    // This will be implemented when integrating with navigation
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  /// Schedule a notification for a task
  Future<int> scheduleTaskNotification({
    required int taskId,
    required String taskTitle,
    required DateTime dueDateTime,
  }) async {
    // Generate unique notification ID from task ID
    final notificationId = taskId;

    // Only schedule if due date is in the future
    if (dueDateTime.isBefore(DateTime.now())) {
      return notificationId;
    }

    final title = '⏰ "$taskTitle" is due';
    const body = 'Time to make it happen. Tap to open and check it off.';

    final androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for task due dates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      color: _brandColor,
      largeIcon: _largeIcon,
      ticker: 'Task due: $taskTitle',
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Jipange',
        htmlFormatContentTitle: false,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Jipange',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule notification
    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(dueDateTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: taskId.toString(),
    );

    return notificationId;
  }

  /// Show an immediate notification (used e.g. when a Pomodoro session ends)
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'pomodoro_alerts',
      'Pomodoro Alerts',
      channelDescription: 'Notifications for Pomodoro timer session changes',
      importance: Importance.high,
      priority: Priority.high,
      color: _brandColor,
      largeIcon: _largeIcon,
      ticker: title,
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Jipange • Pomodoro',
        htmlFormatContentTitle: false,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Jipange • Pomodoro',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails);
  }

  /// Cancel a task notification
  Future<void> cancelTaskNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
