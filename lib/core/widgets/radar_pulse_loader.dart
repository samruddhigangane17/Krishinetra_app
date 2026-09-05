import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';

/// Animated radar/pulse effect shown while [SoilScanScreen] is running an
/// analysis — three concentric rings sweep outward from a glowing center
/// icon, replacing the plain spinner with something that reads as
/// "actively scanning" rather than just "loading".
///
/// Pure UI/animation — doesn't touch [GeminiAgriService] or any model.
class RadarPulseLoader extends StatefulWidget {
  const RadarPulseLoader({this.label = 'Analyzing your sample…', super.key});

  final String label;

  @override
  State<RadarPulseLoader> createState() => _RadarPulseLoaderState();
}

class _RadarPulseLoaderState extends State<RadarPulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final double delay in const [0.0, 0.33, 0.66])
                      _PulseRing(progress: (_controller.value + delay) % 1.0),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 30),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Gemini AI is reading your soil & crop data…',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});

  /// 0.0 → just spawned at the center, 1.0 → fully expanded & faded out.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double size = 56 + (progress * 84);
    final double opacity = (1 - progress).clamp(0.0, 1.0) * 0.55;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(opacity), width: 2),
      ),
    );
  }
}
