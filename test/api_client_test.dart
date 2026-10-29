import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanfo/core/api/api_client.dart';
import 'package:scanfo/core/storage/token_store.dart';

/// Fake server: accepts only "Bearer new", and counts refresh calls.
class FakeServer implements HttpClientAdapter {
  int refreshCalls = 0, meCalls = 0, flaky = 0;
  bool refreshFails = false;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    if (o.path == '/v1/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshFails) {
        return _json(401, {
          'error': {'code': 'unauthorized', 'message': 'Your session expired.'},
        });
      }
      return _json(200, {
        'tokens': {'access_token': 'new', 'refresh_token': 'r2', 'expires_in': 900},
      });
    }
    if (o.path == '/v1/flaky') {
      return ++flaky < 3 ? _json(503, {}) : _json(200, {'ok': true});
    }
    meCalls++;
    if (o.headers['Authorization'] != 'Bearer new') {
      return _json(401, {
        'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'},
      });
    }
    return _json(200, {'ok': true});
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiClient, FakeServer)> _client() async {
  final tokens = TokenStore();
  await tokens.save('old', 'r1');
  final server = FakeServer();
  return (ApiClient(baseUrl: 'http://x', tokens: tokens, adapter: server, retryDelay: Duration.zero), server);
}

void main() {
  test('two simultaneous 401s cause one refresh, then both retry once', () async {
    final (client, server) = await _client();
    final results = await Future.wait([client.call((d) => d.get('/v1/me')), client.call((d) => d.get('/v1/me'))]);
    expect(results, everyElement({'ok': true}));
    expect(server.refreshCalls, 1);
    expect(server.meCalls, 4);
    expect(client.tokens.refreshToken, 'r2');
  });

  test('a rejected refresh signs out once and surfaces unauthorized', () async {
    final (client, server) = await _client();
    server.refreshFails = true;
    var expired = 0;
    client.onSessionExpired = () => expired++;
    await expectLater(
      client.call((d) => d.get('/v1/me')),
      throwsA(isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
    );
    expect(expired, 1);
  });

  test('GET retries up to twice on 5xx', () async {
    final (client, server) = await _client();
    expect(await client.call((d) => d.get('/v1/flaky')), {'ok': true});
    expect(server.flaky, 3);
  });

  test('server errors map to ApiError with fields and reset time', () {
    final e = ApiError.from(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 429,
          data: {
            'error': {
              'code': 'quota_exceeded',
              'message': 'Used up.',
              'reset_at': '2026-10-27T18:30:00+00:00',
              'fields': {'a': 'b'},
            },
          },
        ),
      ),
    );
    expect(e.kind, ApiErrorKind.quotaExceeded);
    expect(e.resetAt, DateTime.utc(2026, 10, 27, 18, 30));
    expect(e.fields, {'a': 'b'});
    expect(
      ApiError.from(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError)).kind,
      ApiErrorKind.network,
    );
  });
}
