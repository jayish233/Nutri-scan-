import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/common.dart';

enum _Phase { idle, uploading, analysing, error }

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  _Phase _phase = _Phase.idle;
  String _error = '';
  CancelToken? _cancel;

  Future<void> _pick(ImageSource source) async {
    // S1: JPEG, longest side 1280 px, quality ~0.72, done by the system picker before upload.
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 72);
    } catch (_) {
      _fail(
        source == ImageSource.camera
            ? 'NutriScan needs camera access to scan. Allow it in Settings, or choose from the gallery.'
            : "Couldn't open your photos. Try again.",
      );
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final cancel = _cancel = CancelToken();
    setState(() => _phase = _Phase.uploading);
    try {
      final result = await ref
          .read(apiProvider)
          .scan(
            bytes,
            cancel: cancel,
            onSendProgress: (sent, total) {
              if (sent == total && mounted && _phase == _Phase.uploading) setState(() => _phase = _Phase.analysing);
            },
          );
      if (!mounted || cancel.isCancelled) return;
      setState(() => _phase = _Phase.idle);
      context.push('/scan/review', extra: (result, bytes));
    } on ApiError catch (e) {
      if (e.kind == ApiErrorKind.cancelled) return;
      _fail(switch (e.kind) {
        ApiErrorKind.quotaExceeded =>
          "You've used today's scans. They reset ${e.resetAt == null ? 'tomorrow' : 'at ${DateFormat.jm().format(e.resetAt!.toLocal())}'}. You can still add a meal manually.",
        _ => e.message,
      });
    }
  }

  void _fail(String message) {
    if (mounted) {
      setState(() {
        _phase = _Phase.error;
        _error = message;
      });
    }
  }

  void _cancelScan() {
    _cancel?.cancel();
    setState(() => _phase = _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider).value ?? false;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (_phase) {
          _Phase.uploading || _Phase.analysing => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingState(
                message: _phase == _Phase.uploading ? 'Uploading meal photo…' : 'Analysing your meal…',
                detail: _phase == _Phase.analysing ? 'Detecting foods and estimating nutrition.' : null,
              ),
              TextButton(onPressed: _cancelScan, child: const Text('Cancel')),
            ],
          ),
          _Phase.error => Center(
            child: SingleChildScrollView(
              child: ErrorState(
                message: _error,
                onRetry: () => setState(() => _phase = _Phase.idle),
                extra: SecondaryButton(label: 'Add manually', onPressed: () => context.push('/add-meal')),
              ),
            ),
          ),
          _Phase.idle => ListView(
            padding: const EdgeInsets.only(bottom: scrollBottomInset),
            children: [
              const ScreenHeader(title: 'Scan', subtitle: 'Photo, estimate, confirm'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FitnessCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 140,
                            child: Stack(
                              children: [
                                const Positioned.fill(child: ScanBrackets(opacity: 0.9)),
                                Center(child: Icon(Icons.restaurant, size: 40, color: AppColors.of(context).brandDeep)),
                              ],
                            ),
                          ),
                          const SizedBox(height: spaceL),
                          Text('Snap. Review. Log.', style: text.headlineSmall),
                          const SizedBox(height: spaceXs),
                          Text('Nothing is saved until you confirm the numbers.', style: text.bodyMedium),
                          const SizedBox(height: spaceL),
                          if (offline)
                            Padding(
                              padding: const EdgeInsets.only(bottom: spaceM),
                              child: Text("You're offline. Connect to scan.", style: text.bodyMedium?.copyWith(color: AppColors.carbs)),
                            ),
                          PrimaryButton(
                            label: 'Take photo',
                            icon: Icons.photo_camera,
                            onPressed: offline ? null : () => _pick(ImageSource.camera),
                          ),
                          const SizedBox(height: spaceM),
                          SecondaryButton(
                            label: 'Choose from gallery',
                            icon: Icons.photo_library,
                            onPressed: offline ? null : () => _pick(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: spaceM),
                    FitnessCard(
                      title: 'How it works',
                      child: Column(
                        children: [
                          for (final (i, step) in const [
                            'Take a clear photo of your plate.',
                            'Review the estimate and correct anything that looks off.',
                            'Confirm to log it. Your rings update right away.',
                          ].indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.brand,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(step, style: text.bodyMedium),
                            ),
                        ],
                      ),
                    ),
                    const EstimateDisclaimer(),
                    TextButton.icon(
                      onPressed: () => context.push('/add-meal'),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Add a meal manually'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
