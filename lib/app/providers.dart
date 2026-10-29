import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/models.dart';
import '../core/api/neon_auth.dart';
import '../core/api/nutri_api.dart';
import '../core/storage/token_store.dart';
import '../domain/nutrition.dart';
import '../domain/protein_navigator.dart';
import 'config.dart';

// Overridden in main() and in tests.
final prefsProvider = Provider<SharedPreferences?>((ref) => null);
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(baseUrl: apiBaseUrl, tokens: ref.watch(tokenStoreProvider)));

final apiProvider = Provider<NutriApi>((ref) => NutriApi(ref.watch(apiClientProvider), ResponseCache(ref.watch(prefsProvider))));

final neonAuthProvider = Provider<NeonAuthClient>((ref) => NeonAuthClient(neonAuthBaseUrl));

// ---------- Session ----------

sealed class SessionState {
  const SessionState();
}

class Booting extends SessionState {
  const Booting([this.error]);

  final String? error;
}

class SignedOut extends SessionState {
  const SignedOut([this.message]);

  final String? message;
}

class SignedIn extends SessionState {
  const SignedIn(this.user);

  final User user;

  bool get needsOnboarding => !user.onboardingCompleted;
}

class SessionController extends Notifier<SessionState> {
  static const _profileKey = 'profile';

  NutriApi get _api => ref.read(apiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);
  SharedPreferences? get _prefs => ref.read(prefsProvider);

  @override
  SessionState build() {
    ref.read(apiClientProvider).onSessionExpired = () => signOut(message: 'Your session expired.', callServer: false);
    Future.microtask(boot);
    return const Booting();
  }

  User? get user => switch (state) {
    SignedIn(:final user) => user,
    _ => null,
  };

  Future<void> boot() async {
    state = const Booting();
    if (!_tokens.hasSession) {
      state = const SignedOut();
      return;
    }
    final cached = _prefs?.getString(_profileKey);
    if (cached != null) {
      // Signed in from the cached profile at once (no Welcome flash), then refresh behind it.
      _setUser(User.fromJson(jsonDecode(cached) as Map<String, dynamic>));
      _refreshProfile();
      return;
    }
    try {
      _setUser(await _api.me());
    } on ApiError catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) return; // onSessionExpired already signed out
      state = Booting(e.message);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      _setUser(await _api.me());
    } on ApiError {
      // Offline or expired: expiry is handled by onSessionExpired, offline keeps the cached profile.
    }
  }

  void _setUser(User u) {
    _api.cache.userId = u.id;
    _prefs?.setString(_profileKey, jsonEncode(u.toJson()));
    state = SignedIn(u);
  }

  Future<void> _startNeon(String signedSession) async {
    await _tokens.saveNeon(signedSession);
    try {
      _setUser(await _api.me());
    } on ApiError {
      // e.g. the email is not on the invite list: drop the session and let the screen show why.
      await _tokens.clear();
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async =>
      _startNeon(await ref.read(neonAuthProvider).signIn(email: email.trim(), password: password));

  Future<void> register({required String name, required String email, required String password}) async =>
      _startNeon(await ref.read(neonAuthProvider).signUp(name: name.trim(), email: email.trim(), password: password));

  /// Better Auth emails a reset link; always answers quietly so it never reveals whether an email exists.
  Future<void> forgotPassword(String email) => ref.read(neonAuthProvider).forgotPassword(email.trim());

  Future<void> updateProfile(Map<String, dynamic> changes) async => _setUser(await _api.updateMe(changes));

  Future<void> signOut({String? message, bool callServer = true}) async {
    final signed = _tokens.neonSession;
    if (callServer && signed != null) {
      await ref.read(neonAuthProvider).signOut(signed); // best effort inside the client
    }
    await _tokens.clear();
    await _prefs?.remove(_profileKey);
    await _api.cache.clearAll();
    state = SignedOut(message);
  }

  Future<void> deleteAccount(String password) async {
    await _api.deleteAccount(password);
    await signOut(callServer: false);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final currentUserProvider = Provider<User?>(
  (ref) => switch (ref.watch(sessionProvider)) {
    SignedIn(:final user) => user,
    _ => null,
  },
);

// ---------- Data ----------

/// Summary for one local date; also feeds Meal history.
final summaryProvider = FutureProvider.autoDispose.family<({Summary summary, bool fromCache}), String>(
  (ref, date) => ref.watch(apiProvider).summary(date),
);

final dailyStatsProvider = FutureProvider.autoDispose.family<List<DailyStat>, (String, String)>(
  (ref, range) => ref.watch(apiProvider).dailyStats(range.$1, range.$2),
);

final mealProvider = FutureProvider.autoDispose.family<Meal, String>((ref, id) => ref.watch(apiProvider).meal(id));

final circlesProvider = FutureProvider.autoDispose<List<Circle>>((ref) => ref.watch(apiProvider).circles(todayKey()));

final proteinFoodsProvider = FutureProvider<List<ProteinFood>>((ref) => ProteinFood.load());

/// Call after any meal or goal write so every screen shows fresh totals.
void invalidateNutrition(WidgetRef ref) {
  ref.invalidate(summaryProvider);
  ref.invalidate(dailyStatsProvider);
  ref.invalidate(circlesProvider);
}

String todayKey() => localDateKey(DateTime.now());

final offlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool offline(List<ConnectivityResult> r) => r.every((x) => x == ConnectivityResult.none);
  yield offline(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(offline);
});

// ---------- Appearance ----------

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values.firstWhere((m) => m.name == ref.read(prefsProvider)?.getString('theme_mode'), orElse: () => ThemeMode.dark);

  void set(ThemeMode mode) {
    ref.read(prefsProvider)?.setString('theme_mode', mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
