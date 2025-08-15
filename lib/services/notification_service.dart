import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Get and set local timezone
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Darwin (iOS/macOS) initialization settings
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        // Add notification categories if you need actions
        notificationCategories: [
          DarwinNotificationCategory(
            'reminder_category',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain('mark_done', 'Mark Done'),
              DarwinNotificationAction.plain('snooze', 'Snooze'),
            ],
            options: <DarwinNotificationCategoryOption>{
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
        ],
      );

      // Linux initialization settings (if supporting Linux)
      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      // Windows initialization settings (if supporting Windows)
      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
        appName: 'Pinpoint',
        appUserModelId: 'com.yourcompany.pinpoint',
        guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb', // Generate your own GUID
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux,
        windows: initializationSettingsWindows,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onDidReceiveBackgroundNotificationResponse,
      );

      // Request permissions on Android 13+ and iOS
      await _requestPermissions();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Handle notification taps when app is in foreground/background
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle the notification tap - navigate to specific screen, etc.
  }

  // Handle notification actions when app is terminated/sleeping
  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse response) {
    debugPrint('Background notification response: ${response.actionId}');
    // Handle background notification actions
  }

  // Request permissions for notifications
  static Future<void> _requestPermissions() async {
    // Request permissions on Android 13+
    final androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      // Optionally request exact alarm permission for scheduled notifications
      await androidPlugin.requestExactAlarmsPermission();
    }

    // Request permissions on iOS
    final iosPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Request permissions on macOS
    final macosPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();

    if (macosPlugin != null) {
      await macosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // Show immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? categoryId,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pinpoint_general',
      'General Notifications',
      channelDescription: 'General notifications for Pinpoint app',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'New notification',
      // Add actions if needed
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('mark_done', 'Mark Done'),
        AndroidNotificationAction('snooze', 'Snooze'),
      ],
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Schedule notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? categoryId,
  }) async {
    final tz.TZDateTime scheduledTZDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pinpoint_reminders',
      'Pinpoint Reminders',
      channelDescription: 'Scheduled notifications for Pinpoint reminders',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Scheduled reminder',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('mark_done', 'Mark Done'),
        AndroidNotificationAction('snooze', 'Snooze'),
      ],
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // matchDateTimeComponents: DateTimeComponents.dateAndTime,
      // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Schedule recurring notification (daily at specific time)
  static Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pinpoint_recurring',
          'Recurring Reminders',
          channelDescription: 'Daily recurring notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'reminder_category',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // This makes it recurring daily
      payload: payload,
    );
  }

  // Schedule periodic notification with interval
  static Future<void> schedulePeriodicNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pinpoint_periodic',
      'Periodic Reminders',
      channelDescription: 'Periodic notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      repeatInterval,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Get pending notifications
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Get active notifications (Android 6+, iOS 10+, macOS 10.14+)
  static Future<List<ActiveNotification>> getActiveNotifications() async {
    return await _flutterLocalNotificationsPlugin.getActiveNotifications();
  }

  // Check if notifications are enabled
  static Future<bool?> areNotificationsEnabled() async {
    final androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled();
    }

    final iosPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      return await iosPlugin
          .checkPermissions()
          .then((permissions) => permissions?.isEnabled);
    }

    return null;
  }

  // Get notification app launch details
  static Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
  }
}
