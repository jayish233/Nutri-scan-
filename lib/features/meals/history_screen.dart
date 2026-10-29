import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/rings.dart';
import '../../domain/nutrition.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _selected = _day(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final key = localDateKey(_selected);
    final async = ref.watch(summaryProvider(key));
    final goal = async.value?.summary.goals.calorieTarget ?? 2200;
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, MMM d').format(_selected)),
        actions: [
          IconButton(
            tooltip: 'Pick a date',
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showModalBottomSheet<DateTime>(
                context: context,
                builder: (_) => CalendarSheet(initial: _selected, calorieGoal: goal),
              );
              if (picked != null) setState(() => _selected = picked);
            },
          ),
          IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh), onPressed: () => invalidateNutrition(ref)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(spaceL, 0, spaceL, spaceXl),
        children: [
          WeekStrip(selected: _selected, calorieGoal: goal, onSelect: (d) => setState(() => _selected = d)),
          const SizedBox(height: spaceL),
          switch (async) {
            AsyncValue(:final value?) => _Day(summary: value.summary),
            AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(summaryProvider(key))),
            _ => const Padding(padding: EdgeInsets.only(top: 80), child: LoadingState()),
          },
        ],
      ),
    );
  }
}

/// Seven days with a mini energy ring each; today in lime. Shared by Summary and Meal history.
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key, required this.selected, required this.calorieGoal, required this.onSelect});

  final DateTime selected;
  final double calorieGoal;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    final stats = ref.watch(dailyStatsProvider((localDateKey(days.first), localDateKey(days.last)))).value ?? const [];
    final byDate = {for (final s in stats) s.date: s};
    final c = AppColors.of(context);
    final today = _day(DateTime.now());
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Semantics(
              button: true,
              selected: d == selected,
              label: DateFormat('EEEE, MMM d').format(d),
              child: InkWell(
                borderRadius: BorderRadius.circular(radiusChip),
                onTap: d.isAfter(today) ? null : () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: spaceS),
                  decoration: BoxDecoration(color: d == selected ? c.cardElevated : null, borderRadius: BorderRadius.circular(radiusChip)),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('E').format(d)[0], style: text(context, d == selected, d == today)),
                        const SizedBox(height: spaceXs),
                        MiniRingGlyph(progress: (byDate[localDateKey(d)]?.nutrition.calories ?? 0) / calorieGoal),
                        const SizedBox(height: spaceXs),
                        Text('${d.day}', style: text(context, d == selected, d == today)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  TextStyle text(BuildContext context, bool selected, bool isToday) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: isToday
        ? AppColors.of(context).brandDeep
        : selected
        ? AppColors.of(context).primaryText
        : AppColors.of(context).secondaryText,
  );
}

class _Day extends StatelessWidget {
  const _Day({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final t = summary.totals, g = summary.goals;
    final text = Theme.of(context).textTheme;
    if (summary.meals.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_today,
        title: 'Nothing logged that day.',
        message: 'Pick another day, or scan your next meal.',
      );
    }
    final buckets = twoHourBuckets(summary.meals, (n) => n.calories);
    final peak = buckets.indexOf(buckets.reduce((a, b) => a > b ? a : b));
    final peakLabel = DateFormat.j().format(DateTime(2000, 1, 1, peak * 2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MetricRing(
            progress: t.calories / g.calorieTarget,
            color: AppColors.energy,
            size: 240,
            stroke: 38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatAmount(t.calories), style: text.headlineLarge?.copyWith(color: AppColors.energy)),
                Text('of ${formatAmount(g.calorieTarget)} CAL', style: text.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: spaceL),
        FitnessCard(
          title: 'Energy through the day',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Peak around $peakLabel', style: text.bodySmall),
              const SizedBox(height: spaceS),
              Bars(
                values: buckets,
                color: AppColors.energy,
                height: 100,
                labels: twoHourLabels,
                semanticLabel: 'Calories in two-hour blocks, peak around $peakLabel',
              ),
              const SizedBox(height: spaceS),
              Text('Total ${formatAmount(t.calories)} cal', style: text.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: spaceM),
        Row(
          children: [
            for (final (label, v, color) in [
              ('Protein', t.protein, AppColors.protein),
              ('Carbs', t.carbohydrates, AppColors.carbs),
              ('Fat', t.fat, AppColors.fat),
              ('Fiber', t.fiber ?? 0, AppColors.fiber),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(label, style: text.bodySmall),
                    UnitValue(value: formatAmount(v), unit: 'g', color: color, size: 17),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: spaceM),
        FitnessCard(
          title: 'Meals',
          child: Column(
            children: [for (final m in summary.meals) MealRow(meal: m, onTap: () => context.push('/meal/${m.id}'))],
          ),
        ),
        const EstimateDisclaimer(),
      ],
    );
  }
}

/// Month grid with a mini ring per day.
class CalendarSheet extends ConsumerStatefulWidget {
  const CalendarSheet({super.key, required this.initial, required this.calorieGoal});

  final DateTime initial;
  final double calorieGoal;

  @override
  ConsumerState<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends ConsumerState<CalendarSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  @override
  Widget build(BuildContext context) {
    final first = _month, last = DateTime(_month.year, _month.month + 1, 0);
    final stats = ref.watch(dailyStatsProvider((localDateKey(first), localDateKey(last)))).value ?? const [];
    final byDate = {for (final s in stats) s.date: s};
    final today = _day(DateTime.now());
    final lead = first.weekday - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(spaceL, 0, spaceL, spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: last.isBefore(today) ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              childAspectRatio: 0.8,
              children: [
                for (final l in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: Text(l, style: Theme.of(context).textTheme.bodySmall)),
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var d = 1; d <= last.day; d++)
                  Builder(
                    builder: (context) {
                      final date = DateTime(_month.year, _month.month, d);
                      return InkWell(
                        borderRadius: BorderRadius.circular(radiusSmall),
                        onTap: date.isAfter(today) ? null : () => Navigator.pop(context, date),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MiniRingGlyph(progress: (byDate[localDateKey(date)]?.nutrition.calories ?? 0) / widget.calorieGoal),
                            Text('$d', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
