import 'dart:convert';

import 'package:flutter/services.dart';

import 'nutrition.dart';

/// Deterministic next-meal protein suggestions over assets/data/protein_foods.json (ported from iOS ProteinNavigatorEngine).
class ProteinFood {
  const ProteinFood({
    required this.id,
    required this.name,
    required this.serving,
    required this.calories,
    required this.proteinG,
    required this.dietTags,
    required this.containsDairy,
    required this.containsEgg,
    required this.containsNuts,
    required this.containsGluten,
  });

  final String id, name, serving;
  final double calories, proteinG;
  final List<String> dietTags;
  final bool containsDairy, containsEgg, containsNuts, containsGluten;

  factory ProteinFood.fromJson(Map<String, dynamic> j) => ProteinFood(
    id: j['id'] as String,
    name: j['name'] as String,
    serving: j['serving'] as String,
    calories: (j['calories'] as num).toDouble(),
    proteinG: (j['protein_g'] as num).toDouble(),
    dietTags: (j['diet_tags'] as List).cast<String>(),
    containsDairy: j['contains_dairy'] as bool,
    containsEgg: j['contains_egg'] as bool,
    // Missing flags are treated as "contains" so an incomplete entry is never shown to a restricted user.
    containsNuts: j['contains_nuts'] as bool? ?? true,
    containsGluten: j['contains_gluten'] as bool? ?? true,
  );

  static Future<List<ProteinFood>> load() async {
    final raw = await rootBundle.loadString('assets/data/protein_foods.json');
    return (jsonDecode(raw) as List).map((e) => ProteinFood.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class MealSuggestion {
  const MealSuggestion({required this.title, required this.reason, this.foodNames = const []});

  final String title, reason;
  final List<String> foodNames;
}

bool isAllowed(ProteinFood f, Set<DietaryRestriction> r) {
  final veg = f.dietTags.contains('vegetarian') || f.dietTags.contains('vegan');
  if (r.contains(DietaryRestriction.vegan) && !(f.dietTags.contains('vegan') && !f.containsDairy && !f.containsEgg)) {
    return false;
  }
  if (r.contains(DietaryRestriction.vegetarian) && !(veg && !f.containsEgg)) return false;
  if (r.contains(DietaryRestriction.eggetarian) && !(veg || f.dietTags.contains('eggetarian'))) return false;
  if (r.contains(DietaryRestriction.dairyFree) && f.containsDairy) return false;
  if (r.contains(DietaryRestriction.nutFree) && f.containsNuts) return false;
  if (r.contains(DietaryRestriction.glutenFree) && f.containsGluten) return false;
  return true;
}

MealSuggestion suggestProtein({
  required double consumedProtein,
  required double proteinTarget,
  required Set<DietaryRestriction> restrictions,
  required List<ProteinFood> catalog,
}) {
  final target = proteinTarget < 1 ? 1.0 : proteinTarget;
  final remaining = (target - consumedProtein).clamp(0, double.infinity).toDouble();
  final eaten = consumedProtein.round(), goal = target.round();

  if (remaining < 8) {
    return MealSuggestion(
      title: 'Protein goal looking good',
      reason: "You've logged ${eaten}g of ${goal}g. A light snack is enough if you're still hungry.",
    );
  }

  final eligible = catalog.where((f) => isAllowed(f, restrictions)).toList()
    // Ties break by id: List.sort is not stable, and suggestions must be deterministic.
    ..sort((a, b) => b.proteinG != a.proteinG ? b.proteinG.compareTo(a.proteinG) : a.id.compareTo(b.id));
  if (eligible.isEmpty) {
    return MealSuggestion(
      title: 'Add a protein-rich meal',
      reason: 'You have ${remaining.round()}g protein left toward ${goal}g. Scan your next meal to stay consistent.',
    );
  }

  final picks = <ProteinFood>[];
  var covered = 0.0;
  for (final f in eligible) {
    if (picks.length >= 2 || covered >= remaining * 0.85) break;
    // Prefer complementary servings over one huge hit when the gap is moderate.
    if (remaining < 35 && f.proteinG > remaining + 10) continue;
    picks.add(f);
    covered += f.proteinG;
  }
  if (picks.isEmpty) picks.add(eligible.first);

  final servings = picks.map((f) => '${f.serving} ${f.name.toLowerCase()}').join(' and ');
  return MealSuggestion(
    title: picks.map((f) => f.name).join(' + '),
    reason: "You've logged ${eaten}g protein. Add $servings to move toward your ${goal}g target.",
    foodNames: picks.map((f) => f.name).toList(),
  );
}
