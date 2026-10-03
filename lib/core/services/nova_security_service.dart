import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Local security foundation for ORAH.
///
/// PIN material is stored as a salted SHA-256 hash.
/// Private-note content uses a random 256-bit AES-GCM key. On Android the
/// key is held by flutter_secure_storage's Android Keystore-backed storage.
/// The note editor performs a strong biometric authentication before any
/// private-note ciphertext is decrypted.
class NovaSecurityService {
  static const _pinHashKey = 'nova_pin_hash_v1';
  static const _pinSaltKey = 'nova_pin_salt_v1';
  static const _appLockKey = 'nova_app_lock_enabled_v1';
  static const _biometricKey = 'nova_biometric_enabled_v1';
  static const _vaultKey = 'orah_private_vault_key_v1';
  static const _vaultPrefix = 'vault:v1:';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // This constructor selects the KeyStore-backed AES-GCM key path on Android.
  // The user-visible biometric gate is handled by local_auth immediately
  // before decrypting a private note.
  final FlutterSecureStorage _vaultStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: false,
      storageNamespace: 'orah_private_vault',
      biometricPromptTitle: 'ORAH private notes',
      biometricPromptSubtitle: 'Authenticate before accessing the vault key.',
    ),
  );

  final LocalAuthentication _auth = LocalAuthentication();
  final AesGcm _vaultCipher = AesGcm.with256bits();

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hash(pin, salt));
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
    await _storage.write(key: _appLockKey, value: enabled ? 'true' : 'false');
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
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
        localizedReason: 'Authenticate to access or lock a private ORAH note',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<String> encryptPrivatePayload(String clearText) async {
    final key = await _vaultSecretKey();
    final box = await _vaultCipher.encryptString(clearText, secretKey: key);
    return _vaultPrefix + base64UrlEncode(box.concatenation());
  }

  Future<String> decryptPrivatePayload(String encoded) async {
    if (!encoded.startsWith(_vaultPrefix)) {
      throw const FormatException(
        'Private note is not encrypted with the ORAH vault format.',
      );
    }
    final raw = base64Url.decode(encoded.substring(_vaultPrefix.length));
    final box = SecretBox.fromConcatenation(
      raw,
      nonceLength: _vaultCipher.nonceLength,
      macLength: _vaultCipher.macAlgorithm.macLength,
    );
    final key = await _vaultSecretKey();
    return _vaultCipher.decryptString(box, secretKey: key);
  }

  Future<SecretKey> _vaultSecretKey() async {
    final encoded = await _vaultStorage.read(key: _vaultKey);
    if (encoded != null && encoded.isNotEmpty) {
      final bytes = base64Url.decode(encoded);
      if (bytes.length != 32) {
        throw const FormatException('ORAH vault key has an invalid length.');
      }
      return SecretKeyData(Uint8List.fromList(bytes));
    }

    final key = await _vaultCipher.newSecretKey();
    final bytes = await key.extractBytes();
    if (bytes.length != 32) {
      throw StateError(
        'ORAH AES-256 key generation returned an invalid length.',
      );
    }
    await _vaultStorage.write(
      key: _vaultKey,
      value: base64UrlEncode(bytes),
    );
    return SecretKeyData(Uint8List.fromList(bytes));
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
