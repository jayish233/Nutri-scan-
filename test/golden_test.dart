// Golden tests for the shared widgets from DESIGN_SCREENS.md, in dark mode at the largest text size.
// Regenerate after an intended visual change: flutter test --update-goldens test/golden_test.dart
// Goldens are rendered on macOS; font rasterising differs on Linux, so run these on a Mac.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanfo/app/providers.dart';
import 'package:scanfo/app/router.dart';
import 'package:scanfo/app/theme.dart';
import 'package:scanfo/core/api/models.dart';
import 'package:scanfo/core/widgets/common.dart';
import 'package:scanfo/core/widgets/rings.dart';
import 'package:scanfo/domain/nutrition.dart';
import 'package:scanfo/features/circles/circles_screen.dart';
import 'package:scanfo/features/meals/history_screen.dart';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final f in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await inter.load();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  }
}

final _today = DateTime(2026, 10, 27);

void _golden(String name, Widget child, {TargetPlatform platform = TargetPlatform.android, double height = 400}) {
  testWidgets('$name ${platform.name}', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = Size(412, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyStatsProvider.overrideWith(
            (ref, r) async => [
              for (var i = 0; i < 7; i++)
                DailyStat(
                  date: localDateKey(DateTime.parse(r.$1).add(Duration(days: i))),
                  nutrition: Nutrition(calories: [1800.0, 2300.0, 900.0, 0.0, 1500.0, 2100.0, 1200.0][i]),
                  mealCount: 1,
                  workoutCount: 0,
                ),
            ],
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.dark, platform),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(412, 900), textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(spaceL),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/${name}_${platform.name}.png'));
  });
}

void main() {
  _golden('energy_ring', const MetricRing(progress: 0.56, color: AppColors.energy), height: 200);
  _golden(
    'nutrient_tile',
    const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: NutrientTile(title: 'Protein', value: 62, target: 140, color: AppColors.protein),
        ),
        SizedBox(width: 10),
        Expanded(
          child: NutrientTile(title: 'Fiber', value: 14, color: AppColors.fiber),
        ),
      ],
    ),
    height: 360,
  );
  _golden('week_strip', WeekStrip(selected: _today, calorieGoal: 2200, onSelect: (_) {}), height: 260);
  _golden(
    'confidence_badge',
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ConfidenceBadge(confidence: 0.9),
        ConfidenceBadge(confidence: 0.6),
        ConfidenceBadge(confidence: 0.2),
        ConfidenceBadge(confidence: null),
      ],
    ),
  );
  _golden('allergen_banner', const AllergenWarningBanner(allergens: ['milk', 'wheat', 'peanuts']), height: 360);
  for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
    _golden(
      'app_card',
      const FitnessCard(title: 'Protein Navigator', child: Text('Add a bowl of dal to close the gap.')),
      platform: p,
      height: 300,
    );
    _golden(
      'app_text_field',
      AuthField(controller: TextEditingController(), label: 'Email', error: 'Enter a valid email address.'),
      platform: p,
    );
    _golden(
      'platform_nav_bar',
      p == TargetPlatform.iOS
          ? FloatingTabBar(index: 0, onTap: (_) {})
          : NavigationBar(
              selectedIndex: 0,
              destinations: [for (final (icon, label) in FloatingTabBar.items) NavigationDestination(icon: Icon(icon), label: label)],
            ),
      platform: p,
      height: 260,
    );
  }
  _golden(
    'primary_button',
    Column(
      children: [
        PrimaryButton(label: 'Confirm and log', onPressed: () {}),
        const SizedBox(height: 12),
        const PrimaryButton(label: 'Sign in', onPressed: null),
      ],
    ),
    height: 300,
  );
  _golden('streak_chip', const Wrap(spacing: 8, children: [StreakChip(days: 6), StreakChip(days: 0)]), height: 200);
  _golden(
    'circle_member_row',
    const Column(
      children: [
        CircleMemberRow(
          member: CircleMember(userId: 'a', displayName: 'Asha', streakDays: 6, loggedToday: true, sharing: true),
        ),
        CircleMemberRow(
          member: CircleMember(userId: 'b', displayName: 'Bilal', streakDays: 0, loggedToday: false, sharing: true),
        ),
        CircleMemberRow(
          member: CircleMember(userId: 'c', displayName: 'Chitra', sharing: false),
        ),
      ],
    ),
    height: 360,
  );
}
