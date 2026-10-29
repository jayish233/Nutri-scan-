import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';

enum ApiErrorKind {
  invalidCredentials,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  notFood,
  rateLimited,
  quotaExceeded,
  payloadTooLarge,
  aiUnavailable,
  server,
  network,
  cancelled,
  decoding,
}

class ApiError implements Exception {
  const ApiError(this.kind, this.message, {this.fields = const {}, this.resetAt});

  final ApiErrorKind kind;
  final String message;
  final Map<String, String> fields;
  final DateTime? resetAt;

  static const _codes = {
    'invalid_credentials': ApiErrorKind.invalidCredentials,
    'unauthorized': ApiErrorKind.unauthorized,
    'forbidden': ApiErrorKind.forbidden,
    'not_found': ApiErrorKind.notFound,
    'validation_failed': ApiErrorKind.validation,
    'conflict': ApiErrorKind.conflict,
    'not_food': ApiErrorKind.notFood,
    'rate_limited': ApiErrorKind.rateLimited,
    'quota_exceeded': ApiErrorKind.quotaExceeded,
    'payload_too_large': ApiErrorKind.payloadTooLarge,
    'ai_unavailable': ApiErrorKind.aiUnavailable,
    'server_error': ApiErrorKind.server,
  };

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is! DioException) return const ApiError(ApiErrorKind.decoding, 'Something unexpected came back. Try again.');
    if (e.error is ApiError) return e.error as ApiError;
    if (e.type == DioExceptionType.cancel) return const ApiError(ApiErrorKind.cancelled, 'Cancelled.');
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiError(
        _codes[err['code']] ?? ApiErrorKind.server,
        err['message'] as String? ?? 'Something went wrong.',
        fields: ((err['fields'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
        resetAt: err['reset_at'] == null ? null : DateTime.tryParse(err['reset_at'] as String),
      );
    }
    if (e.response == null) {
      return const ApiError(ApiErrorKind.network, "Can't reach NutriScan. Check your connection and try again.");
    }
    return const ApiError(ApiErrorKind.server, 'Something went wrong. Try again in a moment.');
  }

  @override
  String toString() => message;
}

/// Dio client with the bearer header, one shared token refresh for every 401, and GET retries.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    HttpClientAdapter? adapter,
    this.retryDelay = const Duration(milliseconds: 400),
  }) : dio = Dio(_options(baseUrl)),
       _refreshDio = Dio(_options(baseUrl)) {
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _refreshDio.httpClientAdapter = adapter;
    }
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final Dio _refreshDio;
  final TokenStore tokens;
  final Duration retryDelay;

  /// Called once when the refresh token is rejected; the session signs out with "Your session expired."
  void Function()? onSessionExpired;
  Future<String>? _refreshing;

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    contentType: 'application/json',
  );

  static bool _isAuthRoute(RequestOptions o) => o.path.startsWith('/v1/auth/') && o.path != '/v1/auth/logout';

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final access = tokens.neonSession ?? tokens.accessToken;
    if (access != null && !_isAuthRoute(o)) o.headers['Authorization'] = 'Bearer $access';
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    if (e.response?.statusCode == 401 && !_isAuthRoute(o) && tokens.neonSession != null) {
      // A Neon Auth session can't be refreshed in-app; a 401 means it ended.
      onSessionExpired?.call();
      return h.next(e);
    }
    if (e.response?.statusCode == 401 && !_isAuthRoute(o) && o.extra['retried'] != true) {
      try {
        final sent = (o.headers['Authorization'] as String?)?.substring(7);
        // A request that went out with an older token only needs the token another refresh already got.
        final access = sent != null && sent != tokens.accessToken ? tokens.accessToken! : await refreshOnce();
        o.headers['Authorization'] = 'Bearer $access';
        o.extra['retried'] = true;
        return h.resolve(await dio.fetch(o));
      } on DioException catch (retryError) {
        return h.next(retryError);
      } on ApiError catch (refreshError) {
        return h.next(DioException(requestOptions: o, response: e.response, error: refreshError));
      }
    }
    final retries = (o.extra['retries'] as int?) ?? 0;
    final transient = e.response == null && e.type != DioExceptionType.cancel || (e.response?.statusCode ?? 0) >= 500;
    if (o.method == 'GET' && transient && retries < 2) {
      await Future<void>.delayed(retryDelay * (retries + 1));
      o.extra['retries'] = retries + 1;
      try {
        return h.resolve(await dio.fetch(o));
      } on DioException catch (retryError) {
        return h.next(retryError);
      }
    }
    h.next(e);
  }

  /// Starts one refresh that every waiting request shares, and returns the new access token.
  Future<String> refreshOnce() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<String> _refresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null) throw _expired();
    try {
      final r = await _refreshDio.post<Map<String, dynamic>>('/v1/auth/refresh', data: {'refresh_token': refresh});
      final t = r.data!['tokens'] as Map<String, dynamic>;
      await tokens.save(t['access_token'] as String, t['refresh_token'] as String);
      return t['access_token'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw _expired();
      throw ApiError.from(e);
    }
  }

  ApiError _expired() {
    onSessionExpired?.call();
    return const ApiError(ApiErrorKind.unauthorized, 'Your session expired.');
  }

  Future<T> call<T>(Future<Response<dynamic>> Function(Dio dio) send, [T Function(dynamic data)? parse]) async {
    try {
      final r = await send(dio);
      return parse == null ? r.data as T : parse(r.data);
    } on DioException catch (e) {
      throw ApiError.from(e);
    } on TypeError catch (e) {
      debugPrint('decode failed: $e');
      throw const ApiError(ApiErrorKind.decoding, 'Something unexpected came back. Try again.');
    }
  }
}
