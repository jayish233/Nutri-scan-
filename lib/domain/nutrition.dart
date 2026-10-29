import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import '../core/api/models.dart';

enum GoalMode {
  fatLoss('fat_loss', 'Fat loss', 'Slight calorie deficit with higher protein', 150),
  muscleGain('muscle_gain', 'Muscle gain', 'Calorie surplus to support training', 180),
  maintenance('maintenance', 'Maintenance', 'Balanced targets to hold steady', 140);

  const GoalMode(this.wire, this.label, this.detail, this.proteinBase);

  final String wire, label, detail;

  /// Base grams for the onboarding protein-ambition slider.
  final double proteinBase;

  static GoalMode fromWire(String? v) => values.firstWhere((m) => m.wire == v, orElse: () => maintenance);

  Goals get suggestedTargets => switch (this) {
    fatLoss => const Goals(mode: 'fat_loss', calorieTarget: 1800, proteinTarget: 150, carbohydrateTarget: 160, fatTarget: 55),
    muscleGain => const Goals(mode: 'muscle_gain', calorieTarget: 2800, proteinTarget: 180, carbohydrateTarget: 300, fatTarget: 80),
    maintenance => const Goals(),
  };

  /// N = base × (0.85 + 0.35 × slider), rounded. Slider runs 0 (Gentle) to 1 (Ambitious).
  double proteinForAmbition(double slider) => (proteinBase * (0.85 + 0.35 * slider.clamp(0, 1))).roundToDouble();
}

/// Goal ranges and steps from PRD G1.
class GoalRange {
  const GoalRange(this.label, this.unit, this.min, this.max, this.step, this.color);

  final String label, unit;
  final double min, max, step;
  final Color color;

  static const calories = GoalRange('Energy', 'kcal', 1000, 5000, 50, AppColors.energy);
  static const protein = GoalRange('Protein', 'g', 20, 300, 5, AppColors.protein);
  static const carbs = GoalRange('Carbs', 'g', 20, 600, 5, AppColors.carbs);
  static const fat = GoalRange('Fat', 'g', 10, 200, 5, AppColors.fat);

  double clamp(double v) => ((v.clamp(min, max) / step).round() * step).toDouble();
}

enum ConfidenceLevel {
  high('High confidence', AppColors.success, Icons.verified),
  medium('Review suggested', AppColors.carbs, Icons.error),
  low('Low confidence — please correct', AppColors.energy, Icons.help),
  unknown('Estimate', Color(0xFFA1A1A6), Icons.info_outline);

  const ConfidenceLevel(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static ConfidenceLevel of(double? c) {
    if (c == null) return unknown;
    if (c >= 0.75) return high;
    if (c >= 0.45) return medium;
    return low;
  }

  bool get needsReview => this == medium || this == low;
}

enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealType(this.label);

  final String label;

  static MealType fromWire(String v) => values.firstWhere((m) => m.name == v, orElse: () => snack);

  /// Default by time of day for the scan review screen.
  static MealType forTime(DateTime t) {
    final h = t.hour;
    if (h >= 4 && h < 11) return breakfast;
    if (h >= 11 && h < 16) return lunch;
    if (h >= 18 && h < 23) return dinner;
    return snack;
  }
}

enum DietaryRestriction {
  vegetarian('vegetarian', 'Vegetarian'),
  eggetarian('eggetarian', 'Eggetarian'),
  vegan('vegan', 'Vegan'),
  glutenFree('gluten_free', 'Gluten-free'),
  dairyFree('dairy_free', 'Dairy-free'),
  nutFree('nut_free', 'Nut-free'),
  shellfishFree('shellfish_free', 'Shellfish-free'),
  halal('halal', 'Halal'),
  kosher('kosher', 'Kosher');

  const DietaryRestriction(this.wire, this.label);

  final String wire, label;

  static Set<DietaryRestriction> fromWire(Iterable<String> v) => values.where((r) => v.contains(r.wire)).toSet();
}

/// The phone's calendar date, used to group meals (`local_date`).
String localDateKey(DateTime t) => DateFormat('yyyy-MM-dd').format(t);

DateTime parseLocalDate(String key) => DateTime.parse(key);

String formatAmount(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String streakLabel(int days) => days == 0 ? 'Start a streak' : '$days day streak';

/// Sums nutrition into 12 two-hour buckets for the intraday sparkline and history chart.
List<double> twoHourBuckets(List<Meal> meals, double Function(Nutrition) pick) {
  final buckets = List<double>.filled(12, 0);
  for (final m in meals) {
    buckets[m.loggedAt.toLocal().hour ~/ 2] += pick(m.nutrition);
  }
  return buckets;
}
