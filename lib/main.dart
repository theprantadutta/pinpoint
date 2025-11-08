import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:provider/provider.dart';

import 'constants/shared_preference_keys.dart';
import 'design_system/design_system.dart';
import 'navigation/app_navigation.dart';
import 'service_locators/init_service_locators.dart';
import 'services/encryption_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/subscription_manager.dart';
import 'services/firebase_notification_service.dart';
import 'sync/sync_manager.dart';

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

    // Initialize encryption service after authentication
    await SecureEncryptionService.initialize();

    // Run the main app
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
  // Initialize services in order of dependency
  // await dotenv.load(); // Uncomment if using dotenv

  initServiceLocators(); // Assuming this is synchronous

  await NotificationService.init();

  // Initialize Firebase notifications
  try {
    debugPrint('🔔 [main.dart] Initializing Firebase notifications...');
    final firebaseNotifications = FirebaseNotificationService();
    await firebaseNotifications.initialize();
    debugPrint('✅ [main.dart] Firebase notifications initialized');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] Firebase notifications not initialized: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
    // Continue without Firebase - app will still work
  }

  // Initialize sync manager
  final syncManager = getIt<SyncManager>();
  await syncManager.init();

  // Add any other core services here
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
      await SecureEncryptionService.initialize();
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
  SharedPreferences? _sharedPreferences;

  /// Accent color presets
  static const List<Color> _accentColors = [
    PinpointColors.mint,
    PinpointColors.iris,
    PinpointColors.rose,
    PinpointColors.amber,
    PinpointColors.ocean,
  ];

  /// This is needed for components that may have a different theme data
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get accentColor => _accentColor;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get highContrastMode => _highContrastMode;

  void changeBiometricEnabledEnabled(bool isisBiometricEnabled) {
    setState(() {
      _isBiometricEnabled = isisBiometricEnabled;
      _sharedPreferences?.setBool(kBiometricKey, isisBiometricEnabled);
    });
  }

  void changeAccentColor(Color color) {
    setState(() {
      _accentColor = color;
      _sharedPreferences?.setInt('accent_color', color.value);
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

  @override
  void initState() {
    super.initState();
    setOptimalDisplayMode();
    initializeSharedPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SubscriptionManager()..initialize(),
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
        ),
        darkTheme: PinpointTheme.dark(
          accentColor: _accentColor,
          highContrast: _highContrastMode,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
