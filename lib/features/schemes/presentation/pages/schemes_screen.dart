import 'package:flutter/material.dart';

import 'package:krishinetra/core/services/report_history_store.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';
import 'package:krishinetra/features/schemes/data/scheme_repository.dart';
import 'package:krishinetra/features/schemes/domain/models/scheme.dart';
import 'package:krishinetra/features/schemes/domain/scheme_match_engine.dart';
import 'package:krishinetra/features/schemes/presentation/widgets/recommended_scheme_card.dart';
import 'package:krishinetra/features/schemes/presentation/widgets/scheme_filter_bar.dart';
import 'package:krishinetra/features/schemes/presentation/widgets/scheme_list_card.dart';

/// Intelligent, searchable scheme matching screen — replaces the old
/// static 8-scheme reference list with the full 100-scheme dataset
/// (`assets/agriculture_schemes.json`), a search + category/government
/// filter bar, and a "Recommended For You" section driven by the
/// farmer's latest soil diagnostic report (see
/// `scheme_match_engine.dart` for the matching logic itself).
///
/// Reads [reportHistoryStore] directly (same pattern as the dashboard's
/// other report-driven tabs) rather than requiring a report to be passed
/// in — this screen works standalone whether or not a scan has been run
/// yet; it just has less to personalize without one.
class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  late Future<List<Scheme>> _schemesFuture;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedGovernment;

  /// How many of the filtered "All Schemes" results to render — grows via
  /// the "Show more" button rather than rendering all ~100 cards eagerly.
  int _visibleCount = 12;

  @override
  void initState() {
    super.initState();
    _schemesFuture = schemeRepository.loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Scheme> _applyFilters(List<Scheme> schemes) {
    final String query = _searchQuery.trim().toLowerCase();
    return schemes.where((s) {
      if (_selectedCategory != null && s.category != _selectedCategory) return false;
      if (_selectedGovernment != null && s.government != _selectedGovernment) return false;
      if (query.isNotEmpty && !s.searchHaystack.contains(query)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final SoilHealthAssessment? report =
        reportHistoryStore.reports.isEmpty ? null : reportHistoryStore.reports.first;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 720;
          return FutureBuilder<List<Scheme>>(
            future: _schemesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text('Could not load scheme data: ${snapshot.error}'),
                  ),
                );
              }

              final List<Scheme> allSchemes = snapshot.data!;
              final List<SchemeMatch> recommended =
                  report == null ? const [] : matchSchemesToReport(schemes: allSchemes, report: report);
              final List<Scheme> filtered = _applyFilters(allSchemes);
              final List<Scheme> visible = filtered.take(_visibleCount).toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(compact ? 16 : 32, 24, compact ? 16 : 32, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(compact: compact, schemeCount: allSchemes.length),
                        const SizedBox(height: 22),

                        if (report == null)
                          _NoReportBanner()
                        else
                          _ReportContextBanner(report: report),
                        const SizedBox(height: 22),

                        if (report != null) ...[
                          Text('Recommended For You', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Based on your latest soil report — health score ${report.healthScore}/100.',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (recommended.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outlineVariant.withOpacity(.6)),
                              ),
                              child: const Text(
                                'No specific scheme matches your current soil report beyond the general '
                                'list below — that\'s not unusual if your readings are already close to '
                                'the ideal range.',
                                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                              ),
                            )
                          else
                            SizedBox(
                              height: 210,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recommended.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, i) => RecommendedSchemeCard(match: recommended[i]),
                              ),
                            ),
                          const SizedBox(height: 28),
                        ],

                        Text('Browse All Schemes', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} of ${allSchemes.length} schemes match your filters.',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),

                        SchemeFilterBar(
                          searchController: _searchController,
                          onSearchChanged: (value) => setState(() {
                            _searchQuery = value;
                            _visibleCount = 12;
                          }),
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: (value) => setState(() {
                            _selectedCategory = value;
                            _visibleCount = 12;
                          }),
                          selectedGovernment: _selectedGovernment,
                          onGovernmentChanged: (value) => setState(() {
                            _selectedGovernment = value;
                            _visibleCount = 12;
                          }),
                        ),
                        const SizedBox(height: 18),

                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 40, color: AppColors.outline),
                                  const SizedBox(height: 10),
                                  Text('No schemes match your filters', style: textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  const Text('Try a different keyword or clear a filter.', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(builder: (context, grid) {
                            final int columns = grid.maxWidth >= 1000 ? 3 : grid.maxWidth >= 650 ? 2 : 1;
                            const double gap = 14;
                            final double cardWidth = (grid.maxWidth - gap * (columns - 1)) / columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final Scheme scheme in visible)
                                  SizedBox(width: cardWidth, child: SchemeListCard(scheme: scheme)),
                              ],
                            );
                          }),

                        if (_visibleCount < filtered.length) ...[
                          const SizedBox(height: 18),
                          Center(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _visibleCount += 15),
                              child: Text('Show more (${filtered.length - _visibleCount} left)'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact, required this.schemeCount});
  final bool compact;
  final int schemeCount;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Government schemes', style: textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Search $schemeCount Maharashtra farmer-support schemes, or see the ones matched to your soil report.',
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.secondaryLight.withOpacity(.28), borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 7),
              Text('Farmer support', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
        ],
      ],
    );
  }
}

class _NoReportBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.outlineVariant.withOpacity(.7))),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Run a soil scan to unlock a "Recommended For You" section — schemes matched to your '
              'actual health score, NPK/pH readings, and organic-input use, with the reasoning explained.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContextBanner extends StatelessWidget {
  const _ReportContextBanner({required this.report});
  final SoilHealthAssessment report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: report.status.color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: report.status.color.withOpacity(.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: report.status.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Personalizing using your latest scan: ${report.healthScore}/100 (${report.status.label}) · '
              '${report.recommendedCrop} · organic inputs: '
              '${report.inputs.usesOrganicInputs == null ? 'not specified' : report.inputs.usesOrganicInputs! ? 'yes' : 'no'}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
