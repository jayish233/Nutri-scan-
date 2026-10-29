import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/common.dart';
import '../../domain/nutrition.dart';
import '../goals/goals_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This removes your meals, goals, photos and account for good. Enter your password to continue.'),
            const SizedBox(height: spaceM),
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, password.text), child: const Text('Continue')),
        ],
      ),
    );
    if (entered == null || entered.isEmpty || !mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep my account')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete everything', style: TextStyle(color: AppColors.energy)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(sessionProvider.notifier).deleteAccount(entered);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _update(Map<String, dynamic> changes) async {
    try {
      await ref.read(sessionProvider.notifier).updateProfile(changes);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final mode = ref.watch(themeModeProvider);
    final goals = ref.watch(summaryProvider(todayKey())).value?.summary.goals;
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    if (user == null) return const Scaffold(body: LoadingState());
    final diet = DietaryRestriction.fromWire(user.dietaryRestrictions);
    void openGoals() => showGoalsSheet(context, ref);
    Widget value(String v) => Text(v, style: text.bodyMedium?.copyWith(color: c.secondaryText));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: scrollBottomInset),
          children: [
            ScreenHeader(title: 'Profile', subtitle: '@${user.username}'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FitnessCard(
                    onTap: () => context.push('/profile/edit'),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.brand,
                          child: Text(
                            user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 26, color: AppColors.ink, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: spaceL),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, style: text.headlineSmall),
                              Text(user.email, style: text.bodySmall),
                              if (user.bio.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: spaceXs),
                                  child: Text(user.bio),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: c.secondaryText),
                      ],
                    ),
                  ),
                  GroupedCard(
                    title: 'Goals',
                    children: [
                      CardRow(title: 'Goal mode', trailing: value(GoalMode.fromWire(goals?.mode).label), onTap: openGoals),
                      CardRow(
                        title: 'Daily energy',
                        trailing: value(goals == null ? '—' : '${formatAmount(goals.calorieTarget)} kcal'),
                        onTap: openGoals,
                      ),
                      CardRow(
                        title: 'Macros',
                        trailing: value(
                          goals == null
                              ? '—'
                              : '${formatAmount(goals.proteinTarget)}P · ${formatAmount(goals.carbohydrateTarget)}C · ${formatAmount(goals.fatTarget)}F',
                        ),
                        onTap: openGoals,
                      ),
                    ],
                  ),
                  GroupedCard(
                    title: 'Dietary preferences',
                    footer: 'Used for next-meal ideas and allergen awareness. Not a medical allergy profile.',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(spaceL),
                        child: Wrap(
                          spacing: spaceS,
                          runSpacing: spaceS,
                          children: [
                            for (final d in DietaryRestriction.values)
                              FilterChip(
                                label: Text(d.label),
                                selected: diet.contains(d),
                                showCheckmark: false,
                                labelStyle: TextStyle(color: diet.contains(d) ? AppColors.ink : c.primaryText, fontWeight: FontWeight.w600),
                                onSelected: (on) => _update({
                                  'dietary_restrictions': [
                                    for (final r in DietaryRestriction.values)
                                      if (r == d ? on : diet.contains(r)) r.wire,
                                  ],
                                }),
                              ),
                          ],
                        ),
                      ),
                      CardRow(title: 'Dietary notes', onTap: () => context.push('/profile/diet')),
                    ],
                  ),
                  GroupedCard(
                    title: 'Circles',
                    footer: 'Circles only ever see your streak and whether you logged today. Never calories, weight or photos.',
                    children: [
                      SwitchListTile(
                        title: const Text('Share my streak'),
                        value: user.privacy['streak_sharing'] ?? false,
                        onChanged: (v) => _update({
                          'privacy': {'streak_sharing': v},
                        }),
                      ),
                    ],
                  ),
                  GroupedCard(
                    title: 'Account',
                    children: [
                      CardRow(title: 'Edit profile', onTap: () => context.push('/profile/edit')),
                      CardRow(title: 'Privacy & data', onTap: () => context.push('/profile/privacy')),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(spaceL, spaceL, spaceL, spaceS),
                    child: Text('APPEARANCE', style: text.labelSmall),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {mode},
                    showSelectedIcon: !isCupertino(context),
                    onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).set(v.first),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(spaceL, spaceS, spaceL, 0),
                    child: Text('Dark is recommended. NutriScan is designed for it.', style: text.bodySmall),
                  ),
                  const EstimateDisclaimer(),
                  SecondaryButton(
                    label: _signingOut ? 'Signing out…' : 'Sign out',
                    onPressed: _signingOut
                        ? null
                        : () async {
                            setState(() => _signingOut = true);
                            await ref.read(sessionProvider.notifier).signOut();
                          },
                  ),
                  const SizedBox(height: spaceM),
                  TextButton(
                    onPressed: _deleteAccount,
                    child: const Text('Delete account', style: TextStyle(color: AppColors.energy)),
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

/// Shared save handling for the small profile forms.
mixin _SaveProfile<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool saving = false;
  String? error;

  Future<void> save(Map<String, dynamic> changes) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).updateProfile(changes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        context.pop();
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> with _SaveProfile {
  late final _user = ref.read(currentUserProvider)!;
  late final _name = TextEditingController(text: _user.displayName);
  late final _username = TextEditingController(text: _user.username);
  late final _bio = TextEditingController(text: _user.bio);

  void _submit() {
    final username = _username.text.trim().toLowerCase();
    if (_name.text.trim().length < 2) return setState(() => error = 'Enter a display name of 2 or more characters.');
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      return setState(() => error = 'Usernames are 3-20 letters, numbers or underscores.');
    }
    save({'display_name': _name.text.trim(), 'username': username, 'bio': _bio.text.trim()});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: ListView(
      padding: const EdgeInsets.all(spaceL),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Display name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: spaceM),
        TextField(
          controller: _username,
          decoration: const InputDecoration(labelText: 'Username', prefixText: '@'),
          autocorrect: false,
        ),
        const SizedBox(height: spaceM),
        TextField(
          controller: _bio,
          maxLength: 160,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Bio'),
        ),
        if (error != null) Text(error!, style: const TextStyle(color: AppColors.energy)),
        const SizedBox(height: spaceL),
        PrimaryButton(label: 'Save', loading: saving, onPressed: _submit),
      ],
    ),
  );
}

class DietScreen extends ConsumerStatefulWidget {
  const DietScreen({super.key});

  @override
  ConsumerState<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends ConsumerState<DietScreen> with _SaveProfile {
  late final _user = ref.read(currentUserProvider)!;
  late final _selected = DietaryRestriction.fromWire(_user.dietaryRestrictions);
  late final _notes = TextEditingController(text: _user.dietaryNotes);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dietary preferences')),
    body: ListView(
      padding: const EdgeInsets.all(spaceL),
      children: [
        GroupedCard(
          footer: 'Used for next-meal ideas and allergen awareness. Not a medical allergy profile.',
          children: [
            for (final d in DietaryRestriction.values)
              CardRow(
                title: d.label,
                trailing: _selected.contains(d) ? Icon(Icons.check, color: AppColors.of(context).brandDeep) : null,
                onTap: () => setState(() => _selected.contains(d) ? _selected.remove(d) : _selected.add(d)),
              ),
          ],
        ),
        const SizedBox(height: spaceL),
        TextField(
          controller: _notes,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        if (error != null) Text(error!, style: const TextStyle(color: AppColors.energy)),
        const SizedBox(height: spaceL),
        PrimaryButton(
          label: 'Save',
          loading: saving,
          onPressed: () => save({'dietary_restrictions': _selected.map((d) => d.wire).toList(), 'dietary_notes': _notes.text.trim()}),
        ),
      ],
    ),
  );
}

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  String? _error;

  Future<void> _toggle(String key, bool value) async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).updateProfile({
        'privacy': {key: value},
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(currentUserProvider)?.privacy ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: ListView(
        padding: const EdgeInsets.all(spaceL),
        children: [
          GroupedCard(
            footer: 'Circles only ever see your streak and whether you logged today. Never calories, weight or photos.',
            children: [
              for (final (key, label) in const [
                ('profile_public', 'Public profile'),
                ('nutrition_visible', 'Share nutrition consistency'),
                ('workouts_visible', 'Share workouts'),
                ('streak_sharing', 'Streak sharing in circles'),
              ])
                SwitchListTile(title: Text(label), value: privacy[key] ?? false, onChanged: (v) => _toggle(key, v)),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: spaceM),
              child: Text(_error!, style: const TextStyle(color: AppColors.energy)),
            ),
        ],
      ),
    );
  }
}
