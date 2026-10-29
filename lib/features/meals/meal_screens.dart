import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';
import '../../domain/nutrition.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: const Text('It will be removed from your totals and the photo is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.energy)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).deleteMeal(id);
      invalidateNutrition(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal deleted')));
        context.pop();
      }
    } on ApiError catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mealProvider(id));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) => _delete(context, ref),
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
          ),
        ],
      ),
      body: switch (async) {
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.all(spaceL),
          children: [
            if (value.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(cardRadius(context)),
                child: CachedNetworkImage(imageUrl: value.imageUrl!, cacheKey: 'meal-${value.id}', height: 240, fit: BoxFit.cover),
              ),
            const SizedBox(height: spaceL),
            Text(value.name, style: text.headlineMedium),
            Text(
              '${MealType.fromWire(value.mealType).label} · ${DateFormat('MMM d, h:mm a').format(value.loggedAt.toLocal())}',
              style: text.bodySmall,
            ),
            const SizedBox(height: spaceL),
            FitnessCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UnitValue(value: formatAmount(value.nutrition.calories), unit: 'kcal', color: AppColors.energy, size: 34),
                  const SizedBox(height: spaceM),
                  Row(
                    children: [
                      for (final (label, v, color) in [
                        ('Protein', value.nutrition.protein, AppColors.protein),
                        ('Carbs', value.nutrition.carbohydrates, AppColors.carbs),
                        ('Fat', value.nutrition.fat, AppColors.fat),
                      ])
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: text.bodySmall),
                              UnitValue(value: formatAmount(v), unit: 'g', color: color, size: 17),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: spaceXl),
                  Row(
                    children: [
                      Text('Fiber', style: text.bodyMedium),
                      const Spacer(),
                      UnitValue(value: formatAmount(value.nutrition.fiber ?? 0), unit: 'g', color: AppColors.fiber, size: 17),
                    ],
                  ),
                ],
              ),
            ),
            if (value.wasUserCorrected)
              Padding(
                padding: const EdgeInsets.only(top: spaceM),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: AppColors.success),
                    const SizedBox(width: spaceS),
                    Text('You corrected this estimate', style: text.bodyMedium),
                  ],
                ),
              ),
            if (value.notes != null) ...[const SizedBox(height: spaceM), FitnessCard(title: 'Notes', child: Text(value.notes!))],
            if (value.items.isNotEmpty) ...[
              const SizedBox(height: spaceM),
              FitnessCard(
                title: 'Items',
                child: Column(
                  children: [
                    for (final i in value.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.name),
                        subtitle: i.serving == null ? null : Text(i.serving!, style: text.bodySmall),
                        trailing: Text('${formatAmount(i.nutrition.calories)} kcal', style: const TextStyle(color: AppColors.energy)),
                      ),
                  ],
                ),
              ),
            ],
            const EstimateDisclaimer(),
          ],
        ),
        AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(mealProvider(id))),
        _ => const LoadingState(),
      },
    );
  }
}

class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _id = const Uuid().v4();
  final _name = TextEditingController(), _notes = TextEditingController();
  final _kcal = TextEditingController(),
      _protein = TextEditingController(),
      _carbs = TextEditingController(),
      _fat = TextEditingController();
  MealType _type = MealType.snack;
  bool _saving = false;
  String? _error;

  double? _opt(TextEditingController c) => c.text.trim().isEmpty ? 0 : double.tryParse(c.text.trim());

  Future<void> _save() async {
    final kcal = double.tryParse(_kcal.text.trim());
    final p = _opt(_protein), c = _opt(_carbs), f = _opt(_fat);
    if (_name.text.trim().isEmpty || kcal == null || kcal < 0 || p == null || c == null || f == null) {
      setState(() => _error = 'Enter a name and valid calorie amount.');
      return;
    }
    if (ref.read(offlineProvider).value ?? false) {
      setState(() => _error = "You're offline. Connect to save.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    try {
      await ref
          .read(apiProvider)
          .saveMeal(
            Meal(
              id: _id,
              name: _name.text.trim(),
              mealType: _type.name,
              loggedAt: now,
              localDate: localDateKey(now),
              nutrition: Nutrition(calories: kcal, protein: p, carbohydrates: c, fat: f),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
      invalidateNutrition(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal logged')));
      context.go('/summary');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _number(TextEditingController c, String label, String unit) => Padding(
    padding: const EdgeInsets.only(bottom: spaceM),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label, suffixText: unit),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add meal')),
    body: ListView(
      padding: const EdgeInsets.all(spaceL),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Food name'),
        ),
        const SizedBox(height: spaceM),
        DropdownButtonFormField<MealType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final t in MealType.values) DropdownMenuItem(value: t, child: Text(t.label))],
          onChanged: (t) => setState(() => _type = t ?? _type),
        ),
        const SizedBox(height: spaceM),
        _number(_kcal, 'Calories', 'kcal'),
        _number(_protein, 'Protein (optional)', 'g'),
        _number(_carbs, 'Carbs (optional)', 'g'),
        _number(_fat, 'Fat (optional)', 'g'),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: spaceM),
            child: Text(_error!, style: const TextStyle(color: AppColors.energy)),
          ),
        const SizedBox(height: spaceXl),
        PrimaryButton(label: 'Save meal', loading: _saving, onPressed: _save),
      ],
    ),
  );
}
