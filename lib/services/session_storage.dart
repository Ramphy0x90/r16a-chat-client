import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  final _storage = const FlutterSecureStorage();
  static const _sessionKey = 'matrix_session';
  static const _storePassphraseKey = 'matrix_store_passphrase';

  Future<void> saveSession(String sessionJson) async {
    await _storage.write(key: _sessionKey, value: sessionJson);
  }

  Future<String?> loadSession() async {
    return _storage.read(key: _sessionKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  /// Passphrase encrypting the on-disk Matrix store (which holds E2EE keys).
  /// Generated once on first run, then reused.
  Future<String> loadOrCreateStorePassphrase() async {
    final existing = await _storage.read(key: _storePassphraseKey);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final passphrase = base64Url.encode(bytes);
    await _storage.write(key: _storePassphraseKey, value: passphrase);
    return passphrase;
  }
}
