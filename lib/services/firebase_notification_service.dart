import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pinpoint/firebase_options.dart';
import 'dart:io';

/// Navigation intent from notification tap
class NotificationNavigationIntent {
  final String type;
  final String? noteUuid;
  final String? noteType;
  final String? reminderId;
  final Map<String, dynamic> rawData;

  NotificationNavigationIntent({
    required this.type,
    this.noteUuid,
    this.noteType,
    this.reminderId,
    required this.rawData,
  });

  @override
  String toString() =>
      'NotificationNavigationIntent(type: $type, noteUuid: $noteUuid, noteType: $noteType, reminderId: $reminderId)';
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
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
  bool _tokenRegisteredThisSession = false;

  // Stream subscriptions for proper cleanup
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  // Stream controller for navigation intents
  final _navigationIntentController =
      StreamController<NotificationNavigationIntent>.broadcast();

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  /// Stream of navigation intents from notification taps
  /// Listen to this in your app to handle navigation
  Stream<NotificationNavigationIntent> get navigationIntents =>
      _navigationIntentController.stream;

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
        debugPrint(
            '✅ Firebase already initialized with ${Firebase.apps.length} apps');
      }

      // Initialize FirebaseMessaging instance AFTER Firebase is initialized
      _firebaseMessaging = FirebaseMessaging.instance;
      debugPrint('✅ FirebaseMessaging instance created');

      // NOTE: Permissions are requested separately on HomeScreen after login
      // Firebase can still get tokens and receive messages without explicit permission request here
      // The permission will be granted when NotificationService.requestBasicNotificationPermission() is called

      // Initialize local notifications (without requesting permissions)
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      await _setupMessageHandlers();

      // Get device ID
      await _getDeviceId();

      // Note: FCM token registration with backend happens after user authentication
      // Call registerTokenWithBackend() manually after successful login

      _initialized = true;
      debugPrint('✅ Firebase Notification Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize Firebase Notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Propagate error to main.dart for better visibility
    }
  }

  /// Initialize local notifications for showing notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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

      // Listen for token refresh (cancel any existing subscription first)
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        registerTokenWithBackend(force: true); // Auto-register on token refresh
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
  /// Should be called after successful user authentication
  /// Only registers once per app session to reduce API calls
  Future<void> registerTokenWithBackend({bool force = false}) async {
    // Skip if already registered this session (unless forced)
    if (_tokenRegisteredThisSession && !force) {
      debugPrint('⏭️ FCM token already registered this session, skipping');
      return;
    }

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

      _tokenRegisteredThisSession = true;
      debugPrint('✅ FCM token registered with backend');
    } catch (e) {
      debugPrint('⚠️ Failed to register FCM token with backend: $e');
      // Don't throw - this is non-critical, token will be registered on next login
    }
  }

  /// Set up message handlers for different app states
  Future<void> _setupMessageHandlers() async {
    // Background message handler (already registered at top level)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Cancel any existing subscriptions first
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedAppSubscription?.cancel();

    // Foreground messages
    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Messages when app is opened from notification
    _onMessageOpenedAppSubscription =
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

  /// Handle notification tap from local notifications
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');

    if (response.payload == null || response.payload!.isEmpty) {
      debugPrint('⚠️ No payload in notification');
      return;
    }

    try {
      // Try to parse the payload as JSON
      // The payload might be a toString() of a Map, so we need to handle that
      Map<String, dynamic> data;

      if (response.payload!.startsWith('{')) {
        data = json.decode(response.payload!);
      } else {
        // Payload might be in format: {key: value, key2: value2}
        // This is the toString() format of a Map
        debugPrint('⚠️ Payload is not valid JSON, attempting to parse: ${response.payload}');
        // For now, just create an empty data map
        data = {'raw_payload': response.payload};
      }

      _handleNotificationData(data);
    } catch (e) {
      debugPrint('❌ Error parsing notification payload: $e');
    }
  }

  /// Handle notification data and emit navigation intent
  void _handleNotificationData(Map<String, dynamic> data) {
    debugPrint('📱 Handling notification data: $data');

    final type = data['type'] as String? ?? 'unknown';
    final noteUuid = data['note_uuid'] as String? ?? data['note_id'] as String?;
    final noteType = data['note_type'] as String?;
    final reminderId = data['reminder_id'] as String?;

    // Create navigation intent
    final intent = NotificationNavigationIntent(
      type: type,
      noteUuid: noteUuid,
      noteType: noteType,
      reminderId: reminderId,
      rawData: data,
    );

    debugPrint('📱 Emitting navigation intent: $intent');
    _navigationIntentController.add(intent);

    // Log specific navigation actions for debugging
    if (type == 'reminder' && noteUuid != null) {
      debugPrint('🔔 Navigate to reminder note: $noteUuid (type: $noteType)');
    } else if (type == 'sync_complete') {
      debugPrint('✅ Sync completed notification');
    } else {
      debugPrint('ℹ️ Unhandled notification type: $type');
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

  /// Dispose resources and cancel all stream subscriptions
  Future<void> dispose() async {
    debugPrint('🧹 Disposing FirebaseNotificationService...');

    // Cancel all stream subscriptions
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    await _onMessageSubscription?.cancel();
    _onMessageSubscription = null;

    await _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;

    // Close the navigation intent stream controller
    await _navigationIntentController.close();

    _initialized = false;
    _tokenRegisteredThisSession = false;

    debugPrint('✅ FirebaseNotificationService disposed');
  }
}
