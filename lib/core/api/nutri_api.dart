import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// One method per endpoint in docs/API_CONTRACT.md. Widgets never call this directly; providers do.
/// Sign-in and sign-up go through Neon Auth (lib/core/api/neon_auth.dart), not this API.
class NutriApi {
  NutriApi(this.client, this.cache);

  final ApiClient client;
  final ResponseCache cache;

  Future<User> me() => client.call((d) => d.get('/v1/me'), (j) => User.fromJson(j as Map<String, dynamic>));

  Future<User> updateMe(Map<String, dynamic> changes) =>
      client.call((d) => d.patch('/v1/me', data: changes), (j) => User.fromJson(j as Map<String, dynamic>));

  Future<void> deleteAccount(String password) => client.call((d) => d.delete('/v1/me', data: {'password': password}));

  Future<Goals> goals() => client.call((d) => d.get('/v1/goals'), (j) => Goals.fromJson(j as Map<String, dynamic>));

  Future<Goals> saveGoals(Goals g) =>
      client.call((d) => d.put('/v1/goals', data: g.toJson()), (j) => Goals.fromJson(j as Map<String, dynamic>));

  /// Never retried automatically: each call costs a scan.
  Future<ScanResult> scan(List<int> jpeg, {CancelToken? cancel, void Function(int, int)? onSendProgress}) => client.call(
    (d) => d.post(
      '/v1/scans',
      data: FormData.fromMap({'image': MultipartFile.fromBytes(jpeg, filename: 'meal.jpg', contentType: DioMediaType('image', 'jpeg'))}),
      cancelToken: cancel,
      onSendProgress: onSendProgress,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    ),
    (j) => ScanResult.fromJson(j as Map<String, dynamic>),
  );

  Future<void> discardScan(String id) => client.call((d) => d.delete('/v1/scans/$id'));

  /// Idempotent: the client-made id is in the path, so a retry never duplicates.
  Future<Meal> saveMeal(Meal m) =>
      client.call((d) => d.put('/v1/meals/${m.id}', data: m.toJson()), (j) => Meal.fromJson(j as Map<String, dynamic>));

  Future<Meal> meal(String id) => client.call((d) => d.get('/v1/meals/$id'), (j) => Meal.fromJson(j as Map<String, dynamic>));

  Future<void> deleteMeal(String id) => client.call((d) => d.delete('/v1/meals/$id'));

  Future<({Summary summary, bool fromCache})> summary(String date) => cache
      .networkFirst('summary:$date', () => client.call((d) => d.get('/v1/summary', queryParameters: {'date': date})), (j) {
        return Summary.fromJson(j as Map<String, dynamic>);
      })
      .then((r) => (summary: r.value, fromCache: r.fromCache));

  Future<List<DailyStat>> dailyStats(String from, String to) => cache
      .networkFirst(
        'stats:$from:$to',
        () => client.call((d) => d.get('/v1/stats/daily', queryParameters: {'from': from, 'to': to})),
        (j) => ((j as Map)['days'] as List).map((e) => DailyStat.fromJson(e as Map<String, dynamic>)).toList(),
      )
      .then((r) => r.value);

  Future<List<Circle>> circles(String date) => client.call(
    (d) => d.get('/v1/circles', queryParameters: {'date': date}),
    (j) => ((j as Map)['items'] as List).map((e) => Circle.fromJson(e as Map<String, dynamic>)).toList(),
  );

  Future<Circle> createCircle(String name) =>
      client.call((d) => d.post('/v1/circles', data: {'name': name}), (j) => Circle.fromJson(j as Map<String, dynamic>));

  Future<Circle> joinCircle(String code) =>
      client.call((d) => d.post('/v1/circles/join', data: {'invite_code': code}), (j) => Circle.fromJson(j as Map<String, dynamic>));

  Future<void> leaveCircle(String id) => client.call((d) => d.post('/v1/circles/$id/leave'));
}

/// Last good GET responses per user, so Summary, history and charts stay readable offline.
/// shortcut: JSON in shared_preferences instead of Drift; move to Drift when the offline write queue (X1) lands.
class ResponseCache {
  ResponseCache(this.prefs);

  final SharedPreferences? prefs;
  String userId = '';

  String _key(String k) => 'cache:$userId:$k';

  Future<({T value, bool fromCache})> networkFirst<T>(String key, Future<dynamic> Function() fetch, T Function(dynamic) parse) async {
    try {
      final data = await fetch();
      await prefs?.setString(_key(key), jsonEncode(data));
      return (value: parse(data), fromCache: false);
    } on ApiError catch (e) {
      final saved = prefs?.getString(_key(key));
      if (e.kind != ApiErrorKind.network || saved == null) rethrow;
      return (value: parse(jsonDecode(saved)), fromCache: true);
    }
  }

  Future<void> clearAll() async {
    for (final k in prefs?.getKeys().where((k) => k.startsWith('cache:')).toList() ?? const <String>[]) {
      await prefs!.remove(k);
    }
  }
}
