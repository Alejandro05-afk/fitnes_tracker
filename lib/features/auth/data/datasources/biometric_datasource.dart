import 'package:local_auth/local_auth.dart';
import '../../domain/entities/auth_result.dart';

abstract class BiometricDataSource {
  Future<bool> canAuthenticate();
  Future<AuthResult> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  BiometricDataSourceImpl() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      final isAvailable = await _auth.isDeviceSupported();
      if (!isAvailable) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Usa tu huella o Face ID para acceder',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return AuthResult(
        success: didAuth,
        message: didAuth ? 'Autenticación exitosa' : 'Autenticación cancelada',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }
}
