import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens in memory plus Android Keystore-backed secure storage. Never logged, never in shared_preferences.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage;

  final FlutterSecureStorage? _storage;
  String? accessToken, refreshToken;

  /// Neon Auth signed session cookie value; when present it is the credential sent to our API.
  String? neonSession;

  bool get hasSession => neonSession != null || refreshToken != null;

  Future<void> load() async {
    accessToken = await _storage?.read(key: 'access_token');
    refreshToken = await _storage?.read(key: 'refresh_token');
    neonSession = await _storage?.read(key: 'neon_session');
  }

  /// Saves to secure storage before updating memory, so a crash never loses a rotated token.
  Future<void> save(String access, String refresh) async {
    await _storage?.write(key: 'access_token', value: access);
    await _storage?.write(key: 'refresh_token', value: refresh);
    accessToken = access;
    refreshToken = refresh;
  }

  Future<void> saveNeon(String signedSession) async {
    await _storage?.write(key: 'neon_session', value: signedSession);
    neonSession = signedSession;
  }

  Future<void> clear() async {
    accessToken = refreshToken = null;
    await _storage?.deleteAll();
  }
}
