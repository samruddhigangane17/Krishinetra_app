import 'package:flutter/foundation.dart' show immutable;

import 'package:krishinetra/core/services/weather_service.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';

/// One short, actionable weather-driven note for the report screen —
/// e.g. "delay fertilizer, rain's coming" or "irrigate, it's dry and your
/// soil's already low on moisture".
@immutable
class WeatherAdvisory {
  const WeatherAdvisory({required this.emoji, required this.headline, required this.message});

  final String emoji;
  final String headline;
  final String message;
}

/// Combines a weather forecast with a soil report (and, if known, the
/// crop's growth stage) into a short list of practical advisories.
///
/// Inputs: [weather] (location + forecast), [assessment] (which already
/// carries crop, soil condition/status, and soil moisture), and the
/// optional [cropStage]. Deliberately rule-based rather than sent through
/// Gemini — instant, reproducible, and works with no API key configured,
/// consistent with the rest of the app's deterministic engines (dosing,
/// crop suitability, primary-issue detection).
///
/// Returns at most 3 advisories, most important first. An empty list
/// means conditions don't call for a change to the plan — callers should
/// show a calm "no weather-related changes today" message rather than
/// leaving a blank space, so farmers don't read the empty state as an
/// error.
List<WeatherAdvisory> buildWeatherAdvisories({
  required WeatherSnapshot weather,
  required SoilHealthAssessment assessment,
  String? cropStage,
}) {
  final List<WeatherAdvisory> advisories = [];
  final DailyForecast? tomorrow = weather.tomorrow;
  final double moisture = assessment.inputs.effectiveMoisture;
  final String crop = assessment.recommendedCrop;

  // Rain expected tomorrow → hold off on fertilizer to avoid nutrient
  // loss through runoff before the crop can take it up.
  final bool rainLikelyTomorrow = tomorrow != null && tomorrow.precipitationProbabilityPercent >= 50;
  if (rainLikelyTomorrow) {
    advisories.add(WeatherAdvisory(
      emoji: '🌧️',
      headline: 'Rain expected tomorrow',
      message: 'Consider delaying fertilizer application for $crop — rain this soon can wash '
          'nutrients away before the roots absorb them. Apply once the soil has had a day or two to dry.',
    ));
  }

  // Dry outlook + soil already below its ideal moisture band → flag an
  // irrigation need, using the farmer's own moisture reading rather than
  // just the forecast.
  final bool dryOutlook = tomorrow == null || tomorrow.precipitationProbabilityPercent < 20;
  final bool lowMoisture = moisture < SoilThresholds.idealMoistureLow;
  if (dryOutlook && lowMoisture) {
    advisories.add(const WeatherAdvisory(
      emoji: '☀️',
      headline: 'Dry conditions expected',
      message: 'Irrigation may be required — your soil moisture reading is already below the '
          'ideal range and no meaningful rain is forecast in the next day.',
    ));
  } else if (dryOutlook && weather.currentTempC >= 35) {
    advisories.add(WeatherAdvisory(
      emoji: '☀️',
      headline: 'Hot, dry conditions expected',
      message: 'High temperatures with no rain forecast — keep an eye on $crop for heat stress '
          'and irrigate if leaves wilt during the hottest part of the day.',
    ));
  }

  // Heavy rain forecast on top of already-saturated soil → waterlogging
  // risk, worth flagging separately from the "delay fertilizer" note.
  final bool heavyRainForecast = tomorrow != null && tomorrow.precipitationSumMm >= 20;
  final bool alreadyWet = moisture > SoilThresholds.idealMoistureHigh;
  if (heavyRainForecast && alreadyWet) {
    advisories.add(const WeatherAdvisory(
      emoji: '🌊',
      headline: 'Heavy rain on already-wet soil',
      message: 'Your soil moisture is already above the ideal range — check field drainage '
          'before the rain arrives to avoid waterlogging and root damage.',
    ));
  }

  // Strong wind today → spraying (fertilizer or pesticide) will drift and
  // land unevenly.
  if (weather.currentWindKph >= 20) {
    advisories.add(const WeatherAdvisory(
      emoji: '💨',
      headline: 'Windy conditions today',
      message: 'Hold off on spraying fertilizer or pesticide — wind this strong causes uneven '
          'coverage and drift onto neighbouring plots.',
    ));
  }

  // Flowering stage + rain → pollination risk, only shown when the
  // farmer told us the crop stage (never assumed).
  if (cropStage != null && cropStage.toLowerCase() == 'flowering' && rainLikelyTomorrow) {
    advisories.add(WeatherAdvisory(
      emoji: '🌸',
      headline: 'Rain during flowering stage',
      message: 'Heavy rain during flowering can affect pollination for $crop — inspect the crop '
          'once the rain passes and note any dropped flowers.',
    ));
  }

  return advisories.take(3).toList();
}
