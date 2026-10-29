import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';
import '../../domain/nutrition.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.scan, required this.photo});

  final ScanResult scan;
  final Uint8List photo;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  // Made once so a double tap or retry sends the same id (PUT is idempotent).
  final _mealId = const Uuid().v4();
  late final _name = TextEditingController(text: widget.scan.recognizedName);
  late final Map<String, TextEditingController> _fields = {
    'Calories': _c(widget.scan.total.calories),
    'Protein': _c(widget.scan.total.protein),
    'Carbs': _c(widget.scan.total.carbohydrates),
    'Fat': _c(widget.scan.total.fat),
    'Fiber': _c(widget.scan.total.fiber ?? 0),
  };
  MealType _type = MealType.forTime(DateTime.now());
  bool _saving = false, _done = false;

  static TextEditingController _c(double v) => TextEditingController(text: formatAmount(v));

  double? _num(String key) => double.tryParse(_fields[key]!.text.trim());

  Nutrition? get _nutrition {
    final values = [for (final k in _fields.keys) _num(k)];
    if (values.any((v) => v == null || v < 0)) return null;
    return Nutrition(calories: values[0]!, protein: values[1]!, carbohydrates: values[2]!, fat: values[3]!, fiber: values[4]);
  }

  bool get _corrected {
    final n = _nutrition, t = widget.scan.total;
    return _name.text.trim() != widget.scan.recognizedName ||
        n == null ||
        n.calories != t.calories ||
        n.protein != t.protein ||
        n.carbohydrates != t.carbohydrates ||
        n.fat != t.fat ||
        (n.fiber ?? 0) != (t.fiber ?? 0);
  }

  Future<void> _save() async {
    final n = _nutrition;
    if (_name.text.trim().isEmpty || n == null) {
      _snack('Enter a name and valid numbers (0 or more).');
      return;
    }
    if (ref.read(offlineProvider).value ?? false) {
      _snack("You're offline. Connect to save.");
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await ref
          .read(apiProvider)
          .saveMeal(
            Meal(
              id: _mealId,
              name: _name.text.trim(),
              mealType: _type.name,
              loggedAt: now,
              localDate: localDateKey(now),
              nutrition: n,
              items: widget.scan.items,
              wasUserCorrected: _corrected,
              scanId: widget.scan.id,
            ),
          );
      invalidateNutrition(ref);
      if (!mounted) return;
      setState(() => _done = true);
      _snack('Meal logged');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/summary');
      });
    } on ApiError catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _discard() async {
    // Removes the photo now instead of waiting for the 24 h cleanup; failure is harmless.
    ref.read(apiProvider).discardScan(widget.scan.id).ignore();
    // Pop after the rebuild so PopScope sees canPop = true.
    setState(() => _done = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard this meal?'),
        content: const Text('The estimate and photo will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave ?? false) _discard();
  }

  Widget _macro(String label, double value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(spaceM),
      decoration: BoxDecoration(color: metricTrack(color), borderRadius: BorderRadius.circular(tileRadius(context))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          UnitValue(value: formatAmount(value), unit: 'g', color: color, size: 17),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final text = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final level = ConfidenceLevel.of(scan.confidence);
    final n = _nutrition ?? scan.total;
    return PopScope(
      canPop: _done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Review meal')),
        body: ListView(
          padding: const EdgeInsets.all(spaceL),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius(context)),
              child: Image.memory(widget.photo, height: 220, fit: BoxFit.cover, semanticLabel: 'Your meal photo'),
            ),
            const SizedBox(height: spaceM),
            FitnessCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConfidenceBadge(confidence: scan.confidence),
                  const SizedBox(height: spaceM),
                  TextField(
                    controller: _name,
                    style: text.headlineSmall,
                    decoration: const InputDecoration(labelText: 'Meal name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: spaceS),
                  Text('Edit anything that looks off — corrections are saved with the meal.', style: text.bodySmall),
                ],
              ),
            ),
            if (scan.potentialAllergens.isNotEmpty) ...[
              const SizedBox(height: spaceM),
              AllergenWarningBanner(allergens: scan.potentialAllergens),
            ],
            const SizedBox(height: spaceM),
            FitnessCard(
              title: 'Meal',
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3,
                mainAxisSpacing: spaceS,
                crossAxisSpacing: spaceS,
                children: [
                  for (final t in MealType.values)
                    ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(t.label, textAlign: TextAlign.center),
                      ),
                      selected: _type == t,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(color: _type == t ? AppColors.ink : c.primaryText, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
            ),
            const SizedBox(height: spaceM),
            FitnessCard(
              title: 'Estimate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UnitValue(value: formatAmount(n.calories), unit: 'kcal', color: AppColors.energy, size: 34),
                  const SizedBox(height: spaceM),
                  Row(
                    children: [
                      _macro('Protein', n.protein, AppColors.protein),
                      const SizedBox(width: spaceS),
                      _macro('Carbs', n.carbohydrates, AppColors.carbs),
                    ],
                  ),
                  const SizedBox(height: spaceS),
                  Row(
                    children: [
                      _macro('Fat', n.fat, AppColors.fat),
                      const SizedBox(width: spaceS),
                      _macro('Fiber', n.fiber ?? 0, AppColors.fiber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: spaceM),
            Material(
              color: c.card,
              borderRadius: BorderRadius.circular(cardRadius(context)),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: level.needsReview,
                title: Text('Correct estimate', style: text.titleMedium),
                childrenPadding: const EdgeInsets.fromLTRB(spaceL, 0, spaceL, spaceL),
                children: [
                  for (final MapEntry(:key, :value) in _fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spaceS),
                      child: TextField(
                        controller: value,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: InputDecoration(labelText: key, suffixText: key == 'Calories' ? 'kcal' : 'g'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
            if (scan.items.isNotEmpty) ...[
              const SizedBox(height: spaceM),
              FitnessCard(
                title: 'Detected items',
                child: Column(
                  children: [
                    for (final item in scan.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name, style: text.bodyLarge),
                        subtitle: item.serving == null ? null : Text(item.serving!, style: text.bodySmall),
                        trailing: Text('${formatAmount(item.nutrition.calories)} kcal', style: const TextStyle(color: AppColors.energy)),
                      ),
                  ],
                ),
              ),
            ],
            const EstimateDisclaimer(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(spaceL, spaceS, spaceL, spaceS),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(label: 'Confirm and log', loading: _saving, onPressed: _save),
                TextButton(onPressed: _saving ? null : _discard, child: const Text('Retake')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
