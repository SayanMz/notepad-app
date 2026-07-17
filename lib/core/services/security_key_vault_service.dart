// Encryption keys are stored externally so Hive can reopen the database securely.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

// Stores the encryption key outside the app sandbox so Hive can reopen securely.
class SecureKeyVaultService {
  static const String _encryptionKeyToken = 'secure_persistence_encryption_key';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static Future<List<int>> getOrCreateEncryptionKey() async {
    try {
      final containsKey = await _secureStorage.containsKey(
        key: _encryptionKeyToken,
      );

      if (containsKey) {
        final stringKey = await _secureStorage.read(key: _encryptionKeyToken);
        if (stringKey != null) {
          return base64Url.decode(stringKey);
        }
      }

      final secureKey = Hive.generateSecureKey();
      final base64Key = base64Url.encode(secureKey);

      await _secureStorage.write(key: _encryptionKeyToken, value: base64Key);

      debugPrint(
        'SecureKeyVault: New hardware-backed key generated and stored.',
      );
      return secureKey;
    } catch (e) {
      debugPrint(
        'SecureKeyVault CRITICAL Error: Hardware key derivation failed! $e',
      );
      rethrow;
    }
  }
}
