import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../domain/nutrition.dart';
import '../api/models.dart';

const disclaimerText = 'Nutrition values are AI estimates for personal tracking — not medical advice or diagnoses.';

/// The NutriScan mark (scan frame around an energy ring) on a lime tile. PNG rendered from assets/brand/logo-mark.svg.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/brand/logo-mark.png', width: size, height: size, semanticLabel: 'NutriScan logo');
}

/// "Nutri" in white and "Scan" in lime, Inter heavy, tight tracking.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'NutriScan',
    child: ExcludeSemantics(
      child: Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'Nutri'),
            TextSpan(
              text: 'Scan',
              style: TextStyle(color: AppColors.brand),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.03 * size,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// Faint scan-frame corner brackets, drawn behind the sign-in header.
class ScanBrackets extends StatelessWidget {
  const ScanBrackets({super.key, this.color = AppColors.brand, this.opacity = 0.08});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _BracketPainter(color.withValues(alpha: opacity)),
      size: Size.infinite,
    ),
  );
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final arm = size.shortestSide * 0.14, w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (w, h, -1.0, -1.0), (0.0, h, 1.0, -1.0)]) {
      final p = Path()
        ..moveTo(x, y + dy * arm)
        ..lineTo(x, y)
        ..lineTo(x + dx * arm, y);
      canvas.drawPath(p.shift(Offset(dx * 8, dy * 8)), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

/// Black canvas with soft red, purple and lime glows for sign-in and onboarding.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget glow(Alignment a, Color c, [double alpha = 0.22]) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: a,
            radius: 0.9,
            colors: [
              c.withValues(alpha: alpha),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return ColoredBox(
      color: AppColors.dark.canvas,
      child: Stack(
        children: [
          glow(const Alignment(-1, -0.9), AppColors.energy, 0.16),
          glow(const Alignment(1, -0.3), AppColors.protein, 0.16),
          glow(const Alignment(0, 1.1), AppColors.brand, 0.14),
          child,
        ],
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(spaceL, spaceL, spaceL, spaceM),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // iOS large title 34/800; Android top-bar title 24/600.
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: isCupertino(context) ? Theme.of(context).textTheme.headlineLarge : Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.of(context).secondaryText)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      // Size, pill shape and label style come from the theme (iOS 17/600, Android 16/600).
      child: FilledButton(
        onPressed: enabled ? onPressed : () {},
        child: loading
            ? Semantics(
                label: '$label, in progress',
                child: const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: spaceS)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.frosted = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Translucent white pill for the dark auth screens.
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: frosted ? Colors.white.withValues(alpha: 0.12) : c.cardElevated,
        foregroundColor: frosted ? Colors.white : c.brandDeep,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: spaceS)],
          Text(label),
        ],
      ),
    );
  }
}

/// App text field: iOS shows the label above a filled field, Android an outlined field with the label on the border.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final ios = isCupertino(context);
    final c = AppColors.of(context);
    final field = TextField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      autocorrect: false,
      style: TextStyle(color: c.primaryText, fontSize: 17),
      decoration: InputDecoration(
        labelText: ios ? null : widget.label,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceL, vertical: 16),
        errorText: widget.error,
        errorMaxLines: 3,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off, color: c.secondaryText),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceM),
      child: ios
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: spaceXs, bottom: 6),
                  child: Text(
                    widget.label,
                    style: TextStyle(color: c.secondaryText, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                field,
              ],
            )
          : field,
    );
  }
}

/// AppCard: card colour, radius 22 on iOS and 28 on Android, padding 16, optional title row with a round chevron.
class FitnessCard extends StatelessWidget {
  const FitnessCard({super.key, this.title, this.onTap, required this.child, this.padding = const EdgeInsets.all(spaceL)});

  final String? title;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius(context))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: spaceM),
                  child: Row(
                    children: [
                      Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
                      if (onTap != null)
                        SizedBox.square(
                          dimension: 24,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: c.cardElevated, shape: BoxShape.circle),
                            child: Icon(Icons.chevron_right, size: 18, color: c.secondaryText),
                          ),
                        ),
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple vertical bar chart: used for tile sparklines, the history day chart and weekly charts.
class Bars extends StatelessWidget {
  const Bars({
    super.key,
    required this.values,
    required this.color,
    this.height = 58,
    this.labels,
    this.semanticLabel,
    this.goal,
    this.lastColor,
  });

  final List<double> values;
  final Color color;
  final double height;
  final List<String>? labels;
  final String? semanticLabel;

  /// Draws a dashed goal line at this value.
  final double? goal;

  /// Colour of the last bar (today), e.g. lime on the Progress chart.
  final Color? lastColor;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(goal ?? 0, (a, b) => b > a ? b : a);
    final c = AppColors.of(context);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (i, v) in values.indexed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              height: max == 0 ? 3 : (v / max * height).clamp(3, height),
                              decoration: BoxDecoration(
                                // Empty days show as a small grey stub.
                                color: v <= 0 ? c.cardElevated : (i == values.length - 1 ? lastColor ?? color : color),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (goal != null && max > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: goal! / max * height - 1,
                      child: CustomPaint(size: const Size.fromHeight(2), painter: _DashPainter(c.secondaryText)),
                    ),
                ],
              ),
            ),
            if (labels != null)
              Padding(
                padding: const EdgeInsets.only(top: spaceXs),
                child: Row(
                  children: [
                    // Each label spans an equal group of bars, e.g. 4 labels over 12 two-hour buckets.
                    for (final l in labels!)
                      Expanded(
                        child: Text(
                          l,
                          textAlign: labels!.length == values.length ? TextAlign.center : TextAlign.start,
                          style: TextStyle(fontSize: 10, color: c.secondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
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

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height / 2), Offset((x + 4).clamp(0, size.width), size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

const twoHourLabels = ['12 AM', '6 AM', '12 PM', '6 PM'];

class UnitValue extends StatelessWidget {
  const UnitValue({super.key, required this.value, required this.unit, required this.color, this.size = 22});

  final String value, unit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: value,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: color),
        ),
        TextSpan(
          text: ' ${unit.toUpperCase()}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: color),
        ),
      ],
    ),
  );
}

/// Nutrient tile: name, value in the nutrient colour, "of N g" and a progress bar when there is a target.
class NutrientTile extends StatelessWidget {
  const NutrientTile({super.key, required this.title, required this.value, required this.color, this.target, this.onTap});

  final String title;
  final double value;
  final double? target;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final goal = target;
    return Semantics(
      button: onTap != null,
      label: '$title today, ${formatAmount(value)} grams${goal == null ? '' : ' of ${formatAmount(goal)}'}',
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tileRadius(context))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(spaceL),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: spaceXs),
                  UnitValue(value: formatAmount(value), unit: 'g', color: color),
                  Text(goal == null ? 'Today' : 'of ${formatAmount(goal)} g', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: spaceM),
                  if (goal != null && goal > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: (value / goal).clamp(0, 1),
                        minHeight: 6,
                        color: color,
                        backgroundColor: metricTrack(color),
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

/// Streak pill for the Summary header. Supportive copy only.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) => Semantics(
    label: streakLabel(days),
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: spaceM, vertical: 6),
        decoration: BoxDecoration(color: AppColors.of(context).cardElevated, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 16, color: days > 0 ? AppColors.energy : AppColors.of(context).secondaryText),
            const SizedBox(width: spaceXs),
            Text(streakLabel(days), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.title, this.footer});

  final List<Widget> children;
  final String? title, footer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceL, spaceL, spaceL, spaceS),
            child: Text(title!.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          ),
        Material(
          color: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius(context))),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, indent: spaceL, color: c.hairline), children[i]],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceL, spaceS, spaceL, 0),
            child: Text(footer!, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.title, this.detail, this.trailing, this.onTap, this.leading, this.titleColor});

  final String title;
  final String? detail;
  final Widget? trailing, leading;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    leading: leading,
    title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: titleColor)),
    subtitle: detail == null ? null : Text(detail!, style: Theme.of(context).textTheme.bodySmall),
    trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: AppColors.of(context).secondaryText) : null),
    onTap: onTap,
  );
}

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence});

  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.of(confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spaceM, vertical: 6),
      decoration: BoxDecoration(color: level.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 16, color: level.color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              level.label,
              style: TextStyle(color: level.color, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AllergenWarningBanner extends StatelessWidget {
  const AllergenWarningBanner({super.key, required this.allergens});

  final List<String> allergens;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(spaceL),
    decoration: BoxDecoration(color: AppColors.energy.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(tileRadius(context))),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.energy),
        const SizedBox(width: spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Possible allergens', style: Theme.of(context).textTheme.titleMedium),
              Text(allergens.join(', '), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: spaceXs),
              Text('AI estimate only — always verify if you have allergies.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class EstimateDisclaimer extends StatelessWidget {
  const EstimateDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: spaceL),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: AppColors.of(context).secondaryText),
        const SizedBox(width: spaceS),
        Expanded(child: Text(disclaimerText, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      color: AppColors.carbs,
      padding: const EdgeInsets.symmetric(horizontal: spaceL, vertical: spaceS),
      child: const Text(
        "You're offline. Showing saved data.",
        style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message, this.detail});

  final String? message, detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.brand),
          if (message != null) ...[
            const SizedBox(height: spaceL),
            Text(message!, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          ],
          if (detail != null) Text(detail!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(spaceL),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppColors.of(context).secondaryText),
        const SizedBox(height: spaceS),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        if (actionLabel != null) ...[const SizedBox(height: spaceL), PrimaryButton(label: actionLabel!, onPressed: onAction)],
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.extra});

  final String message;
  final VoidCallback? onRetry;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(spaceXl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.carbs),
        const SizedBox(height: spaceM),
        Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: spaceXs),
        Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        if (onRetry != null) ...[const SizedBox(height: spaceL), PrimaryButton(label: 'Try again', onPressed: onRetry)],
        if (extra != null) ...[const SizedBox(height: spaceM), extra!],
      ],
    ),
  );
}

class MealThumb extends StatelessWidget {
  const MealThumb({super.key, required this.meal, this.size = 48});

  final Meal meal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.brand.withValues(alpha: 0.18),
      child: Icon(Icons.restaurant, color: AppColors.of(context).brandDeep, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusSmall),
      child: meal.imageUrl == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: meal.imageUrl!,
              // Keyed by meal id so the changing signed URL does not defeat the cache.
              cacheKey: 'meal-${meal.id}',
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class MealRow extends StatelessWidget {
  const MealRow({super.key, required this.meal, this.onTap});

  final Meal meal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = MealType.fromWire(meal.mealType).label;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 64,
      onTap: onTap,
      leading: MealThumb(meal: meal),
      title: Text(meal.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$type · ${formatAmount(meal.nutrition.calories)} kcal', style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(
        '${formatAmount(meal.nutrition.protein)}g P',
        style: const TextStyle(color: AppColors.protein, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String friendlyDate(DateTime d) => DateFormat('EEEE, MMM d').format(d);
