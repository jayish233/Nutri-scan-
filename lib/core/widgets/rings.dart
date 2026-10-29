import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class _Arc {
  const _Arc(this.progress, this.color);

  final double progress;
  final Color color;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.arcs, this.stroke, this.gap, this.arrow);

  final List<_Arc> arcs;
  final double stroke, gap;
  final bool arrow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < arcs.length; i++) {
      final arc = arcs[i];
      final radius = size.shortestSide / 2 - stroke / 2 - i * (stroke + gap);
      final track = Paint()
        ..color = metricTrack(arc.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawCircle(center, radius, track);
      final p = arc.progress.clamp(0.0, 1.0);
      if (p <= 0) continue;
      final sweep = 2 * math.pi * p;
      final fill = Paint()
        ..color = arc.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, fill);
      if (arrow && p > 0.02) {
        // Ink arrow riding the cap, 52% of the stroke.
        final angle = -math.pi / 2 + sweep;
        final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final s = stroke * 0.52;
        canvas.save();
        canvas.translate(tip.dx, tip.dy);
        canvas.rotate(angle + math.pi / 2);
        final path = Path()
          ..moveTo(-s * 0.35, -s * 0.5)
          ..lineTo(s * 0.25, 0)
          ..lineTo(-s * 0.35, s * 0.5);
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.28
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

/// Track plus a round-capped arc from 12 o'clock; progress is clamped so over target stays full.
class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 132,
    this.stroke = 24,
    this.child,
    this.arrow = true,
  });

  final double progress, size, stroke;
  final Color color;
  final Widget? child;
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    final target = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final reduced = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? target : 0, end: target),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter([_Arc(value, color)], stroke, 0, arrow),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class MiniRingGlyph extends StatelessWidget {
  const MiniRingGlyph({super.key, required this.progress, this.color = AppColors.energy});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: 30, child: CustomPaint(painter: _RingPainter([_Arc(progress, color)], 4, 0, false)));
}
