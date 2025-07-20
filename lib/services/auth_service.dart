import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

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
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle specific platform exceptions (e.g., not enrolled, locked out)
      print("Authentication error: ${e.message}");
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
