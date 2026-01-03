import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants/shared_preference_keys.dart';
import 'design_system/design_system.dart';
import 'navigation/app_navigation.dart';
import 'service_locators/init_service_locators.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/backend_auth_service.dart';
import 'services/subscription_manager.dart';
import 'services/firebase_notification_service.dart';
import 'services/google_sign_in_service.dart';
import 'services/filter_service.dart';
import 'services/search_service.dart';
import 'services/app_update_service.dart';
import 'services/api_service.dart';
import 'screens/auth_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // await dotenv.load();
//   initServiceLocators();
//   await NotificationService.init(); // Initialize notification service

//   final sharedPreferences = await SharedPreferences.getInstance();
//   final isBiometricEnabled = sharedPreferences.getBool(kBiometricKey) ?? false;

//   if (isBiometricEnabled) {
//     bool authenticated = await AuthService.authenticate();
//     if (!authenticated) {
//       // If authentication fails, exit the app
//       // This is a simple exit, in a real app you might show an error screen or retry
//       return;
//     }
//   }

//   await     SecureEncryptionService.initialize();
//   runApp(
//     MyApp(),
//   );
// }

void main() async {
  // Always call this first in async main
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize core services first
    await _initializeCoreServices();

    // Handle biometric authentication
    final shouldAuthenticate = await _shouldShowBiometricAuth();

    if (shouldAuthenticate) {
      final isAuthenticated = await _handleBiometricAuth();
      if (!isAuthenticated) {
        // Run app with authentication failure state
        runApp(const AuthenticationFailedApp());
        return;
      }
    }

    // DON'T initialize encryption here - wait until after authentication check
    // Encryption will be initialized in:
    // 1. Splash screen (if authenticated)
    // 2. Auth screen (after successful login)
    debugPrint(
        '🔑 [main.dart] Skipping encryption initialization - will initialize after auth check');

    // Run the main app
    // Update check happens AFTER app renders (in MyApp.initState)
    runApp(const MyApp());
  } catch (error, stackTrace) {
    // Handle initialization errors gracefully
    debugPrint('App initialization error: $error');
    debugPrint('Stack trace: $stackTrace');

    // Run error app instead of crashing
    runApp(InitializationErrorApp(error: error.toString()));
  }
}

Future<void> _initializeCoreServices() async {
  // Load environment variables first (needed for Google Sign-In Web Client ID)
  try {
    debugPrint('🔧 [main.dart] Loading environment variables...');
    await dotenv.load(fileName: '.env');
    debugPrint('✅ [main.dart] Environment variables loaded');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] Failed to load .env file: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
    // Continue without .env - some features may not work
  }

  initServiceLocators(); // Assuming this is synchronous

  // Initialize notification service (fast, local only)
  await NotificationService.init();

  // Initialize Google Sign-In service (fast, no network call)
  try {
    debugPrint('🔐 [main.dart] Initializing Google Sign-In...');
    GoogleSignInService();
    debugPrint('✅ [main.dart] Google Sign-In service initialized');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] Google Sign-In not initialized: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
  }

  // Initialize FilterService (fast, local only)
  try {
    debugPrint('🔍 [main.dart] Initializing FilterService...');
    final filterService = FilterService();
    await filterService.initialize();
    debugPrint('✅ [main.dart] FilterService initialized');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] FilterService not initialized: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
  }

  // NOTE: Firebase initialization moved to background (see _initializeFirebaseInBackground)
  // This prevents Firebase from blocking app startup

  // NOTE: Sync manager initialization moved to auth_screen.dart
  // It needs to happen AFTER authentication, not at app startup
  // See auth_screen.dart -> _performInitialSync()

  // NOTE: SubscriptionService and PremiumService initialization moved to home_screen.dart
  // These services make API calls that require authentication, so they should only
  // initialize after the user has logged in.
  // See home_screen.dart -> _initializeAuthenticatedServices()
}

/// Initialize Firebase in background - non-blocking
/// Called via addPostFrameCallback after first frame renders
Future<void> _initializeFirebaseInBackground() async {
  try {
    debugPrint('🔔 [main.dart] Initializing Firebase in background...');
    final firebaseNotifications = FirebaseNotificationService();
    await firebaseNotifications.initialize();
    debugPrint('✅ [main.dart] Firebase notifications initialized');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] Firebase notifications not initialized: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
    // Continue without Firebase - app will still work
  }
}

Future<bool> _shouldShowBiometricAuth() async {
  try {
    final sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(kBiometricKey) ?? false;
  } catch (e) {
    debugPrint('Error checking biometric preference: $e');
    return false; // Default to no auth if there's an error
  }
}

Future<bool> _handleBiometricAuth() async {
  try {
    return await AuthService.authenticate();
  } catch (e) {
    debugPrint('Biometric authentication error: $e');
    return false;
  }
}

// Error handling apps
class AuthenticationFailedApp extends StatelessWidget {
  const AuthenticationFailedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentication Required',
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Authentication Failed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Please restart the app and try again',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Try authentication again
                  _retryAuthentication();
                },
                child: Text('Try Again'),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Exit the app
                  FlutterExitApp.exitApp(iosForceExit: true);
                },
                child: Text('Exit App'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retryAuthentication() async {
    final isAuthenticated = await _handleBiometricAuth();
    if (isAuthenticated) {
      // Don't initialize encryption here - it will be done in splash screen
      runApp(const MyApp());
    }
  }
}

class InitializationErrorApp extends StatelessWidget {
  final String error;

  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Initialization Error',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'App Initialization Failed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Error: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen shown when a mandatory update is required.
/// This blocks the user from using the app until they update.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _isUpdating = false;

  Future<void> _retryUpdate() async {
    setState(() => _isUpdating = true);

    try {
      final updateService = AppUpdateService();
      final hasUpdate = await updateService.checkForUpdate();

      if (hasUpdate) {
        await updateService.performImmediateUpdate();
      } else {
        // No update needed anymore, restart app
        if (mounted) {
          // Pop back to allow normal app flow
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button from dismissing
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Update icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update,
                      size: 64,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Update Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'A new version of Pinpoint is available. '
                    'Please update to continue using the app.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This update includes important improvements and bug fixes.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Update button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _retryUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            Colors.amber.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download_rounded, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Update Now',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Exit button
                  TextButton(
                    onPressed: () {
                      FlutterExitApp.exitApp(iosForceExit: true);
                    },
                    child: Text(
                      'Exit App',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  //https://gist.github.com/ben-xx/10000ed3bf44e0143cf0fe7ac5648254
  // ignore: library_private_types_in_public_api
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Dark-first design
  Color _accentColor = PinpointColors.mint; // Default accent
  bool _isBiometricEnabled = false;
  bool _highContrastMode = false;
  String _fontFamily = 'Inter'; // Default font
  SharedPreferences? _sharedPreferences;

  /// Accent color presets
  // static const List<Color> _accentColors = [
  //   PinpointColors.mint,
  //   PinpointColors.iris,
  //   PinpointColors.rose,
  //   PinpointColors.amber,
  //   PinpointColors.ocean,
  // ];

  /// This is needed for components that may have a different theme data
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get accentColor => _accentColor;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get highContrastMode => _highContrastMode;
  String get fontFamily => _fontFamily;

  void changeBiometricEnabledEnabled(bool isisBiometricEnabled) {
    setState(() {
      _isBiometricEnabled = isisBiometricEnabled;
      _sharedPreferences?.setBool(kBiometricKey, isisBiometricEnabled);
    });
  }

  void changeAccentColor(Color color) {
    setState(() {
      _accentColor = color;
      _sharedPreferences?.setInt('accent_color', color.toARGB32());
    });
  }

  void changeHighContrastMode(bool enabled) {
    setState(() {
      _highContrastMode = enabled;
      _sharedPreferences?.setBool('high_contrast', enabled);
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
      _sharedPreferences?.setBool(kIsDarkModeKey, themeMode == ThemeMode.dark);
    });
  }

  void changeFontFamily(String fontFamily) {
    setState(() {
      _fontFamily = fontFamily;
      _sharedPreferences?.setString(kSelectedFontKey, fontFamily);
    });
  }

  Future<void> initializeSharedPreferences() async {
    _sharedPreferences = await SharedPreferences.getInstance();

    // Load theme mode
    final isDarkMode = _sharedPreferences?.getBool(kIsDarkModeKey);
    if (isDarkMode != null) {
      setState(
        () => _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light,
      );
    }

    // Load accent color
    final accentColorValue = _sharedPreferences?.getInt('accent_color');
    if (accentColorValue != null) {
      setState(() => _accentColor = Color(accentColorValue));
    }

    // Load high contrast mode
    final highContrast = _sharedPreferences?.getBool('high_contrast');
    if (highContrast != null) {
      setState(() => _highContrastMode = highContrast);
    }

    // Load biometric setting
    final isFingerPrintEnabled = _sharedPreferences?.getBool(kBiometricKey);
    if (isFingerPrintEnabled != null) {
      setState(() => _isBiometricEnabled = isFingerPrintEnabled);
    }

    // Load font family
    final fontFamily = _sharedPreferences?.getString(kSelectedFontKey);
    if (fontFamily != null) {
      setState(() => _fontFamily = fontFamily);
    }
  }

  Future<void> setOptimalDisplayMode() async {
    final List<DisplayMode> supported = await FlutterDisplayMode.supported;
    final DisplayMode active = await FlutterDisplayMode.active;

    final List<DisplayMode> sameResolution = supported
        .where((DisplayMode m) =>
            m.width == active.width && m.height == active.height)
        .toList()
      ..sort((DisplayMode a, DisplayMode b) =>
          b.refreshRate.compareTo(a.refreshRate));

    final DisplayMode mostOptimalMode =
        sameResolution.isNotEmpty ? sameResolution.first : active;

    await FlutterDisplayMode.setPreferredMode(mostOptimalMode);
  }

  bool _updateCheckCompleted = false;
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    setOptimalDisplayMode();
    initializeSharedPreferences();

    // Register session expiry handler for automatic token refresh failures
    _registerSessionExpiryHandler();

    // Initialize background tasks AFTER the first frame renders
    // This ensures the UI loads quickly and non-critical tasks run later
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize Firebase in background (non-blocking)
      _initializeFirebaseInBackground();

      // Check for updates
      _checkForMandatoryUpdate();
    });
  }

  /// Register callback for when user session expires (refresh token also expired)
  void _registerSessionExpiryHandler() {
    ApiService().onSessionExpired = () {
      debugPrint('⚠️ [MyApp] Session expired - redirecting to login');

      // Navigate to auth screen using GoRouter
      // We need to do this after the current frame to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Get the root navigator context and navigate to auth
        AppNavigation.router.go(AuthScreen.kRouteName);
      });
    };
  }

  /// Check for mandatory app updates from Google Play Store.
  /// Called after the first frame is rendered so app loads quickly.
  Future<void> _checkForMandatoryUpdate() async {
    // Only check on Android and only once
    if (!Platform.isAndroid || _updateCheckCompleted) return;
    _updateCheckCompleted = true;

    try {
      debugPrint('🔄 [MyApp] Checking for app updates...');
      final updateService = AppUpdateService();
      final hasUpdate = await updateService.checkForUpdate();

      if (hasUpdate) {
        debugPrint('⚠️ [MyApp] Update available - forcing immediate update');

        // Try immediate update first
        final updateStarted = await updateService.performImmediateUpdate();

        if (!updateStarted && mounted) {
          // If immediate update fails, show blocking update screen
          debugPrint('❌ [MyApp] Immediate update failed - showing update screen');
          setState(() => _updateRequired = true);
        }
      } else {
        debugPrint('✅ [MyApp] App is up to date');
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ [MyApp] Update check failed: $e');
      debugPrint('⚠️ [MyApp] Stack trace: $stackTrace');
      // Don't block the app if update check fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // If update is required, show blocking update screen
    if (_updateRequired) {
      return MaterialApp(
        title: 'Pinpoint',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const UpdateRequiredScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: SubscriptionManager()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => BackendAuthService()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => FilterService(),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchService()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        title: 'Pinpoint',
        routerConfig: AppNavigation.router,
        themeMode: _themeMode,
        theme: PinpointTheme.light(
          accentColor: _accentColor,
          highContrast: _highContrastMode,
          fontFamily: _fontFamily,
        ),
        darkTheme: PinpointTheme.dark(
          accentColor: _accentColor,
          highContrast: _highContrastMode,
          fontFamily: _fontFamily,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
