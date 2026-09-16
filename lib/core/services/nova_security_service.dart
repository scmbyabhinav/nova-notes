
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Local security foundation for NOVA.
///
/// PIN material is stored in secure storage as a salted SHA-256 hash.
/// Biometric authentication is delegated to the OS through local_auth.
class NovaSecurityService {
  static const _pinHashKey = 'nova_pin_hash_v1';
  static const _pinSaltKey = 'nova_pin_salt_v1';
  static const _appLockKey = 'nova_app_lock_enabled_v1';
  static const _biometricKey = 'nova_biometric_enabled_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(
      key: _pinHashKey,
      value: _hash(pin, salt),
    );
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await setAppLockEnabled(false);
    await setBiometricEnabled(false);
  }

  Future<bool> isAppLockEnabled() async =>
      (await _storage.read(key: _appLockKey)) == 'true';

  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(
      key: _appLockKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final available = await _auth.getAvailableBiometrics();
      return supported && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock NOVA Notes',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
