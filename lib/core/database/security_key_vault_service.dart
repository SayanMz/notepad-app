// Orchestrates the generation and hardware-backed storage of the master encryption
// key required for secure database persistence.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Stores the encryption key outside the app sandbox so Hive can reopen securely.
class SecureKeyVaultService {
  SecureKeyVaultService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _secureStorage;

  static const String _encryptionKeyToken = 'secure_persistence_encryption_key';

  static final SecureKeyVaultService _instance = SecureKeyVaultService();

  /// Legacy static access delegating to the default instance.
  static Future<List<int>> getOrCreateEncryptionKey() =>
      _instance.getOrCreateKey();

  /// Logic for retrieving or generating a hardware-backed encryption key.
  Future<List<int>> getOrCreateKey() async {
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
