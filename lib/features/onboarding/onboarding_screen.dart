import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/common.dart';
import '../../domain/nutrition.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  GoalMode? _mode;
  final _diet = <DietaryRestriction>{};
  double _ambition = 0.5;
  bool? _circle;
  bool _saving = false;
  String? _error;

  bool get _canContinue => switch (_step) {
    0 => _mode != null,
    3 => _circle != null,
    _ => true,
  };

  Future<void> _finish({bool skip = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (skip) {
        // Server goals already hold the Maintenance defaults.
        await ref.read(sessionProvider.notifier).updateProfile({'onboarding_completed': true});
        return;
      }
      final mode = _mode!;
      await ref.read(apiProvider).saveGoals(mode.suggestedTargets.copyWith(proteinTarget: mode.proteinForAmbition(_ambition)));
      await ref.read(sessionProvider.notifier).updateProfile({
        'dietary_restrictions': _diet.map((d) => d.wire).toList(),
        'privacy': {'streak_sharing': _circle},
        'onboarding_completed': true,
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _option(String title, String? detail, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceM),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.brand.withValues(alpha: 0.16) : AppColors.dark.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tileRadius(context)),
            side: BorderSide(color: selected ? AppColors.brand : Colors.transparent, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(tileRadius(context)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(spaceL),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        if (detail != null) Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (selected) const Icon(Icons.check_circle, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(children: [for (final m in GoalMode.values) _option(m.label, m.detail, _mode == m, () => setState(() => _mode = m))]);
      case 1:
        return Column(
          children: [
            for (final d in DietaryRestriction.values)
              _option(d.label, null, _diet.contains(d), () => setState(() => _diet.contains(d) ? _diet.remove(d) : _diet.add(d))),
          ],
        );
      case 2:
        final grams = (_mode ?? GoalMode.maintenance).proteinForAmbition(_ambition);
        return Column(
          children: [
            const SizedBox(height: spaceXl),
            Text(
              '${grams.toInt()} g a day',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.protein, fontSize: 56),
            ),
            Slider(
              value: _ambition,
              activeColor: AppColors.protein,
              inactiveColor: metricTrack(AppColors.protein),
              label: '${grams.toInt()} g',
              semanticFormatterCallback: (_) => '${grams.toInt()} grams a day',
              onChanged: (v) => setState(() => _ambition = v),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gentle', style: TextStyle(color: AppColors.muted)),
                Text('Ambitious', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ],
        );
      default:
        return Column(
          children: [
            _option('Yes', 'Share only your streak with friends you invite.', _circle == true, () => setState(() => _circle = true)),
            _option('Not now', 'You can turn this on later in Privacy.', _circle == false, () => setState(() => _circle = false)),
          ],
        );
    }
  }

  static const _titles = [
    ('What are you working towards?', 'This sets your starting targets. You can change them any time.'),
    ('How do you eat?', 'Choose all that apply.'),
    ('How hard do you want to push protein?', 'Slide to set a daily protein target.'),
    ('Want a private accountability circle?', 'Circles see your streak and whether you logged today. Never calories, weight or photos.'),
  ];

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _titles[_step];
    return Theme(
      data: buildTheme(Brightness.dark, Theme.of(context).platform),
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _step--);
        },
        child: Scaffold(
          backgroundColor: AppColors.dark.canvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => setState(() => _step--),
                        ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_step + 1) / 4,
                          color: AppColors.brand,
                          backgroundColor: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                          semanticsLabel: 'Step ${_step + 1} of 4',
                        ),
                      ),
                      if (_step == 0) TextButton(onPressed: _saving ? null : () => _finish(skip: true), child: const Text('Skip')),
                    ],
                  ),
                  const SizedBox(height: spaceXl),
                  Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
                  const SizedBox(height: spaceS),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 17)),
                  const SizedBox(height: spaceXl),
                  Expanded(child: SingleChildScrollView(child: _content())),
                  if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.errorText)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 160,
                      child: PrimaryButton(
                        label: _step == 3 ? 'Finish' : 'Next',
                        loading: _saving,
                        onPressed: !_canContinue ? null : (_step == 3 ? _finish : () => setState(() => _step++)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
