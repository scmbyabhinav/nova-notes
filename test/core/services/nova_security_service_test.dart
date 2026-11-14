import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/core/services/nova_security_service.dart';

void main() {
  group('portable Vault encryption', () {
    const passphrase = 'correct horse battery staple 2026';

    test('payload can be decrypted independently with the backup passphrase', () async {
      final sourceDevice = NovaSecurityService();
      final destinationDevice = NovaSecurityService();
      const payload = '{"title":"Private plan","content":"Keep this secret"}';

      final envelope = await sourceDevice.encryptPortableVaultPayload(
        payload,
        passphrase,
      );
      expect(envelope, startsWith('orah-vault-portable:v1:'));

      final restored = await destinationDevice.decryptPortableVaultPayload(
        envelope,
        passphrase,
      );
      expect(restored, payload);
    });

    test('wrong passphrase is rejected', () async {
      final security = NovaSecurityService();
      final envelope = await security.encryptPortableVaultPayload(
        '{"content":"secret"}',
        passphrase,
      );

      await expectLater(
        security.decryptPortableVaultPayload(
          envelope,
          'a completely different passphrase',
        ),
        throwsA(anything),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final security = NovaSecurityService();
      final envelope = await security.encryptPortableVaultPayload(
        '{"content":"secret"}',
        passphrase,
      );
      const prefix = 'orah-vault-portable:v1:';
      final decoded = jsonDecode(envelope.substring(prefix.length)) as Map;
      final bytes = base64Url.decode(decoded['box'] as String);
      bytes[bytes.length - 1] ^= 1;
      decoded['box'] = base64UrlEncode(bytes);
      final tampered = prefix + jsonEncode(decoded);

      await expectLater(
        security.decryptPortableVaultPayload(tampered, passphrase),
        throwsA(anything),
      );
    });

    test('short passphrases are rejected for both encryption and decryption', () async {
      final security = NovaSecurityService();

      await expectLater(
        security.encryptPortableVaultPayload('secret', 'too-short'),
        throwsFormatException,
      );
      await expectLater(
        security.decryptPortableVaultPayload(
          'orah-vault-portable:v1:{}',
          'too-short',
        ),
        throwsFormatException,
      );
    });
  });
}
