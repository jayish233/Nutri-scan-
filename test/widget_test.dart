import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanfo/app/theme.dart';
import 'package:scanfo/core/api/models.dart';
import 'package:scanfo/core/widgets/common.dart';
import 'package:scanfo/features/scan/review_screen.dart';
import 'package:scanfo/main.dart';

// 1×1 transparent PNG.
final _pixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

ScanResult _scan(double confidence, {List<String> allergens = const []}) => ScanResult(
  id: 's1',
  recognizedName: 'Paneer tikka',
  confidence: confidence,
  items: const [],
  total: const Nutrition(calories: 320, protein: 22, carbohydrates: 10, fat: 20, fiber: 2),
  potentialAllergens: allergens,
);

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(theme: buildTheme(Brightness.dark), home: child),
);

void main() {
  testWidgets('cold start without a session lands on Welcome', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NutriScanApp()));
    await tester.pumpAndSettle();
    expect(find.text("Snap your plate. Know what's in it."), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('review opens the correction panel at medium confidence and shows allergens and disclaimer', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReviewScreen(
          scan: _scan(0.5, allergens: ['milk']),
          photo: _pixel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review suggested'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Possible allergens'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Possible allergens'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Calories'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.widgetWithText(TextField, 'Calories'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(disclaimerText), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(disclaimerText), findsOneWidget);
  });

  testWidgets('review keeps the correction panel closed at high confidence', (tester) async {
    await tester.pumpWidget(_wrap(ReviewScreen(scan: _scan(0.9), photo: _pixel)));
    await tester.pumpAndSettle();
    expect(find.text('High confidence'), findsOneWidget);
    expect(find.text('Possible allergens'), findsNothing);
    expect(find.widgetWithText(TextField, 'Calories'), findsNothing);
  });

  testWidgets('screens survive large text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _wrap(ReviewScreen(scan: _scan(0.3), photo: _pixel)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Low confidence — please correct'), findsOneWidget);
  });
}
