import 'package:flutter/foundation.dart' show immutable;

import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';
import 'package:krishinetra/features/schemes/domain/models/scheme.dart';

/// One scheme matched against the farmer's soil report, with the
/// plain-language reasoning that earned it a spot in "Recommended For
/// You" — this [reason] string is the whole point of the feature: never
/// show a match without saying *why* it applies to this specific report.
@immutable
class SchemeMatch {
  const SchemeMatch({required this.scheme, required this.reason, required this.priority});

  final Scheme scheme;
  final String reason;

  /// Higher = more relevant. Used only to sort/de-duplicate — never shown
  /// to the farmer.
  final int priority;
}

/// Matches a soil diagnostic report against the scheme dataset.
///
/// **Deliberately rule-based**, not ML/LLM-driven: every rule below
/// references a real field already on [SoilHealthAssessment]/[SoilInputs]
/// (health score, N/P/K, pH, moisture, primary issue, recommended crop,
/// organic-input flag) and matches it against scheme *names* in the
/// dataset via keyword search — never against the dataset's
/// `eligibility`/`benefits` text, which (see the dataset review) is
/// generic boilerplate with no per-scheme numeric criteria to parse.
/// This keeps every match traceable back to something concrete: a
/// reviewer can always point at the soil-report field and the scheme-name
/// keywords that produced a given card.
///
/// Returns matches sorted best-first, de-duplicated by scheme id (a
/// scheme can only be recommended once, under its single best-fitting
/// reason even if multiple rules would have surfaced it).
List<SchemeMatch> matchSchemesToReport({
  required List<Scheme> schemes,
  required SoilHealthAssessment report,
}) {
  final List<SchemeMatch> candidates = [];
  final SoilInputs inputs = report.inputs;

  Scheme? findFirst(List<String> mustContainAll, {String? category}) {
    for (final Scheme s in schemes) {
      if (category != null && s.category != category) continue;
      final String name = s.name.toLowerCase();
      if (mustContainAll.every((k) => name.contains(k))) return s;
    }
    return null;
  }

  Scheme? findAny(List<String> anyOf, {String? category}) {
    for (final Scheme s in schemes) {
      if (category != null && s.category != category) continue;
      final String name = s.name.toLowerCase();
      if (anyOf.any((k) => name.contains(k))) return s;
    }
    return null;
  }

  const String soilCategory = 'Soil Health, Seeds & Sustainable Bio-Farming';
  const String irrigationCategory = 'On-Farm Irrigation & Water Infrastructure Components';
  const String horticultureCategory = 'Horticulture Crop Variants & Protected Farming';

  // ── 1. Soil Health Card — always relevant right after any scan ──────
  final Scheme? soilCard = findFirst(['soil health card']);
  if (soilCard != null) {
    candidates.add(SchemeMatch(
      scheme: soilCard,
      reason: 'Your soil health score is ${report.healthScore}/100 — a Soil Health Card '
          'follow-up gives you an official, government-recognized nutrient test to confirm '
          'these readings and track how your soil changes every couple of years.',
      priority: 90,
    ));
  }

  // ── 2. No organic inputs reported → organic transition schemes ─────
  if (inputs.usesOrganicInputs == false) {
    final Scheme? pkvy = findFirst(['pkvy', 'organic', 'cluster'], category: soilCategory) ??
        findAny(['organic'], category: soilCategory);
    if (pkvy != null) {
      candidates.add(SchemeMatch(
        scheme: pkvy,
        reason: 'You reported not using organic inputs — ${pkvy.name} incentivizes moving '
            'toward organic/bio-based farming, which can lower input costs over time and '
            'help rebuild soil biology that chemical-only fertilizer use can deplete.',
        priority: 88,
      ));
    }

    final Scheme? vermicompost = findAny(['vermicompost'], category: soilCategory);
    if (vermicompost != null) {
      candidates.add(SchemeMatch(
        scheme: vermicompost,
        reason: 'A vermicompost unit is a practical first step toward organic inputs — '
            '${vermicompost.name} subsidizes the structure so you can start producing your own.',
        priority: 62,
      ));
    }
  } else if (inputs.usesOrganicInputs == true) {
    // Already using organic inputs → surface certification/expansion
    // support instead of "start using organic" messaging.
    final Scheme? certification = findFirst(['pkvy'], category: soilCategory) ??
        findAny(['certification', 'residue testing'], category: soilCategory);
    if (certification != null) {
      candidates.add(SchemeMatch(
        scheme: certification,
        reason: 'You\'re already using organic inputs — ${certification.name} can help you '
            'move toward formal organic certification, which often unlocks a better market price.',
        priority: 65,
      ));
    }
  }

  // ── 3. Low health score → broader, integrated support ──────────────
  if (report.healthScore < 45) {
    final Scheme? ifs = findAny(['integrated farming system'], category: soilCategory);
    if (ifs != null) {
      candidates.add(SchemeMatch(
        scheme: ifs,
        reason: 'A health score of ${report.healthScore}/100 points to multiple nutrient gaps '
            'at once — ${ifs.name} supports a broader, integrated approach to rebuilding soil '
            'fertility rather than correcting a single nutrient in isolation.',
        priority: 80,
      ));
    }
  }

  // ── 4. Primary issue → the most specific matching scheme ───────────
  final SoilIssue? issue = report.primaryIssue;
  if (issue != null) {
    final String title = issue.title.toLowerCase();

    if (title.contains('nitrogen')) {
      final Scheme? greenManure = findAny(['green manuring', 'dhaincha', 'sunnhemp'], category: soilCategory);
      if (greenManure != null) {
        candidates.add(SchemeMatch(
          scheme: greenManure,
          reason: 'Your soil shows ${issue.title} — green manure crops like dhaincha/sunnhemp '
              'fix nitrogen naturally in the soil ahead of your main crop; this scheme '
              'subsidizes the seed.',
          priority: 76,
        ));
      }
    }

    if (title.contains('phosphorus') || title.contains('potassium')) {
      final Scheme? residueTesting = findAny(['residue testing', 'certification'], category: soilCategory);
      if (residueTesting != null) {
        candidates.add(SchemeMatch(
          scheme: residueTesting,
          reason: 'Your soil shows ${issue.title} — a certified nutrient/residue test through '
              '${residueTesting.name} confirms the deficit precisely before you spend on '
              'correcting it.',
          priority: 58,
        ));
      }
    }

    if (title.contains('ph')) {
      final Scheme? ipm = findAny(['integrated pest management', 'ipm'], category: soilCategory);
      if (ipm != null) {
        candidates.add(SchemeMatch(
          scheme: ipm,
          reason: 'Soil pH outside the ideal range often goes along with weaker natural pest '
              'resistance — ${ipm.name} supports lower-chemical pest management while you work '
              'on correcting the pH.',
          priority: 40,
        ));
      }
    }
  }

  // ── 5. Soil moisture → irrigation infrastructure ───────────────────
  final double moisture = inputs.effectiveMoisture;
  if (moisture < SoilThresholds.idealMoistureLow) {
    final Scheme? drip = findAny(['drip irrigation'], category: irrigationCategory);
    if (drip != null) {
      candidates.add(SchemeMatch(
        scheme: drip,
        reason: 'Your soil moisture reading (${moisture.round()}%) is below the ideal range — '
            '${drip.name} subsidizes drip irrigation, which delivers water directly to roots '
            'far more efficiently than flood irrigation.',
        priority: 78,
      ));
    }
    final Scheme? farmPond = findAny(['farm pond'], category: irrigationCategory);
    if (farmPond != null) {
      candidates.add(SchemeMatch(
        scheme: farmPond,
        reason: 'With soil moisture already low, having your own water storage matters — '
            '${farmPond.name} helps you build a farm pond to store water for exactly this kind '
            'of dry spell.',
        priority: 50,
      ));
    }
  }

  // ── 6. Recommended crop → matching horticulture scheme, if any ─────
  final String crop = report.recommendedCrop.toLowerCase();
  const Map<String, String> cropToKeyword = {
    'mango': 'mango',
    'cashew': 'cashew',
    'pomegranate': 'pomegranate',
    'sweet lime': 'mosambi',
    'mosambi': 'mosambi',
    'mandarin': 'santra',
    'orange': 'santra',
    'dragon fruit': 'dragon fruit',
    'avocado': 'avocado',
    'coconut': 'coconut',
  };
  for (final MapEntry<String, String> entry in cropToKeyword.entries) {
    if (!crop.contains(entry.key)) continue;
    final Scheme? cropScheme = findAny([entry.value], category: horticultureCategory);
    if (cropScheme != null) {
      candidates.add(SchemeMatch(
        scheme: cropScheme,
        reason: 'Your recommended crop is ${report.recommendedCrop} — ${cropScheme.name} '
            'directly supports planting this crop.',
        priority: 84,
      ));
    }
    break;
  }

  // De-duplicate by scheme id (a scheme should only appear once, under
  // its single highest-priority reason), then sort best-first.
  final Map<String, SchemeMatch> deduped = {};
  for (final SchemeMatch match in candidates) {
    final SchemeMatch? existing = deduped[match.scheme.id];
    if (existing == null || match.priority > existing.priority) {
      deduped[match.scheme.id] = match;
    }
  }

  final List<SchemeMatch> result = deduped.values.toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));
  return result;
}
