import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:krishinetra/core/services/auth_service.dart';
import 'package:krishinetra/core/services/language_manager.dart';
import 'package:krishinetra/core/services/report_history_store.dart';
import 'package:krishinetra/core/services/weather_service.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/chatbot/presentation/pages/chatbot_screen.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';
import 'package:krishinetra/features/recommendation/presentation/pages/recommendation_report_screen.dart';
import 'package:krishinetra/features/recommendation/presentation/pages/soil_scan_screen.dart';
import 'package:krishinetra/features/schemes/presentation/pages/schemes_screen.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({required this.authUser, required this.onSignOut, super.key});
  final AuthUser authUser;
  final VoidCallback onSignOut;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  static const _icons = <IconData>[
    Icons.dashboard_rounded,
    Icons.center_focus_strong_rounded,
    Icons.analytics_rounded,
    Icons.account_balance_rounded,
    Icons.smart_toy_rounded,
    Icons.history_rounded,
    Icons.auto_awesome_rounded,
    Icons.wb_sunny_rounded,
    Icons.person_rounded,
  ];
  static const _outlined = <IconData>[
    Icons.dashboard_outlined,
    Icons.center_focus_strong_outlined,
    Icons.analytics_outlined,
    Icons.account_balance_outlined,
    Icons.smart_toy_outlined,
    Icons.history_outlined,
    Icons.auto_awesome_outlined,
    Icons.wb_sunny_outlined,
    Icons.person_outline_rounded,
  ];

  String _name(AppLocalizations l10n) {
    final display = widget.authUser.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    if (widget.authUser.isGuest) return l10n.guestFarmerName;
    return l10n.farmerNameFallback;
  }

  void _select(int value) => setState(() => index = value);

  Widget _page(LanguageOption language, AppLocalizations l10n) {
    switch (index) {
      case 1:
        return SoilScanScreen(language: language);
      case 2:
        return _Results(language: language);
      case 3:
        return const SchemesScreen();
      case 4:
        return ChatbotScreen(language: language);
      case 5:
        return _History(language: language);
      case 6:
        return _Recommendations(language: language);
      case 7:
        return const _Weather();
      case 8:
        return _Profile(
          user: widget.authUser,
          onSignOut: widget.onSignOut,
          currentLanguage: language,
          onLanguageChanged: languageManager.setLanguage,
        );
      default:
        return _Home(
          userName: _name(l10n),
          onScan: () => _select(1),
          onHistory: () => _select(5),
          onResults: () => _select(2),
          onSchemes: () => _select(3),
          onAssistant: () => _select(4),
          onPlan: () => _select(6),
          onWeather: () => _select(7),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 980;
    final l10n = AppLocalizations.of(context);
    final labels = <String>[
      l10n.navHome,
      l10n.navScan,
      'Results',
      l10n.navSchemes,
      l10n.navChat,
      l10n.navHistory,
      'AI Farming Plan',
      'Weather',
      l10n.navProfile,
    ];

    return ValueListenableBuilder<LanguageOption>(
      valueListenable: languageManager.selected,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: wide
              ? null
              : AppBar(
                  backgroundColor: AppColors.background,
                  title: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w800)),
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.language_rounded),
                      onPressed: () => _select(8),
                    ),
                  ],
                ),
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _NavigationContent(
                      selected: index,
                      labels: labels,
                      icons: _icons,
                      outlined: _outlined,
                      onSelected: (value) {
                        Navigator.pop(context);
                        _select(value);
                      },
                      onScan: () {
                        Navigator.pop(context);
                        _select(1);
                      },
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (wide)
                SizedBox(
                  width: 252,
                  child: _NavigationContent(
                    selected: index,
                    labels: labels,
                    icons: _icons,
                    outlined: _outlined,
                    onSelected: _select,
                    onScan: () => _select(1),
                    onSignOut: widget.onSignOut,
                  ),
                ),
              Expanded(
                child: SafeArea(
                  top: wide,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(key: ValueKey(index), child: _page(language, l10n)),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: [0, 1, 4, 5, 8].contains(index) ? [0, 1, 4, 5, 8].indexOf(index) : 0,
                  onDestinationSelected: (i) => _select(const [0, 1, 4, 5, 8][i]),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.center_focus_strong_outlined), selectedIcon: Icon(Icons.center_focus_strong_rounded), label: 'Scan'),
                    NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy_rounded), label: 'AI'),
                    NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
                    NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
                  ],
                ),
        );
      },
    );
  }
}

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({
    required this.selected,
    required this.labels,
    required this.icons,
    required this.outlined,
    required this.onSelected,
    required this.onScan,
    required this.onSignOut,
  });

  final int selected;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> outlined;
  final ValueChanged<int> onSelected;
  final VoidCallback onScan;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(right: BorderSide(color: Color(0x2250A96E))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KrishiNetra', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('See Your Soil. Grow Better.', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Scan Soil Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryLight,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 3),
              itemBuilder: (_, i) {
                final active = selected == i;
                return _NavTile(
                  active: active,
                  icon: active ? icons[i] : outlined[i],
                  label: labels[i],
                  onTap: () => onSelected(i),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _SidePromo(onTap: onScan),
          ),
          const Divider(height: 1, color: Color(0x2267A47E)),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            title: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.active, required this.icon, required this.label, required this.onTap});
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFB8F2C5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primaryDark : Colors.white70, size: 20),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: TextStyle(color: active ? AppColors.primaryDark : Colors.white70, fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600))),
            if (active) const Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 17),
          ],
        ),
      ),
    );
  }
}

class _SidePromo extends StatelessWidget {
  const _SidePromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF075B31), Color(0xFF00351E)]),
          border: Border.all(color: const Color(0x447BCB91)),
        ),
        child: Stack(
          children: [
            Positioned(right: -22, bottom: -28, child: Image.asset('assets/farm_hero.png', width: 170, height: 130, fit: BoxFit.cover)),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan. Understand.\nImprove. Grow.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
                SizedBox(height: 8),
                Text('Make data-driven decisions for healthier crops.', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
              ]),
            ),
            Positioned(left: 14, bottom: 13, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(11)), child: const Text('Scan Soil Now  →', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 11)))),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child, this.title, this.subtitle, this.action});
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title!, style: Theme.of(context).textTheme.headlineMedium), if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)] ])),
                    if (action != null) ...[const SizedBox(width: 18), action!],
                  ],
                ),
              if (title != null) const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.userName, required this.onScan, required this.onHistory, required this.onResults, required this.onSchemes, required this.onAssistant, required this.onPlan, required this.onWeather});
  final String userName;
  final VoidCallback onScan, onHistory, onResults, onSchemes, onAssistant, onPlan, onWeather;

  @override
  Widget build(BuildContext context) {
    final reports = reportHistoryStore.reports;
    final latest = reports.isEmpty ? null : reports.first;
    final score = latest?.healthScore;
    final crop = latest?.recommendedCrop ?? 'Add your first scan';
    final pH = latest?.inputs.effectivePh.toStringAsFixed(1) ?? '--';
    final status = latest?.status.label ?? 'Ready to scan';
    final width = MediaQuery.sizeOf(context).width;

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeader(userName: userName, onProfile: () {}),
          const SizedBox(height: 18),
          _HomeHero(onScan: onScan, score: score),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, constraints) {
              final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
              final cards = <Widget>[
                _StatCard(icon: Icons.eco_rounded, label: 'Soil Health Score', value: score == null ? '—' : '$score/100', note: status, onTap: onResults),
                _StatCard(icon: Icons.science_rounded, label: 'Latest pH', value: pH, note: latest == null ? 'No soil data yet' : 'Current soil reading', onTap: onResults),
                _StatCard(icon: Icons.grass_rounded, label: 'Recommended Crop', value: crop, note: latest == null ? 'AI suggestion after scan' : 'High suitability', onTap: onPlan),
                _WeatherStatCard(onTap: onWeather),
              ];
              return _ResponsiveGrid(columns: columns, children: cards);
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, constraints) {
              final wide = constraints.maxWidth >= 930;
              final activity = Column(children: [
                _SectionCard(
                  title: 'Recent Scans',
                  trailing: TextButton(onPressed: onHistory, child: const Text('View all')),
                  child: _RecentScans(reports: reports, onHistory: onHistory),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'AI Recommendation',
                  trailing: _NewPill(),
                  child: _RecommendationPreview(report: latest, onTap: onPlan),
                ),
              ]);
              final tools = Column(children: [
                _HomeWeather(onTap: onWeather),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Quick Actions',
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: width < 1100 ? 1.55 : 1.7,
                    children: [
                      _QuickAction(icon: Icons.camera_alt_rounded, label: 'Scan Soil', tone: const Color(0xFFDFF8E5), onTap: onScan),
                      _QuickAction(icon: Icons.auto_awesome_rounded, label: 'AI Plan', tone: const Color(0xFFEDE7FF), onTap: onPlan),
                      _QuickAction(icon: Icons.smart_toy_rounded, label: 'AI Assistant', tone: const Color(0xFFF1E4FF), onTap: onAssistant),
                      _QuickAction(icon: Icons.account_balance_rounded, label: 'Schemes', tone: const Color(0xFFFFEEDB), onTap: onSchemes),
                    ],
                  ),
                ),
              ]);
              if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: activity), const SizedBox(width: 16), Expanded(flex: 2, child: tools)]);
              return Column(children: [activity, const SizedBox(height: 16), tools]);
            },
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Government Schemes for You',
            trailing: TextButton.icon(onPressed: onSchemes, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('View all schemes')),
            child: LayoutBuilder(builder: (_, c) {
              final columns = c.maxWidth >= 950 ? 4 : c.maxWidth >= 650 ? 2 : 1;
              return _ResponsiveGrid(columns: columns, children: [
                _SchemeCard(icon: Icons.volunteer_activism_rounded, title: 'PM-KISAN', subtitle: 'Financial support to farmers', accent: const Color(0xFFE8F8E8), onTap: onSchemes),
                _SchemeCard(icon: Icons.health_and_safety_rounded, title: 'Soil Health Card', subtitle: 'Know your soil better', accent: const Color(0xFFE5F5F0), onTap: onSchemes),
                _SchemeCard(icon: Icons.shield_rounded, title: 'PMFBY Insurance', subtitle: 'Crop protection for every season', accent: const Color(0xFFFFF0DD), onTap: onSchemes),
                _SchemeCard(icon: Icons.credit_card_rounded, title: 'KCC Scheme', subtitle: 'Easy agricultural credit', accent: const Color(0xFFE8EEFF), onTap: onSchemes),
              ]);
            }),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName, required this.onProfile});
  final String userName;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good Morning, $userName! 🌱', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -.4)),
            const SizedBox(height: 3),
            const Text("Let's make your farm more productive today.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
        if (MediaQuery.sizeOf(context).width >= 760) ...[
          Container(width: 230, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineVariant.withOpacity(.5))), child: const TextField(decoration: InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.search_rounded, size: 20), hintText: 'Search anything...', contentPadding: EdgeInsets.symmetric(vertical: 11)))),
          const SizedBox(width: 10),
        ],
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        const SizedBox(width: 4),
        InkWell(onTap: onProfile, borderRadius: BorderRadius.circular(20), child: const CircleAvatar(radius: 19, backgroundColor: AppColors.surfaceContainerHigh, child: Icon(Icons.person_rounded, color: AppColors.primary))),
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onScan, this.score});
  final VoidCallback onScan;
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 278,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.13), blurRadius: 28, offset: const Offset(0, 10))]),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/farm_hero.png', fit: BoxFit.cover),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [AppColors.primaryDark.withOpacity(.88), AppColors.primary.withOpacity(.55), Colors.transparent]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 28, 24, 24),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Smart Farming Begins\nwith Healthy Soil', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -.6)),
              const SizedBox(height: 12),
              const Text('AI-powered insights to analyze soil, get recommendations, and improve your crop yield sustainably.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onScan, icon: const Icon(Icons.camera_alt_rounded, size: 17), label: const Text('Scan New Soil'), style: FilledButton.styleFrom(backgroundColor: AppColors.secondaryLight, foregroundColor: AppColors.primaryDark, minimumSize: const Size(154, 44))),
            ])),
            if (MediaQuery.sizeOf(context).width >= 900) ...[
              const SizedBox(width: 16),
              _ScoreBadge(score: score),
            ],
          ]),
        ),
        Positioned(bottom: 13, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < 4; i++) Container(width: i == 0 ? 22 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(i == 0 ? .95 : .6), borderRadius: BorderRadius.circular(8)))])),
      ]),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({this.score});
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      height: 154,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 7))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Soil Health Score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(height: 7),
        Text(score == null ? '—' : '$score', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1)),
        const Text('/100', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20)), child: const Text('Good condition', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondary))),
      ]),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final itemWidth = columns <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.note, required this.onTap});
  final IconData icon;
  final String label, value, note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: AppColors.secondary, size: 25)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.w700))])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.outline, size: 19),
      ]),
    );
  }
}

class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, required this.onTap, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;
  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: hovering ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: hovering ? AppColors.secondaryLight : AppColors.outlineVariant.withOpacity(.45)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(hovering ? .055 : .025), blurRadius: hovering ? 20 : 12, offset: const Offset(0, 7))]),
        child: Material(color: Colors.transparent, child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: widget.padding, child: widget.child))),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outlineVariant.withOpacity(.4)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 16, offset: const Offset(0, 7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), if (trailing != null) trailing!]), const SizedBox(height: 12), child]),
    );
  }
}

class _RecentScans extends StatelessWidget {
  const _RecentScans({required this.reports, required this.onHistory});
  final List<SoilHealthAssessment> reports;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return InkWell(onTap: onHistory, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.camera_alt_rounded, color: AppColors.secondary), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No scans yet', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Run your first soil scan to see field insights here.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))])), Icon(Icons.arrow_forward_rounded, color: AppColors.secondary)])));
    }
    final visible = reports.take(3).toList();
    return Column(children: [for (var i = 0; i < visible.length; i++) _ScanRow(report: visible[i], onTap: onHistory, showDivider: i != visible.length - 1)]);
  }
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.report, required this.onTap, required this.showDivider});
  final SoilHealthAssessment report;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final crop = report.inputs.selectedCrop?.trim().isNotEmpty == true ? report.inputs.selectedCrop! : report.recommendedCrop;
    final date = DateFormat('d MMM yyyy • hh:mm a').format(report.generatedAt);
    return Column(children: [
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(width: 46, height: 46, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: report.inputs.hasImage ? Image.memory(report.inputs.imageBytes!, fit: BoxFit.cover) : const Icon(Icons.grass_rounded, color: AppColors.secondary)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(crop, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text(date, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: report.status.color.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Text('${report.healthScore}', style: TextStyle(fontWeight: FontWeight.w900, color: report.status.color, fontSize: 12))),
        const SizedBox(width: 5),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.outline),
      ]))),
      if (showDivider) const Divider(height: 1, indent: 57),
    ]);
  }
}

class _RecommendationPreview extends StatelessWidget {
  const _RecommendationPreview({required this.report, required this.onTap});
  final SoilHealthAssessment? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = report == null ? 'Scan your soil to unlock personalized AI recommendations.' : (report!.agronomistSummary.isNotEmpty ? report!.agronomistSummary : 'Keep your soil balanced with regular monitoring and targeted nutrition.');
    final items = report == null ? const ['Run a soil scan', 'Review crop suitability', 'Plan nutrient inputs'] : <String>[
      if (report!.organicAlternatives.isNotEmpty) 'Consider organic alternatives where suitable',
      if (report!.fertilizerDoses.isNotEmpty) 'Follow the recommended fertilizer schedule',
      'Monitor soil moisture and nutrient balance',
    ];
    return Column(children: [
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE9F9EC), Color(0xFFF7F6E9)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.eco_rounded, color: AppColors.secondary, size: 28)), const SizedBox(width: 12), Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w600))), const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary, size: 20)])),
      const SizedBox(height: 8),
      for (final item in items) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Container(width: 25, height: 25, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: AppColors.secondary, size: 15)), const SizedBox(width: 9), Expanded(child: Text(item, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.outline)])),
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onTap, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('Open full AI plan'))),
    ]);
  }
}

class _NewPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(20)), child: const Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primaryDark)));
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.tone, required this.onTap});
  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(15)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(.8), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 20)), const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))])));
}

class _WeatherStatCard extends StatefulWidget {
  const _WeatherStatCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_WeatherStatCard> createState() => _WeatherStatCardState();
}

class _WeatherStatCardState extends State<_WeatherStatCard> {
  @override
  void initState() {
    super.initState();
    if (weatherService.snapshot == null && !weatherService.isLoading) {
      weatherService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: weatherService,
      builder: (context, _) {
        final WeatherSnapshot? snapshot = weatherService.snapshot;
        if (snapshot == null) {
          return _StatCard(
            icon: Icons.wb_sunny_rounded,
            label: 'Weather Today',
            value: weatherService.isLoading ? '…' : '—',
            note: weatherService.error ?? 'Fetching forecast…',
            onTap: widget.onTap,
          );
        }
        return _StatCard(
          icon: Icons.wb_sunny_rounded,
          label: 'Weather Today',
          value: '${snapshot.currentTempC.round()}°C',
          note: '${snapshot.currentCondition} · ${snapshot.currentHumidityPercent}%',
          onTap: widget.onTap,
        );
      },
    );
  }
}

class _HomeWeather extends StatefulWidget {
  const _HomeWeather({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HomeWeather> createState() => _HomeWeatherState();
}

class _HomeWeatherState extends State<_HomeWeather> {
  @override
  void initState() {
    super.initState();
    if (weatherService.snapshot == null && !weatherService.isLoading) {
      weatherService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: weatherService,
      builder: (context, _) {
        final WeatherSnapshot? snapshot = weatherService.snapshot;

        Widget body;
        if (snapshot == null && weatherService.isLoading) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        } else if (snapshot == null) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weatherService.error ?? 'Weather unavailable right now.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => weatherService.refresh(),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(snapshot.locationLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                Text('${snapshot.currentEmoji}  ${snapshot.currentTempC.round()}°C', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.currentCondition, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      if (snapshot.tomorrow != null)
                        Text(
                          '${snapshot.tomorrow!.precipitationProbabilityPercent}% rain chance tomorrow',
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _WeatherMetric(icon: Icons.water_drop_rounded, label: 'Humidity', value: '${snapshot.currentHumidityPercent}%')),
                Expanded(child: _WeatherMetric(icon: Icons.air_rounded, label: 'Wind', value: '${snapshot.currentWindKph.round()} km/h')),
                Expanded(
                  child: _WeatherMetric(
                    icon: Icons.umbrella_rounded,
                    label: 'Rain',
                    value: '${snapshot.today?.precipitationProbabilityPercent ?? 0}%',
                  ),
                ),
              ]),
            ],
          );
        }

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEAF8ED), Color(0xFFF8F3DF)]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.wb_sunny_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Weather Today', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ]),
                body,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.icon, required this.label, required this.value});
  final IconData icon; final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 14, color: AppColors.secondary), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]);
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});
  final IconData icon; final String title, subtitle; final Color accent; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
              ),
              const Spacer(),
              const Text(
                'Apply Now  →',
                style: TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
}

class _Results extends StatelessWidget {
  const _Results({required this.language});
  final LanguageOption language;
  @override
  Widget build(BuildContext context) {
    final report = reportHistoryStore.reports.isEmpty ? null : reportHistoryStore.reports.first;
    return _PageFrame(title: 'Soil Results', subtitle: 'Your latest soil health assessment and key insights.', child: report == null ? _EmptyState(title: 'No soil report yet', message: 'Run a soil scan to generate your first report.', icon: Icons.analytics_rounded) : RecommendationReportScreen(assessment: report, language: language));
  }
}

class _History extends StatelessWidget {
  const _History({required this.language});
  final LanguageOption language;
  @override
  Widget build(BuildContext context) {
    final reports = reportHistoryStore.reports;
    final trend = reportHistoryStore.trendSnapshots;
    if (reports.isEmpty && trend.isEmpty) {
      return _PageFrame(title: 'Scan History', subtitle: 'Review your previous soil and crop analyses.', child: _EmptyState(title: 'Your history is empty', message: 'Your completed scans will appear here.', icon: Icons.history_rounded));
    }
    return _PageFrame(
      title: 'Scan History',
      subtitle: 'Review your previous soil and crop analyses.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trend.length >= 2) ...[
            _HealthScoreTrendCard(snapshots: trend),
            const SizedBox(height: 16),
          ],
          if (reports.isEmpty)
            const Text(
              'Full report write-ups are kept for this app session only — the '
              'trend above is saved permanently, but reopening older reports '
              'in detail needs a fresh scan after an app restart.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          else
            ...reports.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryCard(report: r, language: language),
                )),
        ],
      ),
    );
  }
}

class _HealthScoreTrendCard extends StatelessWidget {
  const _HealthScoreTrendCard({required this.snapshots});

  /// Newest first, as stored by [SoilReportHistoryStore.trendSnapshots].
  final List<SoilSnapshotRecord> snapshots;

  @override
  Widget build(BuildContext context) {
    final List<SoilSnapshotRecord> chronological = snapshots.reversed.toList();
    final List<SoilSnapshotRecord> recent =
        chronological.length > 10 ? chronological.sublist(chronological.length - 10) : chronological;

    return _SectionCard(
      title: 'Soil Health Score Trend',
      child: SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final record in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${record.healthScore}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Container(
                        height: (record.healthScore.clamp(4, 100) / 100) * 80,
                        decoration: BoxDecoration(
                          color: record.status.color,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat('d MMM').format(record.timestamp), style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.report, required this.language});
  final SoilHealthAssessment report;
  final LanguageOption language;
  @override
  Widget build(BuildContext context) => _HoverCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Soil Report')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RecommendationReportScreen(assessment: report, language: language),
              ),
            ),
          ),
        ),
        child: Row(children: [Container(width: 58, height: 58, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(15)), child: report.inputs.hasImage ? Image.memory(report.inputs.imageBytes!, fit: BoxFit.cover) : const Icon(Icons.grass_rounded, color: AppColors.secondary, size: 27)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(report.recommendedCrop, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(DateFormat('d MMM yyyy, hh:mm a').format(report.generatedAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 4), Text(report.status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: report.status.color))])), Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), decoration: BoxDecoration(color: report.status.color.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text('${report.healthScore}/100', style: TextStyle(color: report.status.color, fontWeight: FontWeight.w900))), const Icon(Icons.chevron_right_rounded)]),
      );
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.language});
  final LanguageOption language;
  @override
  Widget build(BuildContext context) {
    final report = reportHistoryStore.reports.isEmpty ? null : reportHistoryStore.reports.first;
    if (report == null) return const _PageFrame(title: 'AI Farming Plan', subtitle: 'Personalized recommendations for your field.', child: _EmptyState(title: 'Scan first, plan smarter', message: 'Your AI farming plan will be generated from your soil report.', icon: Icons.auto_awesome_rounded));
    return _PageFrame(title: 'AI Farming Plan', subtitle: 'Personalized actions based on your latest soil report.', child: RecommendationReportScreen(assessment: report, language: language));
  }
}

class _Weather extends StatefulWidget {
  const _Weather();

  @override
  State<_Weather> createState() => _WeatherState();
}

class _WeatherState extends State<_Weather> {
  @override
  void initState() {
    super.initState();
    if (weatherService.snapshot == null && !weatherService.isLoading) {
      weatherService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Weather',
      subtitle: 'Use weather conditions to plan irrigation and field work.',
      child: AnimatedBuilder(
        animation: weatherService,
        builder: (context, _) {
          final WeatherSnapshot? snapshot = weatherService.snapshot;

          if (snapshot == null && weatherService.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot == null) {
            return _EmptyState(
              title: 'Weather unavailable',
              message: weatherService.error ?? 'Could not load weather right now.',
              icon: Icons.cloud_off_rounded,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeWeather(onTap: () => weatherService.refresh()),
              const SizedBox(height: 16),
              _SectionCard(
                title: '3-Day Forecast',
                child: Row(
                  children: [
                    for (final day in snapshot.daily)
                      Expanded(
                        child: Column(
                          children: [
                            Text(DateFormat('EEE').format(day.date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(day.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 6),
                            Text('${day.tempMaxC.round()}° / ${day.tempMinC.round()}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('${day.precipitationProbabilityPercent}% rain', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionCard(
                title: 'About this forecast',
                child: Text(
                  'Weather is fetched for your device\'s current location using Open-Meteo, a '
                  'free forecast service — no account or API key needed. If the location looks '
                  'wrong, check that location access is allowed for this app/browser.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.user, required this.onSignOut, required this.currentLanguage, required this.onLanguageChanged});
  final AuthUser user;
  final VoidCallback onSignOut;
  final LanguageOption currentLanguage;
  final ValueChanged<LanguageOption> onLanguageChanged;
  @override
  Widget build(BuildContext context) => _PageFrame(title: 'Profile & Settings', subtitle: 'Manage your farmer profile and app preferences.', child: Column(children: [_SectionCard(title: 'Farmer Profile', child: ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(radius: 26, backgroundColor: AppColors.surfaceContainerLow, child: Icon(Icons.person_rounded, color: AppColors.primary)), title: Text(user.displayName ?? 'Farmer', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(user.isGuest ? 'Offline Guest Mode' : (user.phoneNumber ?? 'Signed in')), trailing: FilledButton(onPressed: onSignOut, child: const Text('Sign out')))), const SizedBox(height: 16), _SectionCard(title: 'Language', child: DropdownButtonFormField<LanguageOption>(initialValue: currentLanguage, decoration: const InputDecoration(prefixIcon: Icon(Icons.language_rounded), labelText: 'App language'), items: LanguageOption.supported.map((l) => DropdownMenuItem(value: l, child: Text(l.nativeName))).toList(), onChanged: (value) { if (value != null) onLanguageChanged(value); }))]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message, required this.icon});
  final String title, message; final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outlineVariant.withOpacity(.4))), child: Column(children: [Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle), child: Icon(icon, color: AppColors.secondary, size: 30)), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))]));
}
