import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';

/// KrishiNetra's branded header — an [Image.asset] logo (with a graceful
/// gradient + [Icons.eco_rounded] fallback if `assets/logo.png` isn't
/// present) paired with the wordmark. Used everywhere a screen previously
/// showed a plain text title, so the brand is visually anchored across
/// Home, Scan, Results, and History.
///
/// Two layouts:
///  * [compact] — a small horizontal lockup (logo + "KrishiNetra"),
///    sized to drop straight into an [AppBar] title slot.
///  * default — a larger header with an optional [subtitle] line, meant
///    to sit at the top of a scrollable page body.
class BrandedLogoHeader extends StatelessWidget {
  const BrandedLogoHeader({
    this.subtitle,
    this.compact = false,
    this.trailing,
    this.logoSize,
    super.key,
  });

  /// Optional line shown under the "KrishiNetra" wordmark (ignored when
  /// [compact] is true — there's no room for it in an AppBar).
  final String? subtitle;

  /// Use the small AppBar-friendly lockup instead of the full header.
  final bool compact;

  /// Optional trailing widget (e.g. an avatar or icon button) shown at
  /// the end of the row in the non-compact layout.
  final Widget? trailing;

  /// Override the logo's diameter. Defaults to 32 (compact) or 46 (full).
  final double? logoSize;

  @override
  Widget build(BuildContext context) {
    final double size = logoSize ?? (compact ? 32 : 46);
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
            ),
          ),
          child: Icon(Icons.eco_rounded, color: Colors.white, size: size * 0.58),
        ),
      ),
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(width: AppSpacing.sm),
          Text(
            'KrishiNetra',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logo,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KrishiNetra',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
