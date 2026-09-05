import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';

/// A lightweight, JSON-serializable snapshot of one soil report — just
/// enough to plot a trend (health score, key readings, crop, date) across
/// app restarts, without persisting the full [SoilHealthAssessment]
/// (photo bytes, AI narrative, dosing tables, etc.). Full assessments
/// stay available for the current app session only (see
/// [SoilReportHistoryStore.reports]) — re-opening a past report's full
/// write-up after an app restart isn't supported yet; only the trend
/// numbers persist. This keeps the storage footprint small and avoids a
/// large, brittle serialization surface for fields that change often as
/// the report screen evolves.
class SoilSnapshotRecord {
  const SoilSnapshotRecord({
    required this.timestamp,
    required this.healthScore,
    required this.recommendedCrop,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
    required this.moisture,
  });

  final DateTime timestamp;
  final int healthScore;
  final String recommendedCrop;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double ph;
  final double moisture;

  SoilHealthStatus get status => SoilThresholds.statusForScore(healthScore);

  factory SoilSnapshotRecord.fromAssessment(SoilHealthAssessment assessment) => SoilSnapshotRecord(
        timestamp: assessment.generatedAt,
        healthScore: assessment.healthScore,
        recommendedCrop: assessment.recommendedCrop,
        nitrogen: assessment.inputs.effectiveNitrogen,
        phosphorus: assessment.inputs.effectivePhosphorus,
        potassium: assessment.inputs.effectivePotassium,
        ph: assessment.inputs.effectivePh,
        moisture: assessment.inputs.effectiveMoisture,
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'healthScore': healthScore,
        'recommendedCrop': recommendedCrop,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'ph': ph,
        'moisture': moisture,
      };

  static SoilSnapshotRecord? tryFromJson(Map<String, dynamic> json) {
    try {
      return SoilSnapshotRecord(
        timestamp: DateTime.parse(json['timestamp'] as String),
        healthScore: (json['healthScore'] as num).toInt(),
        recommendedCrop: json['recommendedCrop'] as String? ?? 'Unknown crop',
        nitrogen: (json['nitrogen'] as num).toDouble(),
        phosphorus: (json['phosphorus'] as num).toDouble(),
        potassium: (json['potassium'] as num).toDouble(),
        ph: (json['ph'] as num).toDouble(),
        moisture: (json['moisture'] as num?)?.toDouble() ?? 27.5,
      );
    } catch (_) {
      // A malformed/older-schema entry shouldn't take down the whole
      // history list — just skip it.
      return null;
    }
  }
}

/// Holds soil report history for the app.
///
/// Two tiers, on purpose:
/// - [reports]: full, rich [SoilHealthAssessment] objects — available for
///   the current app session only (in memory), used by the History list
///   and "tap to reopen" flow while the app is running.
/// - [trendSnapshots]: lightweight [SoilSnapshotRecord]s — persisted to
///   [SharedPreferences] via [hydrate]/[_persist], so the health-score
///   trend chart still has data after an app restart even though the
///   full reports themselves don't.
final class SoilReportHistoryStore {
  final List<SoilHealthAssessment> _reports = [];
  List<SoilSnapshotRecord> _trendSnapshots = [];
  bool _hydrated = false;

  static const String _prefsKey = 'krishinetra.soil_history_snapshots_v1';

  /// Cap on how many trend points we keep — a few months of regular
  /// scanning, without the persisted payload growing unbounded.
  static const int _maxPersisted = 60;

  List<SoilHealthAssessment> get reports => List.unmodifiable(_reports);

  /// Newest first, same ordering as [reports].
  List<SoilSnapshotRecord> get trendSnapshots => List.unmodifiable(_trendSnapshots);

  /// Restores persisted trend snapshots. Call once from `main()` before
  /// `runApp`, alongside `languageManager.initialize()`. Safe to call
  /// again (no-op after the first successful call) and fails soft: any
  /// storage error just leaves history empty instead of blocking or
  /// crashing app startup — exactly the same contract as
  /// `LanguageManager.initialize()`.
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(_prefsKey) ?? const [];
      _trendSnapshots = raw
          .map((s) => SoilSnapshotRecord.tryFromJson(jsonDecode(s) as Map<String, dynamic>))
          .whereType<SoilSnapshotRecord>()
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      _trendSnapshots = [];
    }
  }

  /// Records a freshly generated report: kept in full for this session
  /// (so the farmer can reopen it immediately from the History tab) and
  /// persisted as a lightweight trend point in the background.
  void add(SoilHealthAssessment assessment) {
    _reports.insert(0, assessment);

    _trendSnapshots.insert(0, SoilSnapshotRecord.fromAssessment(assessment));
    if (_trendSnapshots.length > _maxPersisted) {
      _trendSnapshots = _trendSnapshots.sublist(0, _maxPersisted);
    }
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = _trendSnapshots.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_prefsKey, raw);
    } catch (_) {
      // Best-effort — a storage failure here shouldn't interrupt the
      // farmer's flow; the report they just generated is still visible
      // for the rest of this session via [reports].
    }
  }

  /// Clears both the in-session reports and the persisted trend history.
  void clear() {
    _reports.clear();
    _trendSnapshots.clear();
    unawaited(_persist());
  }
}

/// App-wide singleton.
final SoilReportHistoryStore reportHistoryStore = SoilReportHistoryStore();
