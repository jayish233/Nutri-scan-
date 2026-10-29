import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/widgets/common.dart';

const circlesPrivacyText = 'Circles share streaks only — never calories, weight, or body images.';

/// Name, "Logged today" / "Not yet" and streak days. A member who turned sharing off shows "Streak hidden".
class CircleMemberRow extends StatelessWidget {
  const CircleMemberRow({super.key, required this.member});

  final CircleMember member;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final logged = member.loggedToday ?? false;
    final status = !member.sharing
        ? 'Streak hidden'
        : logged
        ? 'Logged today'
        : 'Not yet';
    final streak = member.streakDays ?? 0;
    return Semantics(
      label: '${member.displayName}, $status${member.sharing ? ', $streak day streak' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: spaceS),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.cardElevated,
                child: Text(
                  member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase(),
                  style: TextStyle(color: c.primaryText, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(status, style: text.bodySmall?.copyWith(color: logged ? AppColors.success : null)),
                  ],
                ),
              ),
              if (member.sharing) ...[
                Icon(Icons.local_fire_department, size: 18, color: streak > 0 ? AppColors.energy : c.secondaryText),
                const SizedBox(width: spaceXs),
                Text('$streak ${streak == 1 ? 'day' : 'days'}', style: text.titleMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CirclesScreen extends ConsumerStatefulWidget {
  const CirclesScreen({super.key});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen> {
  final _name = TextEditingController(), _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(circlesProvider);
      _name.clear();
      _code.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(Circle circle) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Leave ${circle.name}?'),
        content: const Text('You can rejoin later with the invite code while anyone is still in it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
        ],
      ),
    );
    if (sure ?? false) await _run(() => ref.read(apiProvider).leaveCircle(circle.id), 'You left ${circle.name}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(circlesProvider);
    final text = Theme.of(context).textTheme;
    final sharing = ref.watch(currentUserProvider)?.privacy['streak_sharing'] ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Circles')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(spaceL, 0, spaceL, spaceXl),
        children: [
          Text(circlesPrivacyText, style: text.bodySmall),
          if (!sharing)
            Padding(
              padding: const EdgeInsets.only(top: spaceS),
              child: Text('Your streak is hidden. Turn on "Share my streak" in Profile to show it.', style: text.bodySmall),
            ),
          const SizedBox(height: spaceL),
          FitnessCard(
            title: 'Create a circle',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Circle name'),
                  onChanged: (_) => setState(() {}),
                ),
                PrimaryButton(
                  label: 'Create',
                  loading: _busy,
                  onPressed: _name.text.trim().isEmpty
                      ? null
                      : () => _run(
                          () => ref.read(apiProvider).createCircle(_name.text.trim()),
                          'Circle created. Share its code with friends.',
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: spaceM),
          FitnessCard(
            title: 'Join a circle',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _code,
                  maxLength: 6,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Invite code'),
                  onChanged: (_) => setState(() {}),
                ),
                SecondaryButton(
                  label: 'Join',
                  onPressed: _busy || _code.text.trim().length != 6
                      ? null
                      : () => _run(() => ref.read(apiProvider).joinCircle(_code.text.trim()), 'You joined the circle'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: spaceM),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, style: const TextStyle(color: AppColors.errorText)),
              ),
            ),
          const SizedBox(height: spaceM),
          switch (async) {
            AsyncValue(:final value?) => Column(
              children: [
                for (final circle in value) ...[
                  FitnessCard(
                    title: circle.name,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Code ${circle.inviteCode} · ${circle.members.length} of 5', style: text.bodySmall)),
                            IconButton(
                              tooltip: 'Copy invite code',
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: circle.inviteCode));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied')));
                                }
                              },
                            ),
                          ],
                        ),
                        for (final m in circle.members) CircleMemberRow(member: m),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : () => _leave(circle),
                            child: const Text('Leave circle', style: TextStyle(color: AppColors.energy)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: spaceM),
                ],
              ],
            ),
            AsyncValue(:final error?) => ErrorState(message: '$error', onRetry: () => ref.invalidate(circlesProvider)),
            _ => const LoadingState(),
          },
        ],
      ),
    );
  }
}
