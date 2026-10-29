import 'package:dio/dio.dart';

import 'api_client.dart';

/// Neon Auth (Managed Better Auth) REST client.
///
/// The app signs in against Neon Auth directly. Better Auth's session credential
/// is the *signed session cookie value* (`<token>.<signature>`), captured from
/// `set-cookie` — this managed instance does not accept the raw token as a
/// Bearer. The app stores that signed value and sends it to our own API as its
/// Bearer credential; the API validates it by replaying it to `/get-session`.
class NeonAuthClient {
  NeonAuthClient(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          contentType: 'application/json',
          // Better Auth requires an Origin header; localhost origins are pre-approved.
          headers: {'Origin': 'http://localhost'},
          validateStatus: (_) => true, // error mapping reads the JSON body instead
        ),
      );

  static const sessionCookie = '__Secure-neon-auth.session_token';

  final Dio _dio;

  String? _signedSession(Response<dynamic> r) {
    for (final c in r.headers['set-cookie'] ?? const <String>[]) {
      if (c.startsWith('$sessionCookie=')) {
        return c.substring(sessionCookie.length + 1).split(';').first;
      }
    }
    return null;
  }

  Never _fail(dynamic data) {
    final body = data is Map ? data : const {};
    final code = body['code'] as String? ?? '';
    final message = switch (code) {
      'INVALID_EMAIL_OR_PASSWORD' => 'Email or password is incorrect.',
      'USER_ALREADY_EXISTS' || 'EMAIL_ALREADY_EXISTS' => 'An account with that email already exists.',
      _ => (body['message'] as String?) ?? 'Something went wrong. Try again in a moment.',
    };
    throw ApiError(switch (code) {
      'INVALID_EMAIL_OR_PASSWORD' => ApiErrorKind.invalidCredentials,
      'USER_ALREADY_EXISTS' || 'EMAIL_ALREADY_EXISTS' => ApiErrorKind.conflict,
      _ => ApiErrorKind.server,
    }, message);
  }

  Future<String> _call(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post<dynamic>(path, data: body);
      if (r.statusCode != 200) _fail(r.data);
      final signed = _signedSession(r);
      if (signed == null) _fail(null);
      return signed;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Returns the signed session value to store and send to our API.
  Future<String> signIn({required String email, required String password}) =>
      _call('/sign-in/email', {'email': email, 'password': password});

  /// Returns the signed session value to store and send to our API.
  Future<String> signUp({required String name, required String email, required String password}) =>
      _call('/sign-up/email', {'name': name, 'email': email, 'password': password});

  Future<void> signOut(String signedSession) async {
    try {
      await _dio.post<dynamic>('/sign-out', options: Options(headers: {'Cookie': '$sessionCookie=$signedSession'}));
    } on DioException {
      // Best effort: the local session ends either way.
    }
  }

  /// Better Auth emails a reset link (shared SMTP in dev). Always succeeds quietly.
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<dynamic>('/request-password-reset', data: {'email': email});
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }
}
