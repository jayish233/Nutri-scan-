import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanfo/app/providers.dart';
import 'package:scanfo/app/router.dart';
import 'package:scanfo/core/api/models.dart';
import 'package:scanfo/domain/nutrition.dart';
import 'package:scanfo/domain/protein_navigator.dart';

List<ProteinFood> _catalog() => (jsonDecode(File('assets/data/protein_foods.json').readAsStringSync()) as List)
    .map((e) => ProteinFood.fromJson(e as Map<String, dynamic>))
    .toList();

const _user = User(id: 'u', email: 'a@b.c', displayName: 'Asha', username: 'asha_1234');

void main() {
  test('goal modes and protein ambition', () {
    expect(GoalMode.fatLoss.suggestedTargets.calorieTarget, 1800);
    expect(GoalMode.muscleGain.suggestedTargets.carbohydrateTarget, 300);
    expect(GoalMode.maintenance.suggestedTargets.fatTarget, 70);
    expect(GoalMode.fatLoss.proteinForAmbition(0), 128); // 150 × 0.85 = 127.5 → 128
    expect(GoalMode.muscleGain.proteinForAmbition(1), 216); // 180 × 1.2
    expect(GoalMode.maintenance.proteinForAmbition(0.5), 144); // 143.5 rounds half away from zero
  });

  test('goal ranges clamp and snap to step', () {
    expect(GoalRange.calories.clamp(900), 1000);
    expect(GoalRange.calories.clamp(2222), 2200);
    expect(GoalRange.fat.clamp(500), 200);
  });

  test('confidence thresholds', () {
    expect(ConfidenceLevel.of(0.75), ConfidenceLevel.high);
    expect(ConfidenceLevel.of(0.7499), ConfidenceLevel.medium);
    expect(ConfidenceLevel.of(0.45), ConfidenceLevel.medium);
    expect(ConfidenceLevel.of(0.44), ConfidenceLevel.low);
    expect(ConfidenceLevel.of(null), ConfidenceLevel.unknown);
    expect(ConfidenceLevel.medium.needsReview && ConfidenceLevel.low.needsReview, isTrue);
    expect(ConfidenceLevel.high.needsReview, isFalse);
  });

  test('nutrition sums items, keeping fiber null only when every item lacks it', () {
    const a = Nutrition(calories: 230, protein: 18, carbohydrates: 35, fat: 4, fiber: 8);
    const b = Nutrition(calories: 200, protein: 4, carbohydrates: 45, fat: 0.5);
    expect(Nutrition.sum([a, b]), const Nutrition(calories: 430, protein: 22, carbohydrates: 80, fat: 4.5, fiber: 8));
    expect(Nutrition.sum([b, b]).fiber, isNull);
  });

  test('streak label and local date key', () {
    expect(streakLabel(0), 'Start a streak');
    expect(streakLabel(4), '4 day streak');
    expect(localDateKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  test('meal type defaults by time of day', () {
    expect(MealType.forTime(DateTime(2026, 1, 1, 8)), MealType.breakfast);
    expect(MealType.forTime(DateTime(2026, 1, 1, 13)), MealType.lunch);
    expect(MealType.forTime(DateTime(2026, 1, 1, 17)), MealType.snack);
    expect(MealType.forTime(DateTime(2026, 1, 1, 20)), MealType.dinner);
  });

  group('protein navigator', () {
    final foods = _catalog();

    test('nut-free users never see peanuts', () {
      final allowed = foods.where((f) => isAllowed(f, {DietaryRestriction.nutFree})).map((f) => f.id);
      expect(allowed, isNot(contains('peanut')));
      expect(allowed, contains('dal'));
    });

    test('diet filters', () {
      Iterable<String> ids(Set<DietaryRestriction> r) => foods.where((f) => isAllowed(f, r)).map((f) => f.id);
      expect(ids({DietaryRestriction.vegan}), isNot(anyOf(contains('paneer'), contains('eggs'), contains('curd'))));
      expect(ids({DietaryRestriction.vegetarian}), isNot(contains('eggs')));
      expect(ids({DietaryRestriction.vegetarian}), contains('paneer'));
      expect(ids({DietaryRestriction.eggetarian}), contains('eggs'));
      expect(ids({DietaryRestriction.dairyFree}), isNot(contains('paneer')));
    });

    test('suggestions are deterministic and respect restrictions', () {
      final s = suggestProtein(
        consumedProtein: 40,
        proteinTarget: 140,
        restrictions: {DietaryRestriction.vegan, DietaryRestriction.nutFree},
        catalog: foods,
      );
      expect(s.foodNames, ['Soy chunks', 'Dal']);
      expect(s.reason, contains('40g'));
      final again = suggestProtein(
        consumedProtein: 40,
        proteinTarget: 140,
        restrictions: {DietaryRestriction.vegan, DietaryRestriction.nutFree},
        catalog: foods,
      );
      expect(again.title, s.title);
    });

    test('goal reached and nothing eligible', () {
      expect(suggestProtein(consumedProtein: 135, proteinTarget: 140, restrictions: {}, catalog: foods).title, 'Protein goal looking good');
      expect(suggestProtein(consumedProtein: 0, proteinTarget: 140, restrictions: {}, catalog: const []).foodNames, isEmpty);
    });

    test('small gaps avoid one oversized serving', () {
      // 10 g left: soy chunks (26 g) is skipped as more than 10 g over the gap.
      final s = suggestProtein(consumedProtein: 130, proteinTarget: 140, restrictions: {}, catalog: foods);
      expect(s.foodNames, ['Dal']);
    });
  });

  test('json models round-trip the wire format', () {
    final meal = Meal.fromJson({
      'id': 'm1',
      'name': 'Dal and rice',
      'meal_type': 'lunch',
      'logged_at': '2026-10-27T07:36:10Z',
      'local_date': '2026-10-27',
      'nutrition': {'calories': 420, 'protein': 18, 'carbohydrates': 55, 'fat': 12, 'fiber': null},
      'items': [
        {
          'id': 'i1',
          'name': 'Dal',
          'serving': '1 cup',
          'nutrition': {'calories': 230, 'protein': 18, 'carbohydrates': 35, 'fat': 4},
          'confidence': 0.82,
        },
      ],
      'notes': null,
      'was_user_corrected': true,
      'image_url': null,
      'scan_id': 's1',
    });
    final body = meal.toJson();
    expect(body['meal_type'], 'lunch');
    expect(body['logged_at'], '2026-10-27T07:36:10.000Z');
    expect((body['items'] as List).single['confidence'], 0.82);
    expect(body['was_user_corrected'], isTrue);
    expect(User.fromJson(_user.toJson()).username, 'asha_1234');
  });

  test('session redirects', () {
    expect(sessionRedirect(const Booting(), '/summary'), '/splash');
    expect(sessionRedirect(const SignedOut(), '/summary'), '/welcome');
    expect(sessionRedirect(const SignedOut('Your session expired.'), '/splash'), '/sign-in');
    expect(sessionRedirect(const SignedOut(), '/register'), isNull);
    expect(sessionRedirect(const SignedIn(_user), '/summary'), '/onboarding');
    final done = User.fromJson({..._user.toJson(), 'onboarding_completed': true});
    expect(sessionRedirect(SignedIn(done), '/splash'), '/summary');
    expect(sessionRedirect(SignedIn(done), '/meal/x'), isNull);
  });
}
