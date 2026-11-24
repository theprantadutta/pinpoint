import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/terms_acceptance_screen.dart';

/// Whether an expired session should send the user from [path] to the
/// sign-in screen. Not from the screens a signed-out person is meant to be
/// on: the splash (it routes by itself), onboarding with its legal reader,
/// and the sign-in screen itself.
bool sessionExpiryShouldRedirect(String path) => !const {
      SplashScreen.kRouteName,
      OnboardingScreen.kRouteName,
      TermsAcceptanceScreen.kRouteName,
      AuthScreen.kRouteName,
    }.contains(path);
