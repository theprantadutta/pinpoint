import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'generated/l10n/app_localizations.dart';

import 'constants/shared_preference_keys.dart';
import 'design_system/design_system.dart';
import 'navigation/app_navigation.dart';
import 'service_locators/init_service_locators.dart';
import 'services/analytics/analytics_facade.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/backend_auth_service.dart';
import 'services/subscription_manager.dart';
import 'services/firebase_notification_service.dart';
import 'services/google_sign_in_service.dart';
import 'services/filter_service.dart';
import 'services/search_service.dart';
import 'services/connectivity_service.dart';
import 'services/app_update_service.dart';
import 'services/api_service.dart';
import 'services/theme_controller.dart';
import 'services/locale_controller.dart';
import 'services/refresh_rate_controller.dart';
import 'services/notification_channels.dart';
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

  // Silence all debugPrint output in release builds. debugPrint still prints in
  // release by default; several services log status (including encryption/sync
  // key handling) via debugPrint. Raw key bytes are never printed, but gagging
  // it in release avoids leaking any operational detail into device logs.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // All Google Fonts are bundled as app assets (assets/fonts/google_fonts/),
  // so never reach out to the network at runtime. This removes the
  // "Failed to load font with url: ..." crashes seen when a device is offline
  // or fonts.gstatic.com is unreachable. google_fonts discovers the bundled
  // TTFs automatically via the asset manifest.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    // Initialize core services first
    await _initializeCoreServices();

    // Set up Crashlytics error handlers (release mode only)
    if (!kDebugMode && Firebase.apps.isNotEmpty) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (FlutterErrorDetails details) {
        // Font loading happens via a fire-and-forget future inside
        // google_fonts; a failure there should never take down the app.
        // The fleather rich-text editor can also throw a null-check during an
        // animated scroll that rebuilds the selection overlay against a stale
        // position (RenderEditableContainerBox.childAtPosition) — a package
        // race we cannot fix and should not crash on.
        final nonFatal = _isNonFatalFontError(details.exception) ||
            _isNonFatalEditorError(details.stack);
        FirebaseCrashlytics.instance.recordFlutterError(
          details,
          fatal: !nonFatal,
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        final nonFatal =
            _isNonFatalFontError(error) || _isNonFatalEditorError(stack);
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: !nonFatal,
        );
        return true;
      };
      // The two handlers above only see the main isolate. Anything thrown in a
      // spawned isolate — `compute()`, and the background work drift and the
      // save queue hand off — dies silently otherwise, because an uncaught
      // isolate error never reaches this zone.
      //
      // The error arrives as a two-element list of strings, so the stack has to
      // be reconstructed rather than passed through.
      Isolate.current.addErrorListener(RawReceivePort((dynamic pair) async {
        final errorAndStacktrace = pair as List<dynamic>;
        final stack = errorAndStacktrace.last == null
            ? null
            : StackTrace.fromString(errorAndStacktrace.last as String);
        await FirebaseCrashlytics.instance.recordError(
          errorAndStacktrace.first,
          stack,
          fatal: true,
        );
      }).sendPort);
    }

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

    // Report to Crashlytics if available (release mode only)
    if (!kDebugMode) {
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
        }
      } catch (_) {}
    }

    // Run error app instead of crashing
    runApp(InitializationErrorApp(error: error.toString()));
  }
}

/// Whether [error] is a (non-fatal) google_fonts font-loading failure.
///
/// google_fonts loads each font in a fire-and-forget future with no
/// `catchError`, so a load failure surfaces as an unhandled async error in
/// `PlatformDispatcher.onError`. With fonts now bundled as assets this should
/// not happen, but we classify these so a stray font error is recorded as
/// non-fatal instead of crashing the app.
bool _isNonFatalFontError(Object? error) {
  final message = error.toString().toLowerCase();
  return message.contains('failed to load font') ||
      message.contains('google_fonts') ||
      message.contains('allowruntimefetching') ||
      (message.contains('font') &&
          message.contains('was not found in the application assets'));
}

/// Whether [stack] points at the known fleather editor selection/scroll race.
///
/// fleather's `RenderEditableContainerBox.childAtPosition` does
/// `return targetChild!;` and throws "Null check operator used on a null value"
/// when an animated scroll (`DrivenScrollActivity`) rebuilds the text-selection
/// overlay against a position whose render child no longer exists. It is a
/// package-internal race (present in the latest fleather, 1.27.0) that we cannot
/// fix from app code. We only ever downgrade fatal -> non-fatal here, and only
/// when the stack is clearly from fleather's editor, so unrelated null-check
/// bugs are never masked. No-op on obfuscated release stacks (matches nothing).
bool _isNonFatalEditorError(StackTrace? stack) {
  if (stack == null) return false;
  final frames = stack.toString();
  return frames.contains('childAtPosition') ||
      frames.contains('EditorTextSelectionOverlay') ||
      frames.contains('RenderEditableContainerBox') ||
      frames.contains('editable_box.dart') ||
      frames.contains('editable_text_block.dart');
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

  // Initialize connectivity monitoring (fast, local) so the offline indicator
  // and offline-first logic have an accurate status from launch.
  try {
    await ConnectivityService().initialize();
  } catch (e) {
    debugPrint('⚠️ [main.dart] Connectivity service not initialized: $e');
  }

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

  // NOTE: Firebase core initializes here so Crashlytics can capture crashes from first frame.
  // FirebaseNotificationService (the slow part) still initializes in background.
  try {
    debugPrint('🔥 [main.dart] Initializing Firebase core...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ [main.dart] Firebase core initialized');
  } catch (e, stackTrace) {
    debugPrint('⚠️ [main.dart] Firebase core init failed: $e');
    debugPrint('⚠️ [main.dart] Stack trace: $stackTrace');
  }

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

    // Flush queued analytics events now that Firebase is ready
    getIt<AnalyticsFacade>().onFirebaseReady();
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
      // These run outside the main app shell, so they need their own
      // Localizations — without this AppL10n.of() below has nothing to read.
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: LocaleController.supportedLocales,
      // onGenerateTitle rather than `title`: the latter is evaluated with the
      // context *above* MaterialApp, where Localizations does not yet exist.
      onGenerateTitle: (context) => AppL10n.of(context).startupAuthRequired,
      // Builder for the same reason as onGenerateTitle above: `home` is
      // evaluated here, with build's own context, which sits *above* the
      // Localizations this MaterialApp installs. Reading AppL10n from it finds
      // nothing and throws on the null check.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  AppL10n.of(context).startupAuthFailed,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  AppL10n.of(context).startupRestartApp,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Try authentication again
                    _retryAuthentication();
                  },
                  child: Text(AppL10n.of(context).startupTryAgain),
                ),
              ],
            ),
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
      // These run outside the main app shell, so they need their own
      // Localizations — without this AppL10n.of() below has nothing to read.
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: LocaleController.supportedLocales,
      // onGenerateTitle rather than `title`: the latter is evaluated with the
      // context *above* MaterialApp, where Localizations does not yet exist.
      onGenerateTitle: (context) => AppL10n.of(context).startupInitError,
      // Builder for the same reason as onGenerateTitle above: `home` is
      // evaluated here, with build's own context, which sits *above* the
      // Localizations this MaterialApp installs. Reading AppL10n from it finds
      // nothing and throws on the null check.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    AppL10n.of(context).startupInitFailed,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppL10n.of(context).startupErrorDetail(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app
                      main();
                    },
                    child: Text(AppL10n.of(context).commonRetry),
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
                  Text(
                    AppL10n.of(context).updateRequiredTitle,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    AppL10n.of(context).updateRequiredBody,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppL10n.of(context).updateRequiredNote,
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.download_rounded, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  AppL10n.of(context).updateNow,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isBiometricEnabled = false;
  SharedPreferences? _sharedPreferences;

  /// Appearance (theme mode / accent / contrast / font) is owned by
  /// [ThemeController] — a reactive ChangeNotifier provided below. Only the
  /// non-theme biometric toggle remains here.
  final ThemeController _themeController = ThemeController();

  /// Language selection, owned the same way as appearance so switching it
  /// re-renders the app without a restart.
  final LocaleController _localeController = LocaleController();

  bool get isBiometricEnabled => _isBiometricEnabled;

  void changeBiometricEnabledEnabled(bool isisBiometricEnabled) {
    setState(() {
      _isBiometricEnabled = isisBiometricEnabled;
      _sharedPreferences?.setBool(kBiometricKey, isisBiometricEnabled);
    });
    getIt<AnalyticsFacade>().trackBiometricToggled(enabled: isisBiometricEnabled);
  }

  Future<void> initializeSharedPreferences() async {
    _sharedPreferences = await SharedPreferences.getInstance();

    // Load appearance preferences into the reactive controller.
    await _themeController.load();

    // Load the language choice before the first frame so the app never
    // renders English and then visibly switches.
    await _localeController.load();

    // Reads the stored preference and pushes it to the display. Doing it here
    // rather than in initState means the very first frame is already drawn at
    // the rate the user asked for.
    await _refreshRateController.load();

    // Load biometric setting
    final isFingerPrintEnabled = _sharedPreferences?.getBool(kBiometricKey);
    if (isFingerPrintEnabled != null) {
      setState(() => _isBiometricEnabled = isFingerPrintEnabled);
    }
  }

  /// Owns the "smooth motion" preference and pushes it to the display.
  ///
  /// Replaces a `flutter_displaymode` call that forced the highest Android
  /// mode unconditionally, with no way for the user to decline and no iOS
  /// path. [RefreshRateController] is cross-platform, honours a stored
  /// preference, and is re-applied on resume — see [didChangeAppLifecycleState].
  final RefreshRateController _refreshRateController = RefreshRateController();

  bool _updateCheckCompleted = false;
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    // Watch for resume so the display preference can be re-asserted; Android
    // discards the window's preferred mode whenever the app is backgrounded.
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Android drops the window's preferred display mode when the app goes to
    // the background, so a task switch would otherwise leave the app stuck at
    // 60 Hz until the next cold start. Re-assert it on the way back in.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshRateController.apply());
    }
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
        // Its own shell, shown before the main app builds, so it needs its
        // own Localizations.
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: LocaleController.supportedLocales,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const UpdateRequiredScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeController),
        ChangeNotifierProvider.value(value: _localeController),
        ChangeNotifierProvider.value(value: _refreshRateController),
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
        ChangeNotifierProvider.value(
          value: ConnectivityService(),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeController, localeController, _) {
          return MaterialApp.router(
            localizationsDelegates: const [
              AppL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: LocaleController.supportedLocales,
            // Null means "follow the device", which is Flutter's own default
            // resolution behaviour; a non-null value pins the app.
            locale: localeController.locale,
            title: 'Pinpoint',
            // NOTE: the explicit router pieces (instead of `routerConfig`) are
            // used so we can supply a guarded back-button dispatcher that
            // shields against a go_router `popRoute` null-check crash.
            routerDelegate: AppNavigation.router.routerDelegate,
            routeInformationParser: AppNavigation.router.routeInformationParser,
            routeInformationProvider:
                AppNavigation.router.routeInformationProvider,
            backButtonDispatcher: AppNavigation.backButtonDispatcher,
            // Keeps the Android notification channels in the app's language.
            // Sits inside MaterialApp because it needs Localizations, which is
            // only available below this point in the tree.
            builder: (context, child) =>
                _LocalizedNotificationChannels(child: child ?? const SizedBox.shrink()),
            themeMode: themeController.mode,
            theme: PinpointTheme.light(
              accentColor: themeController.accent,
              highContrast: themeController.highContrast,
              fontFamily: themeController.fontFamily,
            ),
            darkTheme: PinpointTheme.dark(
              accentColor: themeController.accent,
              highContrast: themeController.highContrast,
              fontFamily: themeController.fontFamily,
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

/// Keeps the Android notification channels named in the app's current language.
///
/// Channel names live in the OS settings UI, not the app, and Android freezes
/// them at creation time — so switching language has no effect unless the
/// channels are deleted and recreated. This runs that sync whenever the
/// resolved locale changes.
///
/// It is a widget rather than a startup call because it needs [Localizations],
/// which only exists below [MaterialApp]. Depending on the locale here also
/// means [didChangeDependencies] re-fires on a language change for free.
class _LocalizedNotificationChannels extends StatefulWidget {
  const _LocalizedNotificationChannels({required this.child});

  final Widget child;

  @override
  State<_LocalizedNotificationChannels> createState() =>
      _LocalizedNotificationChannelsState();
}

class _LocalizedNotificationChannelsState
    extends State<_LocalizedNotificationChannels> {
  Locale? _syncedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = Localizations.localeOf(context);
    if (_syncedFor == locale) return;
    _syncedFor = locale;

    // Non-blocking and self-guarding: NotificationChannels no-ops unless the
    // stored locale actually differs, so this is cheap on a normal start.
    unawaited(
      NotificationChannels.syncWithLocale(
        context,
        FirebaseNotificationService().localNotificationsPlugin,
      ).catchError((Object e) {
        debugPrint('⚠️ Notification channel localization failed: $e');
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
