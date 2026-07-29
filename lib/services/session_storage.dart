import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  final _storage = const FlutterSecureStorage();
  static const _sessionKey = 'matrix_session';

  Future<void> saveSession(String sessionJson) async {
    await _storage.write(key: _sessionKey, value: sessionJson);
  }

  Future<String?> loadSession() async {
    return _storage.read(key: _sessionKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
