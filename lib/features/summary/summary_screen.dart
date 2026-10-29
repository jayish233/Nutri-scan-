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
import '../../domain/protein_navigator.dart';
import '../goals/goals_sheet.dart';
import '../meals/history_screen.dart';

String _grouped(double v) => NumberFormat.decimalPattern().format(v.round());

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayKey();
    final async = ref.watch(summaryProvider(today));
    final offline = ref.watch(offlineProvider).value ?? false;
    final user = ref.watch(currentUserProvider);
    final data = async.value;

    return Scaffold(
      // Android adds an extended FAB for scanning; iOS uses the Scan tab.
      floatingActionButton: isCupertino(context)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/scan'),
              icon: const Icon(Icons.center_focus_weak),
              label: const Text('Scan meal'),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (offline || (data?.fromCache ?? false)) const OfflineBanner(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.brand,
                onRefresh: () => ref.refresh(summaryProvider(today).future),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: scrollBottomInset),
                  children: [
                    ScreenHeader(
                      title: 'Summary',
                      subtitle: friendlyDate(DateTime.now()),
                      trailing: IconButton(
                        tooltip: 'Profile',
                        onPressed: () => context.go('/profile'),
                        icon: CircleAvatar(
                          backgroundColor: AppColors.brand,
                          child: Text(
                            (user?.displayName.isNotEmpty ?? false) ? user!.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: spaceL),
                      child: switch (async) {
                        AsyncValue(:final value?) => _Body(summary: value.summary),
                        AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(summaryProvider(today))),
                        _ => const Padding(padding: EdgeInsets.only(top: 80), child: LoadingState()),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = summary.totals, g = summary.goals;
    final mode = GoalMode.fromWire(g.mode);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final left = (g.calorieTarget - t.calories).clamp(0, double.infinity).toDouble();
    void openHistory() => context.push('/history');

    Widget tile(String title, double value, Color color, double? target) => Expanded(
      child: NutrientTile(title: title, value: value, color: color, target: target, onTap: openHistory),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: StreakChip(days: summary.streakDays),
        ),
        const SizedBox(height: spaceM),
        WeekStrip(selected: DateTime.now(), calorieGoal: g.calorieTarget, onSelect: (_) => openHistory()),
        const SizedBox(height: spaceM),
        Semantics(
          button: true,
          label: 'Energy, ${_grouped(t.calories)} of ${_grouped(g.calorieTarget)} calories, ${_grouped(left)} left. Opens goals.',
          child: FitnessCard(
            title: 'Energy',
            onTap: () => showGoalsSheet(context, ref),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  MetricRing(
                    progress: t.calories / g.calorieTarget,
                    color: AppColors.energy,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_grouped(left), style: text.headlineSmall),
                        Text('left', style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: spaceL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Eaten', style: text.bodySmall),
                        Text(_grouped(t.calories), style: text.headlineLarge?.copyWith(color: AppColors.energy)),
                        Text('of ${_grouped(g.calorieTarget)} kcal', style: text.bodyMedium),
                        const SizedBox(height: spaceS),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: spaceM, vertical: spaceXs),
                          decoration: BoxDecoration(color: c.cardElevated, borderRadius: BorderRadius.circular(100)),
                          child: Text(
                            mode.label,
                            style: TextStyle(color: c.brandDeep, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: spaceM),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Protein', t.protein, AppColors.protein, g.proteinTarget),
              const SizedBox(width: spaceS + 2),
              tile('Carbs', t.carbohydrates, AppColors.carbs, g.carbohydrateTarget),
            ],
          ),
        ),
        const SizedBox(height: spaceS + 2),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Fat', t.fat, AppColors.fat, g.fatTarget),
              const SizedBox(width: spaceS + 2),
              tile('Fiber', t.fiber ?? 0, AppColors.fiber, null),
            ],
          ),
        ),
        const SizedBox(height: spaceM),
        _ProteinNavigatorCard(consumed: t.protein, target: g.proteinTarget),
        const SizedBox(height: spaceM),
        FitnessCard(
          title: 'Meals',
          onTap: openHistory,
          child: summary.meals.isEmpty
              ? EmptyState(
                  icon: Icons.restaurant,
                  title: 'No meals recorded.',
                  message: 'Your logged meals will show here.',
                  actionLabel: 'Scan your first meal',
                  onAction: () => context.go('/scan'),
                )
              : Column(
                  children: [for (final m in summary.meals) MealRow(meal: m, onTap: () => context.push('/meal/${m.id}'))],
                ),
        ),
        const EstimateDisclaimer(),
      ],
    );
  }
}

class _ProteinNavigatorCard extends ConsumerWidget {
  const _ProteinNavigatorCard({required this.consumed, required this.target});

  final double consumed, target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(proteinFoodsProvider).value;
    final user = ref.watch(currentUserProvider);
    if (foods == null) return const SizedBox.shrink();
    final s = suggestProtein(
      consumedProtein: consumed,
      proteinTarget: target,
      restrictions: DietaryRestriction.fromWire(user?.dietaryRestrictions ?? const []),
      catalog: foods,
    );
    return FitnessCard(
      title: 'Protein Navigator',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: metricTrack(AppColors.protein), shape: BoxShape.circle),
            child: const Icon(Icons.explore, color: AppColors.protein, size: 22),
          ),
          const SizedBox(width: spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.protein)),
                const SizedBox(height: spaceXs),
                Text(s.reason, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
