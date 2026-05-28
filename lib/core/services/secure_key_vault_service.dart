import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class SecureKeyVaultService {
  static const String _encryptionKeyToken = 'secure_persistence_encryption_key';

  // Enforce hardware-backed storage options for Android Keystore
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences:
          true, // Uses Keystore to encrypt the file keys
    ),
  );

  /// Retrieves an existing encryption key from the hardware vault or
  /// derives a brand-new 256-bit cryptographically secure key.
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

      // 🌟 KEY DERIVATION: Generate a cryptographically strong 256-bit key
      final secureKey = Hive.generateSecureKey();
      final base64Key = base64Url.encode(secureKey);

      // Persist the key inside the Hardware Key Vault
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
