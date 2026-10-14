import 'dart:math' show cos, pi, sin;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/core/services/report_history_store.dart';
import 'package:krishinetra/core/services/translation_service.dart';
import 'package:krishinetra/core/services/tts_service.dart';
import 'package:krishinetra/core/services/weather_advisory_engine.dart';
import 'package:krishinetra/core/services/weather_service.dart';
import 'package:krishinetra/core/widgets/branded_logo_header.dart';
import 'package:krishinetra/core/widgets/ui_kit.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/recommendation/data/gemini_service.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';

/// Full soil analysis report — the destination screen after a successful
/// `GeminiAgriService.analyzeSoil(...)` call. Presents the health score,
/// per-nutrient traffic lights, the AI agronomist's synthesis, the
/// fertilizer plan, organic alternatives, guidelines, and interactive
/// follow-up tools.
///
/// When [assessment] hasn't been saved yet, pass [onSaveRequested] so the
/// caller can persist it (and, e.g., switch the Home Dashboard to its
/// History tab). Pass `null` when reopening an already-saved report from
/// history — the Save button then shows a disabled "Saved" state instead.
class RecommendationReportScreen extends StatefulWidget {
  const RecommendationReportScreen({
    required this.assessment,
    this.language = LanguageOption.defaultLanguage,
    this.onSaveRequested,
    super.key,
  });

  final SoilHealthAssessment assessment;
  final LanguageOption language;

  /// Called when the farmer taps "Save Report to History". If null, the
  /// screen assumes the report is already saved (e.g. opened from
  /// History) and disables the button accordingly.
  final VoidCallback? onSaveRequested;

  @override
  State<RecommendationReportScreen> createState() =>
      _RecommendationReportScreenState();
}

class _RecommendationReportScreenState
    extends State<RecommendationReportScreen> {
  final List<_QaTurn> _qaHistory = [];
  final TextEditingController _questionController = TextEditingController();
  bool _isAsking = false;
  bool _isSaved = false;

  static const List<String> _quickPrompts = [
    'How do I fix low Nitrogen organically?',
    'Is my soil pH safe for this crop?',
    'When should I irrigate after fertilizing?',
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askAgronomist(String question) async {
    final String trimmed = question.trim();
    if (trimmed.isEmpty || _isAsking) return;

    setState(() {
      _isAsking = true;
      _qaHistory.add(_QaTurn(question: trimmed, answer: null));
    });
    _questionController.clear();

    final String answer = await geminiAgriService.answerQuickPrompt(
      question: trimmed,
      assessment: widget.assessment,
      language: widget.language,
    );

    if (!mounted) return;
    setState(() {
      _qaHistory[_qaHistory.length - 1] = _QaTurn(
        question: trimmed,
        answer: answer,
      );
      _isAsking = false;
    });
  }

  void _handleSave() {
    if (_isSaved) return;
    reportHistoryStore.add(widget.assessment);
    setState(() => _isSaved = true);
    widget.onSaveRequested?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report saved to History.')),
    );
  }

  Future<void> _handleShareOnWhatsApp() async {
    final String reportText = _buildShareableText(widget.assessment);
    await Clipboard.setData(ClipboardData(text: reportText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Report copied — paste it into WhatsApp to share. '
          '(Direct WhatsApp share needs the url_launcher package.)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoilHealthAssessment assessment = widget.assessment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const BrandedLogoHeader(compact: true)),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              140, // clears the sticky action bar
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SoilHealthHeroCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _ListenToReportButton(assessment: assessment, language: widget.language),
                const SizedBox(height: AppSpacing.lg),
                _WeatherAdvisoryCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _SoilNutrientGraphCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _GeminiSynthesisCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _CropRecommendationCard(assessment: assessment),
                if (assessment.cropSuitabilities.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _CropSuitabilityCard(assessment: assessment),
                ],
                if (assessment.hasDiseaseFinding) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _DiseaseFindingCard(assessment: assessment),
                ],
                if (assessment.primaryIssue != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SoilNeedsCard(assessment: assessment),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ActionPlanCard(assessment: assessment),
                if (assessment.fertilizerContextNotes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _FertilizerContextCard(assessment: assessment),
                ],
                if (assessment.fertilizerOrganicAlternatives.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _FertilizerHistoryOrganicAlternativesCard(assessment: assessment),
                ],
                const SizedBox(height: AppSpacing.lg),
                _FertilizerRecommendationTableCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _FertilizerScheduleCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _OrganicAlternativesCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _DosAndDontsCard(assessment: assessment),
                const SizedBox(height: AppSpacing.lg),
                _AskAgronomistCard(
                  quickPrompts: _quickPrompts,
                  qaHistory: _qaHistory,
                  controller: _questionController,
                  isAsking: _isAsking,
                  onAsk: _askAgronomist,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyActionBar(
              isSaved: _isSaved,
              onSave: _handleSave,
              onShare: _handleShareOnWhatsApp,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Hero: Soil Health Score + per-nutrient traffic-light badges
// ═══════════════════════════════════════════════════════════════════════

/// The central "Score Card" — a dynamic gradient ring showing the health
/// score, plus a crisp 2×2 grid of interactive nutrient chips below it.
/// Colors follow the strict brand rule everywhere on this card:
///   green > 75, orange/yellow 40–74, red < 40 OR a disease was detected.
class _SoilHealthHeroCard extends StatelessWidget {
  const _SoilHealthHeroCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final SoilInputs inputs = assessment.inputs;
    final bool diseased = assessment.hasDiseaseFinding;
    final List<Color> gradient = KNStatusColor.gradientForScore(
      assessment.healthScore,
      diseaseDetected: diseased,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(color: gradient.last.withOpacity(0.4), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Soil Health Score',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _StatusPill(
                label: KNStatusColor.labelForScore(assessment.healthScore, diseaseDetected: diseased),
                icon: KNStatusColor.iconForScore(assessment.healthScore, diseaseDetected: diseased),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: _SemiCircleGauge(score: assessment.healthScore)),
          const SizedBox(height: AppSpacing.lg),
          // Crisp nutrient grid with interactive status chips.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.6,
            children: [
              _NutrientTile(
                label: 'Nitrogen (N)',
                status: SoilThresholds.nitrogenStatus(inputs.effectiveNitrogen),
                isEstimated: inputs.nitrogen == null,
              ),
              _NutrientTile(
                label: 'Phosphorus (P)',
                status: SoilThresholds.phosphorusStatus(inputs.effectivePhosphorus),
                isEstimated: inputs.phosphorus == null,
              ),
              _NutrientTile(
                label: 'Potassium (K)',
                status: SoilThresholds.potassiumStatus(inputs.effectivePotassium),
                isEstimated: inputs.potassium == null,
              ),
              _NutrientTile(
                label: 'Soil pH',
                status: SoilThresholds.phStatus(inputs.effectivePh),
                isEstimated: inputs.ph == null,
              ),
              _NutrientTile(
                label: 'Moisture',
                status: SoilThresholds.moistureStatus(inputs.effectiveMoisture),
                isEstimated: inputs.moisture == null,
              ),
            ],
          ),
          if (!inputs.hasCompleteSoilData) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '* Some readings weren\'t entered — those chips show an '
              'assumed-average placeholder, not a real measurement.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// A thick, traditional semi-circular gauge — deliberately styled like a
/// tractor's speedometer rather than a slick circular progress ring, with
/// a needle sweeping across a fixed dial and the score sitting inside the
/// dial's curve. Animates from 0 up to the assessment's score on first
/// build.
class _SemiCircleGauge extends StatelessWidget {
  const _SemiCircleGauge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    const double width = 240;
    const double height = 140;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: (score.clamp(0, 100)) / 100),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _GaugePainter(progress: value),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Text('/ 100', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the dial track, the filled progress arc, and a needle+hub — a
/// deliberately "instrument panel" look rather than a slim modern ring.
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress});

  /// 0.0–1.0
  final double progress;

  static const double _strokeWidth = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height - 4);
    final double radius = (size.width / 2) - (_strokeWidth / 2) - 4;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, track);

    final Paint value = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi * progress, false, value);

    // Tick marks every 10% around the dial, tractor-instrument style.
    final Paint tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    for (int i = 0; i <= 10; i++) {
      final double angle = pi + (pi * i / 10);
      final double outer = radius + (_strokeWidth / 2) + 4;
      final double inner = radius + (_strokeWidth / 2) - 2;
      canvas.drawLine(
        Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle)),
        Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle)),
        tickPaint,
      );
    }

    // Needle
    final double needleAngle = pi + (pi * progress);
    final double needleLength = radius - (_strokeWidth / 2) - 4;
    final Offset needleTip = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );
    final Paint needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 7, Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.progress != progress;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One cell of the results screen's 2×2 nutrient grid — a tappable,
/// color-coded status chip (e.g. "🌱 Optimal" / "⚠️ Low") that reveals a
/// short explanation of what the reading means on tap, so the grid is
/// interactive rather than purely decorative.
class _NutrientTile extends StatelessWidget {
  const _NutrientTile({
    required this.label,
    required this.status,
    this.isEstimated = false,
  });

  final String label;
  final SoilHealthStatus status;

  /// True when this reading wasn't entered by the farmer and the chip is
  /// showing an assumed-average placeholder instead of a real value.
  final bool isEstimated;

  String get _emoji {
    switch (status) {
      case SoilHealthStatus.good:
        return '🌱';
      case SoilHealthStatus.moderate:
        return '⚠️';
      case SoilHealthStatus.poor:
        return '🚨';
    }
  }

  String get _statusWord {
    switch (status) {
      case SoilHealthStatus.good:
        return 'Optimal';
      case SoilHealthStatus.moderate:
        return 'Low';
      case SoilHealthStatus.poor:
        return 'Critical';
    }
  }

  void _showExplanation(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$label is reading as "${status.label}"${isEstimated ? " (estimated — no reading entered)" : ""}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = isEstimated ? Colors.white70 : Colors.white;
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExplanation(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEstimated ? '$label*' : label,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_emoji $_statusWord',
                      style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.info_outline_rounded, size: 14, color: fg.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Soil Nutrient Graph — N/P/K/pH vs. the optimal band, as color-coded bars
// ═══════════════════════════════════════════════════════════════════════

/// Everything one nutrient bar row needs to draw itself: the farmer's
/// reading, the ideal band it's judged against, and the scale the bar is
/// drawn against (deliberately wider than the ideal band so both "a bit
/// low" and "a bit high" readings are visible on the same bar).
@immutable
class _NutrientBarData {
  const _NutrientBarData({
    required this.label,
    required this.icon,
    required this.value,
    required this.idealLow,
    required this.idealHigh,
    required this.maxScale,
    required this.unit,
    required this.status,
    required this.isEstimated,
  });

  final String label;
  final IconData icon;
  final double value;
  final double idealLow;
  final double idealHigh;
  final double maxScale;
  final String unit;
  final SoilHealthStatus status;
  final bool isEstimated;
}

/// "Soil Nutrient Graph" — a highly visual N/P/K/pH comparison against the
/// optimal baseline, built from native `Container`/`Stack` bars (no extra
/// chart dependency, so `pubspec.yaml` and the existing build stay
/// untouched). Each bar is color-coded green/mustard/terracotta by the same
/// [SoilHealthStatus] the rest of the report already uses.
class _SoilNutrientGraphCard extends StatelessWidget {
  const _SoilNutrientGraphCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final SoilInputs inputs = assessment.inputs;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<_NutrientBarData> bars = [
      _NutrientBarData(
        label: 'Nitrogen (N)',
        icon: Icons.eco_rounded,
        value: inputs.effectiveNitrogen,
        idealLow: SoilThresholds.idealNitrogenLow,
        idealHigh: SoilThresholds.idealNitrogenHigh,
        maxScale: SoilThresholds.idealNitrogenHigh * 1.8,
        unit: 'kg/acre',
        status: SoilThresholds.nitrogenStatus(inputs.effectiveNitrogen),
        isEstimated: inputs.nitrogen == null,
      ),
      _NutrientBarData(
        label: 'Phosphorus (P)',
        icon: Icons.local_florist_rounded,
        value: inputs.effectivePhosphorus,
        idealLow: SoilThresholds.idealPhosphorusLow,
        idealHigh: SoilThresholds.idealPhosphorusHigh,
        maxScale: SoilThresholds.idealPhosphorusHigh * 1.8,
        unit: 'kg/acre',
        status: SoilThresholds.phosphorusStatus(inputs.effectivePhosphorus),
        isEstimated: inputs.phosphorus == null,
      ),
      _NutrientBarData(
        label: 'Potassium (K)',
        icon: Icons.terrain_rounded,
        value: inputs.effectivePotassium,
        idealLow: SoilThresholds.idealPotassiumLow,
        idealHigh: SoilThresholds.idealPotassiumHigh,
        maxScale: SoilThresholds.idealPotassiumHigh * 1.8,
        unit: 'kg/acre',
        status: SoilThresholds.potassiumStatus(inputs.effectivePotassium),
        isEstimated: inputs.potassium == null,
      ),
      _NutrientBarData(
        label: 'Soil pH',
        icon: Icons.water_drop_rounded,
        value: inputs.effectivePh,
        idealLow: SoilThresholds.idealPhLow,
        idealHigh: SoilThresholds.idealPhHigh,
        maxScale: 14,
        unit: '',
        status: SoilThresholds.phStatus(inputs.effectivePh),
        isEstimated: inputs.ph == null,
      ),
      _NutrientBarData(
        label: 'Moisture',
        icon: Icons.opacity_rounded,
        value: inputs.effectiveMoisture,
        idealLow: SoilThresholds.idealMoistureLow,
        idealHigh: SoilThresholds.idealMoistureHigh,
        maxScale: SoilThresholds.idealMoistureHigh * 2,
        unit: '%',
        status: SoilThresholds.moistureStatus(inputs.effectiveMoisture),
        isEstimated: inputs.moisture == null,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Soil Parameters', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your readings against the optimal range — the shaded band '
              'marks where each nutrient should sit for healthy soil.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final _NutrientBarData bar in bars) ...[
              _NutrientBarRow(data: bar),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: const [
                _GraphLegendDot(color: AppColors.success, label: 'Optimal'),
                _GraphLegendDot(color: AppColors.mustard, label: 'Slightly Off'),
                _GraphLegendDot(color: AppColors.terracotta, label: 'Deficient'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientBarRow extends StatelessWidget {
  const _NutrientBarRow({required this.data});

  final _NutrientBarData data;

  Color get _barColor {
    switch (data.status) {
      case SoilHealthStatus.good:
        return AppColors.success;
      case SoilHealthStatus.moderate:
        return AppColors.mustard;
      case SoilHealthStatus.poor:
        return AppColors.terracotta;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double fraction = (data.value / data.maxScale).clamp(0.0, 1.0);
    final double idealStart = (data.idealLow / data.maxScale).clamp(0.0, 1.0);
    final double idealEnd = (data.idealHigh / data.maxScale).clamp(0.0, 1.0);
    final String valueLabel = data.unit.isEmpty
        ? data.value.toStringAsFixed(1)
        : '${data.value.toStringAsFixed(0)} ${data.unit}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(data.icon, size: 16, color: AppColors.soilBrown),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                data.isEstimated ? '${data.label} (estimated)' : data.label,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              valueLabel,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: _barColor),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final double trackWidth = constraints.maxWidth;
            final double bandLeft = trackWidth * idealStart;
            final double bandWidth = (trackWidth * (idealEnd - idealStart)).clamp(4.0, trackWidth);
            return SizedBox(
              height: 16,
              child: Stack(
                children: [
                  Container(
                    width: trackWidth,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outline.withOpacity(0.5)),
                    ),
                  ),
                  Positioned(
                    left: bandLeft,
                    width: bandWidth,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.22),
                        border: Border.symmetric(
                          vertical: BorderSide(color: AppColors.success.withOpacity(0.7), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fraction),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedFraction, _) => Container(
                      width: trackWidth * animatedFraction,
                      decoration: BoxDecoration(
                        color: _barColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GraphLegendDot extends StatelessWidget {
  const _GraphLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Gemini AI Agronomist Synthesis — glassmorphic panel
// ═══════════════════════════════════════════════════════════════════════

class _GeminiSynthesisCard extends StatelessWidget {
  const _GeminiSynthesisCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.secondary.withOpacity(0.14),
                AppColors.primary.withOpacity(0.06),
              ],
            ),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'AI Agronomist Synthesis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  assessment.poweredByGemini
                      ? const _SourceBadge(label: '✨ Gemini AI', emphasized: true)
                      : const _SourceBadge(label: 'Offline Engine'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                assessment.agronomistSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.secondary.withOpacity(0.2)
            : AppColors.outline.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: emphasized ? AppColors.primaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Target Crop Recommendation
// ═══════════════════════════════════════════════════════════════════════

class _CropRecommendationCard extends StatelessWidget {
  const _CropRecommendationCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Primary Recommendation', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    assessment.recommendedCrop,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                '+${assessment.yieldIncreasePercent}% Expected Yield',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Weather-Aware Advice — combines the local forecast with this soil
// report to flag things worth changing about the plan today/tomorrow
// (delay fertilizer ahead of rain, irrigate ahead of a dry spell, etc.)
// ═══════════════════════════════════════════════════════════════════════

class _WeatherAdvisoryCard extends StatefulWidget {
  const _WeatherAdvisoryCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  State<_WeatherAdvisoryCard> createState() => _WeatherAdvisoryCardState();
}

class _WeatherAdvisoryCardState extends State<_WeatherAdvisoryCard> {
  @override
  void initState() {
    super.initState();
    if (weatherService.snapshot == null && !weatherService.isLoading) {
      weatherService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: weatherService,
      builder: (context, _) {
        if (weatherService.snapshot == null && weatherService.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Checking today\'s weather for field-specific advice…')),
                ],
              ),
            ),
          );
        }

        if (weatherService.snapshot == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weather advice unavailable', style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          weatherService.error ?? 'Could not load weather right now.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => weatherService.refresh(),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final WeatherSnapshot snapshot = weatherService.snapshot!;
        final List<WeatherAdvisory> advisories = buildWeatherAdvisories(
          weather: snapshot,
          assessment: widget.assessment,
          cropStage: widget.assessment.inputs.cropStage,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_cloudy_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Weather-Aware Advice', style: textTheme.titleMedium)),
                    Text(
                      '${snapshot.currentEmoji} ${snapshot.currentTempC.round()}°C',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(snapshot.locationLabel, style: textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                if (advisories.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('✅ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'Conditions look stable — no weather-related changes to your plan today.',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...advisories.map(
                    (advisory) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.mustard.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${advisory.emoji} ${advisory.headline}',
                            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(advisory.message, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Crop Suitability — best-fit crop plus 2-3 runner-ups, each scored
// against the soil reading's N/P/K/pH closeness to that crop's ideal band.
// ═══════════════════════════════════════════════════════════════════════

class _CropSuitabilityCard extends StatelessWidget {
  const _CropSuitabilityCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<CropSuitability> ranked = assessment.cropSuitabilities;
    if (ranked.isEmpty) return const SizedBox.shrink();

    final CropSuitability best = ranked.first;
    final List<CropSuitability> alternatives = ranked.skip(1).take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Best Suitable Crop', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Text('${best.emoji} ${best.name}', style: textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    'Suitability: ${best.percent}%',
                    style: textTheme.titleMedium?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Also consider', style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              ...alternatives.map(
                (crop) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('${crop.emoji} ${crop.name}', style: textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '${crop.percent}%',
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Suitability compares your reading to each crop\'s ideal N/P/K/pH '
              'range — a planning guide, not a yield guarantee.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// What Your Soil Needs — headline "Primary Issue" + plain-language impact
// bullets, only rendered when a reading is meaningfully off its ideal
// band.
// ═══════════════════════════════════════════════════════════════════════

class _SoilNeedsCard extends StatelessWidget {
  const _SoilNeedsCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final SoilIssue? issue = assessment.primaryIssue;
    if (issue == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_alt_rounded, color: AppColors.mustard, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('What Your Soil Needs', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Primary Issue', style: textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              '${issue.emoji} ${issue.title}',
              style: textTheme.titleMedium?.copyWith(color: AppColors.mustard, fontWeight: FontWeight.w800),
            ),
            if (issue.impacts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Impact:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...issue.impacts.map(
                (impact) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 6, color: AppColors.mustard),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(impact, style: textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Recommended Action Plan — the report's main "what should you do" card.
// ═══════════════════════════════════════════════════════════════════════

class _ActionPlanCard extends StatelessWidget {
  const _ActionPlanCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Recommended Action Plan', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final ActionStep step in assessment.actionPlan)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 2),
                    Text(step.description, style: textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.mustard.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      'Exact fertilizer quantities below are estimates from a general '
                      'rule-of-thumb model — for large or high-value fields, confirm '
                      'with a local agronomist or Krishi Vigyan Kendra before applying.',
                      style: textTheme.bodySmall,
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

// ═══════════════════════════════════════════════════════════════════════
// Fertilizer Recommendation table — Input / Recommendation / Why
// ═══════════════════════════════════════════════════════════════════════

class _FertilizerRecommendationTableCard extends StatelessWidget {
  const _FertilizerRecommendationTableCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_rows_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Fertilizer Recommendation', style: textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'For ${assessment.recommendedCrop} on your current soil profile:',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final FertilizerRecommendationRow row in assessment.fertilizerRecommendationRows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(row.input, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _pillColor(row.recommendation).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(AppRadii.chip),
                            ),
                            child: Text(
                              row.recommendation,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _pillColor(row.recommendation),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Why? ${row.reason}',
                            style: textTheme.bodySmall,
                          ),
                        ],
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

  Color _pillColor(String recommendation) {
    switch (recommendation) {
      case 'Increase':
        return AppColors.terracotta;
      case 'Reduce':
        return AppColors.mustard;
      case 'Recommended':
        return AppColors.primary;
      default:
        return AppColors.success;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Listen to Report — reads the report aloud via on-device TTS, in the
// farmer's selected language where a voice is available.
// ═══════════════════════════════════════════════════════════════════════

class _ListenToReportButton extends StatefulWidget {
  const _ListenToReportButton({required this.assessment, required this.language});

  final SoilHealthAssessment assessment;
  final LanguageOption language;

  @override
  State<_ListenToReportButton> createState() => _ListenToReportButtonState();
}

class _ListenToReportButtonState extends State<_ListenToReportButton> {
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    reportTtsService.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    reportTtsService.removeListener(_onTtsStateChanged);
    // Stop speaking on the way out — otherwise navigating away mid-report
    // leaves the audio playing in the background with no control left on
    // screen to stop it (this button no longer exists to tap).
    if (reportTtsService.isSpeaking) {
      reportTtsService.stop();
    }
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleTap() async {
    if (reportTtsService.isSpeaking) {
      await reportTtsService.stop();
      return;
    }

    setState(() => _isPreparing = true);
    final String spokenText = await _buildSpokenReportText(widget.assessment, widget.language);
    if (!mounted) return;
    setState(() => _isPreparing = false);

    await reportTtsService.speak(spokenText, widget.language.code);

    if (!mounted) return;
    if (reportTtsService.lastFallbackNotice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reportTtsService.lastFallbackNotice!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool speaking = reportTtsService.isSpeaking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _isPreparing ? null : _handleTap,
            style: FilledButton.styleFrom(
              backgroundColor: speaking ? AppColors.error : AppColors.primary,
            ),
            icon: _isPreparing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded),
            label: Text(
              speaking ? 'Stop' : '🔊 Listen to Report',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Plays in ${widget.language.nativeName} where a voice is available on this device.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Composes the text spoken by [_ListenToReportButton]. Only
/// [SoilHealthAssessment.agronomistSummary] is guaranteed to already be in
/// [language] (it's translated at generation time by the agronomy
/// engine); everything else here is authored in English and translated in
/// one batched call to keep this responsive and avoid re-translating text
/// that's already correct.
Future<String> _buildSpokenReportText(SoilHealthAssessment assessment, LanguageOption language) async {
  final String intro =
      'Your soil health score is ${assessment.healthScore} out of 100, rated ${assessment.status.label}.';

  final String cropLine = assessment.cropSuitabilities.isNotEmpty
      ? 'The best suited crop for your field is ${assessment.cropSuitabilities.first.name}, '
          'with a suitability of ${assessment.cropSuitabilities.first.percent} percent.'
      : 'The recommended crop for your field is ${assessment.recommendedCrop}.';

  final String issueLine = assessment.primaryIssue == null
      ? ''
      : 'The main issue found in your soil is ${assessment.primaryIssue!.title}.';

  final String actionLine = assessment.actionPlan.isEmpty
      ? ''
      : 'Here is your action plan. ${assessment.actionPlan.map((step) => step.description).join(' ')}';

  final String englishBlock = [intro, cropLine, issueLine, actionLine]
      .where((s) => s.isNotEmpty)
      .join(' ');

  final String translatedBlock = language.code == 'en'
      ? englishBlock
      : await translationService.translate(englishBlock, sourceLanguage: 'en', targetLanguage: language.code);

  return [translatedBlock, assessment.agronomistSummary].where((s) => s.trim().isNotEmpty).join('. ');
}

// ═══════════════════════════════════════════════════════════════════════
// Disease / Pest Finding — only rendered when Gemini detected one
// ═══════════════════════════════════════════════════════════════════════

/// Animated soft-red warning banner shown only when Gemini detected a
/// disease/pest in the crop photo. Pulses gently to draw the eye, and
/// breaks the treatment text into clear, numbered action steps instead
/// of one dense paragraph.
class _DiseaseFindingCard extends StatefulWidget {
  const _DiseaseFindingCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  State<_DiseaseFindingCard> createState() => _DiseaseFindingCardState();
}

class _DiseaseFindingCardState extends State<_DiseaseFindingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween<double>(begin: 0.06, end: 0.16).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Splits the free-text treatment into short, numbered action steps —
  /// on sentence terminators if present, otherwise on line breaks — so
  /// the farmer gets a scannable checklist rather than a paragraph.
  List<String> get _actionSteps {
    final String raw = widget.assessment.diseaseTreatment ?? '';
    final List<String> pieces = raw
        .split(RegExp(r'(?<=[.!])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return pieces.isEmpty ? [raw] : pieces;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final SoilHealthAssessment assessment = widget.assessment;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.error.withOpacity(_pulse.value),
            border: Border.all(color: AppColors.error.withOpacity(0.35), width: 1.2),
            boxShadow: [
              BoxShadow(color: AppColors.error.withOpacity(_pulse.value * 0.8), blurRadius: 20),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disease/Pest Detected',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      assessment.diseaseName!,
                      style: textTheme.titleLarge?.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (assessment.diseaseTreatment != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.checklist_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Immediate Action Steps',
                  style: textTheme.titleMedium?.copyWith(color: AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (int i = 0; i < _actionSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _actionSteps[i],
                        style: textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Fertilizer Context — connects logged fertilizer history to this soil
// test's results. Only rendered when the farmer logged history AND at
// least one entry matched a recognized fertilizer.
// ═══════════════════════════════════════════════════════════════════════

class _FertilizerContextCard extends StatelessWidget {
  const _FertilizerContextCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.info, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Fertilizer Context', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...assessment.fertilizerContextNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: AppColors.info),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(note, style: textTheme.bodyMedium)),
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

// ═══════════════════════════════════════════════════════════════════════
// Potential Organic/Natural Alternatives — NCONF-referenced, grouped by
// the previously-used conventional fertilizer they relate to. Only
// rendered when at least one logged fertilizer matched a recognized
// entry in the offline knowledge base.
// ═══════════════════════════════════════════════════════════════════════

class _FertilizerHistoryOrganicAlternativesCard extends StatelessWidget {
  const _FertilizerHistoryOrganicAlternativesCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Potential Organic/Natural Alternatives', style: textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Not a 1:1 replacement — shown as options to explore, based on '
              'the nutrient your logged fertilizer typically supplies.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final FertilizerAlternativeGroup group in assessment.fertilizerOrganicAlternatives)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous: ${group.previousFertilizer}',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ...group.alternatives.map(
                      (alt) => Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(Icons.circle, size: 6, color: AppColors.secondary),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(alt, style: textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.md),
            InkWell(
              onTap: () async {
                await Clipboard.setData(const ClipboardData(text: 'https://nconf.dac.gov.in'));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('NCONF link copied: nconf.dac.gov.in')),
                );
              },
              child: Text(
                'Source: NCONF (nconf.dac.gov.in)',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.info,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Fertilizer Dosage + Vertical Application Timeline
// ═══════════════════════════════════════════════════════════════════════

class _FertilizerScheduleCard extends StatelessWidget {
  const _FertilizerScheduleCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chemical Fertilizer Dosage', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...assessment.fertilizerDoses.map(
              (dose) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_outlined, size: 16, color: AppColors.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: '${dose.name}: ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: '${dose.doseKgPerAcre.toStringAsFixed(0)} kg/acre'
                                  '${dose.note != null ? ' — ${dose.note}' : ''}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpacing.xl),
            Text('Application Timeline', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _VerticalTimeline(steps: assessment.scheduleSteps),
          ],
        ),
      ),
    );
  }
}

/// A clean vertical stepper: a connecting line with a filled dot per day,
/// and the step description beside it — reads clearly top-to-bottom as a
/// farmer scrolls.
class _VerticalTimeline extends StatelessWidget {
  const _VerticalTimeline({required this.steps});

  final List<ScheduleStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final ScheduleStep step = steps[index];
        final bool isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: AppColors.outline),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.dayLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Organic Alternatives
// ═══════════════════════════════════════════════════════════════════════

class _OrganicAlternativesCard extends StatelessWidget {
  const _OrganicAlternativesCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Organic Alternatives', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...assessment.organicAlternatives.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: AppColors.secondary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
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

// ═══════════════════════════════════════════════════════════════════════
// Do's & Don'ts
// ═══════════════════════════════════════════════════════════════════════

class _DosAndDontsCard extends StatelessWidget {
  const _DosAndDontsCard({required this.assessment});

  final SoilHealthAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BulletListCard(
            title: "Do's",
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.primary,
            items: assessment.dos,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _BulletListCard(
            title: "Don'ts",
            icon: Icons.cancel_rounded,
            iconColor: AppColors.error,
            items: assessment.donts,
          ),
        ),
      ],
    );
  }
}

class _BulletListCard extends StatelessWidget {
  const _BulletListCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: iconColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════
// Ask Gemini Agronomist
// ═══════════════════════════════════════════════════════════════════════

class _QaTurn {
  const _QaTurn({required this.question, required this.answer});
  final String question;
  final String? answer; // null while awaiting a response
}

class _AskAgronomistCard extends StatelessWidget {
  const _AskAgronomistCard({
    required this.quickPrompts,
    required this.qaHistory,
    required this.controller,
    required this.isAsking,
    required this.onAsk,
  });

  final List<String> quickPrompts;
  final List<_QaTurn> qaHistory;
  final TextEditingController controller;
  final bool isAsking;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Ask Gemini Agronomist', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: quickPrompts
                  .map(
                    (prompt) => ActionChip(
                      label: Text(prompt, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.surfaceVariant,
                      onPressed: isAsking ? null : () => onAsk(prompt),
                    ),
                  )
                  .toList(),
            ),
            if (qaHistory.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...qaHistory.map((turn) => _QaBubble(turn: turn)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isAsking,
                    decoration: const InputDecoration(
                      hintText: 'Type a follow-up question…',
                    ),
                    onSubmitted: onAsk,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: isAsking ? null : () => onAsk(controller.text),
                  icon: isAsking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QaBubble extends StatelessWidget {
  const _QaBubble({required this.turn});

  final _QaTurn turn;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                turn.question,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: turn.answer == null
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(turn.answer!, style: textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Sticky bottom action bar
// ═══════════════════════════════════════════════════════════════════════

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.isSaved,
    required this.onSave,
    required this.onShare,
  });

  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isSaved ? null : onSave,
                icon: Icon(isSaved ? Icons.check_rounded : Icons.save_alt_rounded),
                label: Text(isSaved ? 'Saved' : 'Save Report to History'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                label: const Text('Share on WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Export helper
// ═══════════════════════════════════════════════════════════════════════

/// Builds a plain-text version of the report suitable for clipboard-based
/// sharing (WhatsApp, SMS, email) without needing any file-export package.
String _buildShareableText(SoilHealthAssessment assessment) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('🌱 KrishiNetra Soil Report')
    ..writeln('Health Score: ${assessment.healthScore}/100 (${assessment.status.label})')
    ..writeln()
    ..writeln(assessment.agronomistSummary)
    ..writeln()
    ..writeln('Recommended Crop: ${assessment.recommendedCrop} '
        '(+${assessment.yieldIncreasePercent}% expected yield)')
    ..writeln()
    ..writeln('Fertilizer Plan:');

  for (final dose in assessment.fertilizerDoses) {
    buffer.writeln('• ${dose.name}: ${dose.doseKgPerAcre.toStringAsFixed(0)} kg/acre');
  }

  buffer
    ..writeln()
    ..writeln('Application Timeline:');
  for (final step in assessment.scheduleSteps) {
    buffer.writeln('• ${step.dayLabel}: ${step.description}');
  }

  buffer
    ..writeln()
    ..writeln('Organic Alternatives:');
  for (final item in assessment.organicAlternatives) {
    buffer.writeln('• $item');
  }

  return buffer.toString();
}
