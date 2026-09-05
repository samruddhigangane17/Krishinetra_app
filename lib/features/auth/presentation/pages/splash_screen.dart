import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const Duration _holdDuration = Duration(milliseconds: 2500);
  static const Duration _fadeInDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _fadeInDuration);

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(_holdDuration, () {
      if (!mounted) return;
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                          ),
                          child: const Icon(Icons.eco_rounded, size: 50, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Text(
                        'KrishiNetra',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Padding(
                        // Regional-language taglines (e.g. Kannada, Telugu)
                        // run noticeably longer than the English source
                        // string — constrain width and allow a 2nd line
                        // instead of a single fixed-width line, so longer
                        // translations wrap instead of overflowing.
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: Text(
                          AppLocalizations.of(context).splashTagline,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
