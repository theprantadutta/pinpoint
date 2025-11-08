import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinpoint/firebase_options.dart';
import 'dart:io';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('📱 Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  late FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _deviceId;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  /// Initialize Firebase and notification services
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔔 Firebase already initialized');
      return;
    }

    try {
      debugPrint('🔔 Initializing Firebase Notifications...');
      debugPrint('📱 Checking Firebase apps: ${Firebase.apps.length}');

      // Initialize Firebase with platform-specific options (only if not already initialized)
      if (Firebase.apps.isEmpty) {
        debugPrint('📱 Firebase not initialized, initializing now...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized successfully');
      } else {
        debugPrint('✅ Firebase already initialized with ${Firebase.apps.length} apps');
      }

      // Initialize FirebaseMessaging instance AFTER Firebase is initialized
      _firebaseMessaging = FirebaseMessaging.instance;
      debugPrint('✅ FirebaseMessaging instance created');

      // Request notification permissions
      final permitted = await _requestPermissions();
      if (!permitted) {
        debugPrint('⚠️ Notification permissions denied');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Get device ID
      await _getDeviceId();

      // Register token with backend
      await _registerTokenWithBackend();

      _initialized = true;
      debugPrint('✅ Firebase Notification Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize Firebase Notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Propagate error to main.dart for better visibility
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      // For Android 13+ (API 33+), request POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        if (androidInfo.version.sdkInt >= 33) {
          final status = await Permission.notification.request();

          if (status.isDenied || status.isPermanentlyDenied) {
            debugPrint('⚠️ Android 13+ notification permission denied');
            return false;
          }

          debugPrint('✅ Android 13+ notification permission granted');
        }
      }

      // Request FCM permissions (iOS and additional Android settings)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          '📋 Notification permission status: ${settings.authorizationStatus}');

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Initialize local notifications for showing notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android 8.0+
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'pinpoint_default_channel',
        'Pinpoint Notifications',
        description: 'Default notification channel for Pinpoint',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      debugPrint('✅ Android notification channel created');
    }

    debugPrint('✅ Local notifications initialized');
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _registerTokenWithBackend();
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Get device ID
  Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor;
      }

      debugPrint('📱 Device ID: $_deviceId');
    } catch (e) {
      debugPrint('❌ Error getting device ID: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend() async {
    if (_fcmToken == null || _deviceId == null) {
      debugPrint('⚠️ Cannot register token: Token or Device ID is null');
      return;
    }

    try {
      final apiService = ApiService();
      await apiService.registerFCMToken(
        fcmToken: _fcmToken!,
        deviceId: _deviceId!,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );

      debugPrint('✅ FCM token registered with backend');
    } catch (e) {
      debugPrint('❌ Failed to register token with backend: $e');
    }
  }

  /// Set up message handlers for different app states
  void _setupMessageHandlers() {
    // Background message handler (already registered at top level)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    // Check if app was opened from a terminated state
    _checkInitialMessage();

    debugPrint('✅ Message handlers set up');
  }

  /// Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Foreground message received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle notification tap when app is in background
  void _handleNotificationOpened(RemoteMessage message) {
    debugPrint('🔔 Notification opened: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    // Navigate to appropriate screen based on data
    _handleNotificationData(message.data);
  }

  /// Check if app was opened from notification in terminated state
  Future<void> _checkInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();

    if (message != null) {
      debugPrint('🚀 App opened from notification: ${message.messageId}');
      _handleNotificationData(message.data);
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'pinpoint_default_channel',
      'Pinpoint Notifications',
      channelDescription: 'Default notification channel for Pinpoint',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Parse payload and navigate to appropriate screen
  }

  /// Handle notification data and navigate
  void _handleNotificationData(Map<String, dynamic> data) {
    debugPrint('📱 Handling notification data: $data');

    // Example: Navigate based on notification type
    final type = data['type'];
    final noteId = data['note_id'];

    if (type == 'note_reminder' && noteId != null) {
      // Navigate to note detail screen
      debugPrint('Navigate to note: $noteId');
      // TODO: Implement navigation
    } else if (type == 'sync_complete') {
      // Show sync complete message
      debugPrint('Sync completed');
    }
  }

  /// Send a test notification (for development)
  Future<void> sendTestNotification() async {
    if (!_initialized) {
      debugPrint('⚠️ Service not initialized');
      return;
    }

    debugPrint('📤 Sending test notification...');

    // This would typically be triggered from the backend
    // For now, we'll show a local notification
    const androidDetails = AndroidNotificationDetails(
      'pinpoint_test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🎉 Test Notification',
      'This is a test notification from Pinpoint!',
      details,
    );

    debugPrint('✅ Test notification sent');
  }

  /// Unregister FCM token (when user logs out)
  Future<void> unregister() async {
    if (_deviceId == null) return;

    try {
      final apiService = ApiService();
      await apiService.removeFCMToken(_deviceId!);
      debugPrint('✅ FCM token unregistered');
    } catch (e) {
      debugPrint('❌ Failed to unregister token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    // Nothing to dispose for now
  }
}
