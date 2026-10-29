import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';
import '../../domain/nutrition.dart';

Future<void> showGoalsSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: GoalsSheet()),
);

class GoalsSheet extends ConsumerStatefulWidget {
  const GoalsSheet({super.key});

  @override
  ConsumerState<GoalsSheet> createState() => _GoalsSheetState();
}

class _GoalsSheetState extends ConsumerState<GoalsSheet> {
  Goals? _goals;
  GoalRange _metric = GoalRange.calories;
  String? _message, _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiProvider)
        .goals()
        .then((g) => mounted ? setState(() => _goals = g) : null, onError: (Object e) => mounted ? setState(() => _error = '$e') : null);
  }

  double _value(GoalRange r) => switch (r) {
    GoalRange.calories => _goals!.calorieTarget,
    GoalRange.protein => _goals!.proteinTarget,
    GoalRange.carbs => _goals!.carbohydrateTarget,
    _ => _goals!.fatTarget,
  };

  void _set(GoalRange r, double v) => setState(() {
    v = r.clamp(v);
    _goals = switch (r) {
      GoalRange.calories => _goals!.copyWith(calorieTarget: v),
      GoalRange.protein => _goals!.copyWith(proteinTarget: v),
      GoalRange.carbs => _goals!.copyWith(carbohydrateTarget: v),
      _ => _goals!.copyWith(fatTarget: v),
    };
  });

  Future<void> _save() async {
    final g = _goals!;
    if (g.calorieTarget <= 0 || g.proteinTarget <= 0) {
      setState(() => _error = 'Calories and protein must be greater than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).saveGoals(g);
      invalidateNutrition(ref);
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    if (_goals == null) {
      return _error == null ? const LoadingState() : ErrorState(message: _error!);
    }
    const ranges = [GoalRange.calories, GoalRange.protein, GoalRange.carbs, GoalRange.fat];
    final value = _value(_metric);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('Goals'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(spaceL),
        children: [
          Text('Your daily targets', style: text.headlineMedium),
          const SizedBox(height: spaceS),
          Text(
            'Pick a goal mode for a starting point, then tune each target. These are personal tracking goals, not medical advice.',
            style: text.bodySmall,
          ),
          const SizedBox(height: spaceL),
          SegmentedButton<GoalRange>(
            segments: [for (final r in ranges) ButtonSegment(value: r, label: Text(r.label))],
            selected: {_metric},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _metric = s.first),
            style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.brand, selectedForegroundColor: AppColors.ink),
          ),
          const SizedBox(height: spaceXl),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Decrease ${_metric.label}',
                iconSize: 32,
                icon: const Icon(Icons.remove),
                onPressed: value <= _metric.min ? null : () => _set(_metric, value - _metric.step),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(formatAmount(value), style: text.displayLarge?.copyWith(color: _metric.color)),
                    Text(_metric.unit.toUpperCase(), style: text.labelSmall),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Increase ${_metric.label}',
                iconSize: 32,
                icon: const Icon(Icons.add),
                onPressed: value >= _metric.max ? null : () => _set(_metric, value + _metric.step),
              ),
            ],
          ),
          GroupedCard(
            title: 'All targets',
            children: [
              for (final r in ranges)
                CardRow(
                  title: r.label,
                  trailing: Text(
                    '${formatAmount(_value(r))} ${r.unit}',
                    style: TextStyle(color: r.color, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => setState(() => _metric = r),
                ),
            ],
          ),
          GroupedCard(
            title: 'Goal mode',
            footer: _message,
            children: [
              for (final m in GoalMode.values)
                CardRow(
                  title: m.label,
                  detail: m.detail,
                  trailing: _goals!.mode == m.wire ? Icon(Icons.check, color: c.brandDeep) : null,
                  onTap: () => setState(() {
                    _goals = m.suggestedTargets;
                    _message = 'Applied ${m.label} suggestions — adjust anything below.';
                  }),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: spaceL),
              child: Text(_error!, style: const TextStyle(color: AppColors.energy)),
            ),
          const SizedBox(height: spaceXl),
          PrimaryButton(label: 'Save targets', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
