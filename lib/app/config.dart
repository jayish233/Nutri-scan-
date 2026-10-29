import 'package:flutter/foundation.dart';

/// Set per flavor with `--dart-define-from-file=config/dev.json` (or prod.json). No secrets live here.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

/// Neon Auth (Managed Better Auth) base URL; sign-in and sign-up happen here directly.
const neonAuthBaseUrl = String.fromEnvironment('NEON_AUTH_BASE_URL');

/// Private/LAN hosts a release build may reach over plain http while the backend is self-hosted locally.
bool _isPrivateHost(String host) =>
    host == 'localhost' ||
    host.startsWith('127.') ||
    host.startsWith('10.') ||
    host.startsWith('192.168.') ||
    RegExp(r'^172\.(1[6-9]|2[0-9]|3[01])\.').hasMatch(host);

void checkConfig() {
  if (!kReleaseMode) return;
  final uri = Uri.tryParse(apiBaseUrl);
  final ok = apiBaseUrl.startsWith('https://') || (uri != null && uri.isScheme('http') && _isPrivateHost(uri.host));
  if (!ok) {
    throw StateError('Release builds need an https API_BASE_URL (or http to a private/LAN address).');
  }
}
