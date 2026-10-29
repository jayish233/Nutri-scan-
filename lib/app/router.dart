import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/models.dart';
import '../features/auth/auth_screens.dart';
import '../features/circles/circles_screen.dart';
import '../features/meals/history_screen.dart';
import '../features/meals/meal_screens.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screens.dart';
import '../features/progress/progress_screens.dart';
import '../features/scan/review_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/summary/summary_screen.dart';
import 'providers.dart';
import 'theme.dart';

const _authRoutes = {'/welcome', '/sign-in', '/register', '/forgot'};

/// Signed out goes to Welcome, signed in without onboarding to Onboarding, otherwise to the tabs.
String? sessionRedirect(SessionState session, String location) => switch (session) {
  Booting() => location == '/splash' ? null : '/splash',
  SignedOut() => _authRoutes.contains(location) ? null : (session.message != null ? '/sign-in' : '/welcome'),
  SignedIn(needsOnboarding: true) => location == '/onboarding' ? null : '/onboarding',
  SignedIn() => (location == '/splash' || location == '/onboarding' || _authRoutes.contains(location)) ? '/summary' : null,
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (_, state) => sessionRedirect(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/summary', builder: (_, _) => const SummaryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/scan', builder: (_, _) => const ScanScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/scan/review',
        redirect: (_, s) => s.extra is (ScanResult, Uint8List) ? null : '/scan',
        builder: (_, s) {
          final (scan, photo) = s.extra! as (ScanResult, Uint8List);
          return ReviewScreen(scan: scan, photo: photo);
        },
      ),
      GoRoute(path: '/add-meal', builder: (_, _) => const AddMealScreen()),
      GoRoute(
        path: '/meal/:id',
        builder: (_, s) => MealDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/weekly', builder: (_, _) => const WeeklyChartsScreen()),
      GoRoute(path: '/circles', builder: (_, _) => const CirclesScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/profile/diet', builder: (_, _) => const DietScreen()),
      GoRoute(path: '/profile/privacy', builder: (_, _) => const PrivacyScreen()),
    ],
  );
});

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    void onTap(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final ios = isCupertino(context);
    return Scaffold(
      // Only the floating capsule draws over content; Android's NavigationBar sits below it.
      extendBody: ios,
      body: shell,
      bottomNavigationBar: ios
          ? FloatingTabBar(index: shell.currentIndex, onTap: onTap)
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: onTap,
              destinations: [for (final (icon, label) in FloatingTabBar.items) NavigationDestination(icon: Icon(icon), label: label)],
            ),
    );
  }
}

/// iOS: translucent capsule, 64 high, 16 from the sides and 24 from the bottom; active item lime.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (Icons.donut_large, 'Summary'),
    (Icons.center_focus_weak, 'Scan'),
    (Icons.bar_chart, 'Progress'),
    (Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Fixed 64 px capsule: cap label growth like the iOS tab bar does, so large text never overflows it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(spaceL, 0, spaceL, spaceXl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: c.cardElevated.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: c.hairline),
              ),
              child: Row(
                children: [
                  for (final (i, (icon, label)) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: '$label tab',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () => onTap(i),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 19, color: i == index ? c.brandDeep : c.secondaryText),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: i == index ? c.brandDeep : c.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
