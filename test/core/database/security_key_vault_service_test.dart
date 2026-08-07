import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/security_key_vault_service.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data.containsKey(key);
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    }
  }
}

void main() {
  group('SecureKeyVaultService', () {
    test('getOrCreateKey generates a new key if none exists', () async {
      final storage = FakeSecureStorage();
      final service = SecureKeyVaultService(secureStorage: storage);

      final key = await service.getOrCreateKey();

      // Hive AES-256 keys are 32 bytes (256 bits)
      expect(key, hasLength(32));
      expect(await storage.containsKey(key: 'secure_persistence_encryption_key'), isTrue);
    });

    test('getOrCreateKey reuses existing key if present', () async {
      final storage = FakeSecureStorage();
      final originalKey = List<int>.generate(32, (i) => i);
      final base64Key = base64Url.encode(originalKey);
      await storage.write(key: 'secure_persistence_encryption_key', value: base64Key);

      final service = SecureKeyVaultService(secureStorage: storage);
      final retrievedKey = await service.getOrCreateKey();

      expect(retrievedKey, originalKey);
    });
  });
}
