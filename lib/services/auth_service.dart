import 'package:local_auth/local_auth.dart';
import 'package:pinpoint/services/logger_service.dart';

class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> authenticate() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    if (!canCheckBiometrics) {
      return true; // Biometrics not available, proceed without authentication
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Pinpoint',
      );
    } catch (e) {
      // Handle authentication exceptions
      log.e("Authentication error: $e");
      return false;
    }
  }

  static Future<bool> isBiometricAvailable() async {
    return await _localAuth.canCheckBiometrics;
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }
}
