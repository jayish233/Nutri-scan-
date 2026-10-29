import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';
import '../circles/circles_screen.dart';
import '../../domain/nutrition.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final count = _month ? 30 : 7;
    final days = [for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final range = (localDateKey(days.first), localDateKey(days.last));
    final async = ref.watch(dailyStatsProvider(range));
    final goal = ref.watch(summaryProvider(todayKey())).value?.summary.goals.calorieTarget;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: scrollBottomInset),
          children: [
            const ScreenHeader(title: 'Progress', subtitle: 'How meals and training add up'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Week')),
                      ButtonSegment(value: true, label: Text('Month')),
                    ],
                    selected: {_month},
                    showSelectedIcon: !isCupertino(context),
                    onSelectionChanged: (v) => setState(() => _month = v.first),
                  ),
                  const SizedBox(height: spaceM),
                  switch (async) {
                    AsyncValue(:final value?) => _Overview(stats: value, days: days, goal: goal),
                    AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(dailyStatsProvider(range))),
                    _ => const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: LoadingState()),
                  },
                  const SizedBox(height: spaceM),
                  const _CirclesCard(),
                  GroupedCard(
                    title: 'Insights',
                    children: [
                      CardRow(
                        leading: const Icon(Icons.bar_chart, color: AppColors.energy),
                        title: 'Weekly charts',
                        detail: 'Energy, protein and workouts for 7 days',
                        onTap: () => context.push('/weekly'),
                      ),
                      CardRow(
                        leading: const Icon(Icons.calendar_month, color: AppColors.protein),
                        title: 'Meal history',
                        detail: 'Any day, with its meals and totals',
                        onTap: () => context.push('/history'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accountability: everyone in your circles, with streak and "logged today" only.
class _CirclesCard extends ConsumerWidget {
  const _CirclesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(circlesProvider);
    // One row per person even when you share several circles with them.
    final members =
        {
          for (final c in circles.value ?? const <Circle>[])
            for (final m in c.members) m.userId: m,
        }.values.toList()..sort((a, b) {
          final logged = ((b.loggedToday ?? false) ? 1 : 0) - ((a.loggedToday ?? false) ? 1 : 0);
          return logged != 0 ? logged : (b.streakDays ?? 0) - (a.streakDays ?? 0);
        });
    return FitnessCard(
      title: 'Accountability',
      onTap: () => context.push('/circles'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (circles.hasError)
            Text("Couldn't load circles. Tap to try again.", style: Theme.of(context).textTheme.bodySmall)
          else if (circles.value?.isEmpty ?? false)
            Text('Start or join a circle to keep each other going.', style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final m in members) CircleMemberRow(member: m),
          const SizedBox(height: spaceS),
          Text(circlesPrivacyText, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Daily calories with a dashed goal line (today in lime), then protein average and days logged.
class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.days, this.goal});

  final List<DailyStat> stats;
  final List<DateTime> days;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final calories = [for (final s in stats) s.nutrition.calories];
    final logged = stats.where((s) => s.mealCount > 0).toList();
    // Averages over logged days only, so a missed day never drags the number down.
    double avg(double Function(DailyStat) pick) => logged.isEmpty ? 0 : logged.fold<double>(0, (a, s) => a + pick(s)) / logged.length;
    Widget tile(String title, String value, String unit, Color color) => Expanded(
      child: FitnessCard(
        padding: const EdgeInsets.all(spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.bodySmall),
            const SizedBox(height: spaceXs),
            UnitValue(value: value, unit: unit, color: color),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FitnessCard(
          title: 'Daily average',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UnitValue(
                value: formatAmount(avg((s) => s.nutrition.calories).roundToDouble()),
                unit: 'kcal',
                color: AppColors.energy,
                size: 28,
              ),
              if (goal != null) Text('Goal ${formatAmount(goal!)} kcal', style: text.bodySmall),
              const SizedBox(height: spaceL),
              Bars(
                values: calories,
                color: AppColors.energy,
                lastColor: AppColors.brand,
                goal: goal,
                height: 140,
                labels: days.length <= 7 ? [for (final d in days) DateFormat('E').format(d).substring(0, 1)] : null,
                semanticLabel: 'Calories for the last ${days.length} days: ${calories.map(formatAmount).join(', ')}',
              ),
            ],
          ),
        ),
        const SizedBox(height: spaceM),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Protein average', formatAmount(avg((s) => s.nutrition.protein).roundToDouble()), 'g', AppColors.protein),
              const SizedBox(width: spaceS + 2),
              tile('Days logged', '${logged.length}', 'of ${days.length}', AppColors.fiber),
            ],
          ),
        ),
      ],
    );
  }
}

class WeeklyChartsScreen extends ConsumerWidget {
  const WeeklyChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final range = (localDateKey(days.first), localDateKey(days.last));
    final async = ref.watch(dailyStatsProvider(range));
    final labels = [for (final d in days) DateFormat('E').format(d).substring(0, 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly charts')),
      body: switch (async) {
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.all(spaceL),
          children: [
            for (final (title, unit, color, values) in [
              ('Energy', 'kcal', AppColors.energy, [for (final s in value) s.nutrition.calories]),
              ('Protein', 'g', AppColors.protein, [for (final s in value) s.nutrition.protein]),
              ('Workout frequency', 'sessions', AppColors.brand, [for (final s in value) s.workoutCount.toDouble()]),
            ]) ...[
              FitnessCard(
                title: title,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average ${formatAmount((values.fold<double>(0, (a, b) => a + b) / 7).roundToDouble())} $unit a day',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: spaceM),
                    Bars(
                      values: values,
                      color: color,
                      height: 120,
                      labels: labels,
                      semanticLabel: '$title for the last 7 days: ${values.map(formatAmount).join(', ')} $unit',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: spaceM),
            ],
          ],
        ),
        AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(dailyStatsProvider(range))),
        _ => const LoadingState(),
      },
    );
  }
}
