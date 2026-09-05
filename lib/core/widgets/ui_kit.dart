import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';

/// Pure presentation-layer color logic for score/health indicators.
///
/// This intentionally lives *outside* the domain models —
/// [GeminiAgriService] and every model in `soil_models.dart` keep their
/// original scoring/status logic untouched. This is purely how the UI
/// paints a given score, following the brief's rule:
///   Green  → score > 75 (healthy)
///   Orange → score 40–74 (moderate)
///   Red    → score < 40, OR a disease/pest was detected
abstract final class KNStatusColor {
  static Color forScore(int score, {bool diseaseDetected = false}) {
    if (diseaseDetected || score < 40) return AppColors.error;
    if (score < 75) return AppColors.warning;
    return AppColors.success;
  }

  /// A richer two-stop gradient keyed to the same rule, for hero cards /
  /// score rings that want depth rather than a flat fill.
  static List<Color> gradientForScore(int score, {bool diseaseDetected = false}) {
    if (diseaseDetected || score < 40) {
      return const [Color(0xFF7A1313), AppColors.error];
    }
    if (score < 75) {
      return const [Color(0xFFB25E00), AppColors.accent];
    }
    return const [AppColors.primaryDark, AppColors.primary];
  }

  static IconData iconForScore(int score, {bool diseaseDetected = false}) {
    if (diseaseDetected || score < 40) return Icons.error_rounded;
    if (score < 75) return Icons.warning_rounded;
    return Icons.check_circle_rounded;
  }

  static String labelForScore(int score, {bool diseaseDetected = false}) {
    if (diseaseDetected || score < 40) return 'Critical';
    if (score < 75) return 'Moderate';
    return 'Healthy';
  }
}

/// Soft, layered shadows shared by every "tile" in the vibrant redesign
/// (stat cards, feature cards, score cards) so depth stays consistent
/// instead of every screen inventing its own blur/opacity values.
abstract final class AppShadows {
  static List<BoxShadow> soft(Color tint) => [
    BoxShadow(color: tint.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 10)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get card => soft(AppColors.primaryDark);
}

/// A reusable rounded-20, soft-gradient, soft-shadow container used for
/// every major dashboard tile in the redesign (stat tiles, feature
/// tiles, list rows) so the "vibrant / color-coded / interactive" look
/// stays consistent across Home, Scan, Results, and History.
class GradientTile extends StatelessWidget {
  const GradientTile({
    required this.child,
    this.colors,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    super.key,
  });

  final Widget child;
  final List<Color>? colors;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    final List<Color> stops = colors ?? [AppColors.surface, AppColors.surfaceVariant.withOpacity(0.7)];
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: stops,
            ),
            border: Border.all(color: borderColor ?? AppColors.outline.withOpacity(0.5)),
            boxShadow: AppShadows.soft(stops.last),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A small pill chip used for nutrient status ("🌱 Optimal" / "⚠️ Low")
/// and other quick, color-coded, tappable indicators.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    this.emoji,
    this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final String? emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
