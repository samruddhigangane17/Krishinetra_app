import 'package:flutter/material.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/presentation/pages/language_selection_screen.dart';
import 'package:krishinetra/features/auth/presentation/pages/login_screen.dart';
import 'package:krishinetra/core/services/auth_service.dart';
import 'package:krishinetra/features/dashboard/dashboard_shell.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 34, vertical: compact ? 24 : 38),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                children: [
                  Container(
                    height: compact ? 520 : 500,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(.14), blurRadius: 34, offset: const Offset(0, 16)),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset('assets/farm_hero.png', fit: BoxFit.cover),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [AppColors.primaryDark.withOpacity(.92), AppColors.primaryDark.withOpacity(.48), Colors.transparent],
                              stops: const [0, .48, 1],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(compact ? 28 : 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Image.asset('assets/logo.png', width: 34, height: 34),
                                ),
                                const SizedBox(width: 12),
                                const Text('KrishiNetra', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              ]),
                              const Spacer(),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('See Your Soil.\nGrow Better.', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05)),
                                  const SizedBox(height: 16),
                                  Text(l10n.landingSubtitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(.88), height: 1.45)),
                                  const SizedBox(height: 22),
                                  Wrap(spacing: 10, runSpacing: 10, children: [
                                    _GlassPill(icon: Icons.auto_awesome_rounded, text: 'AI Powered'),
                                    _GlassPill(icon: Icons.eco_rounded, text: 'Better Yields'),
                                    _GlassPill(icon: Icons.verified_rounded, text: 'Smart Insights'),
                                  ]),
                                ]),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 28,
                          top: 28,
                          child: _FloatingBadge(icon: Icons.water_drop_rounded, title: 'Soil Moisture', value: 'Optimal'),
                        ),
                        Positioned(
                          right: compact ? 18 : 60,
                          bottom: 34,
                          child: _FloatingBadge(icon: Icons.spa_rounded, title: 'Crop Health', value: 'Good'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Feature(icon: Icons.science_rounded, text: l10n.featureSoilAnalysis),
                      _Feature(icon: Icons.auto_awesome_rounded, text: l10n.featureAiRecommendations),
                      _Feature(icon: Icons.eco_rounded, text: l10n.featureOrganicAlternatives),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LanguageSelectionScreen(
                              onContinue: (ctx) {
                                Navigator.of(ctx).pushReplacement(MaterialPageRoute(
                                  builder: (loginCtx) => LoginScreen(
                                    onAuthenticated: (user) => Navigator.of(loginCtx).pushReplacement(MaterialPageRoute(builder: (_) => _DashboardStarter(user: user))),
                                  ),
                                ));
                              },
                            ),
                          ));
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(l10n.getStarted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('AI-powered soil intelligence for smarter farming', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.22))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 7), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
  );
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.90), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 6))]),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle), child: Icon(icon, color: AppColors.secondary, size: 18)),
      const SizedBox(width: 9),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary))]),
    ]),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: AppColors.primary),
    label: Text(text),
  );
}

class _DashboardStarter extends StatelessWidget {
  const _DashboardStarter({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) => DashboardShell(
    authUser: user,
    onSignOut: () async {
      // `context` here is DashboardShell's own subtree context (passed
      // down from this widget's own build), so it's still valid at the
      // moment "Sign out" is tapped — unlike a context captured from an
      // ancestor screen that may already have been replaced.
      await authService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    },
  );
}
