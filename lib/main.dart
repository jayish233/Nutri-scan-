import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/config.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  checkConfig();
  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStore(const FlutterSecureStorage());
  await tokens.load();
  runApp(
    ProviderScope(
      // No automatic provider retries: the Dio client already retries GETs, and scans must never repeat.
      retry: (_, _) => null,
      overrides: [prefsProvider.overrideWithValue(prefs), tokenStoreProvider.overrideWithValue(tokens)],
      child: const NutriScanApp(),
    ),
  );
}

class NutriScanApp extends ConsumerWidget {
  const NutriScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'NutriScan',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
  );
}
