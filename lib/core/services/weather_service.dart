import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// One day of forecast data from Open-Meteo.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.tempMaxC,
    required this.tempMinC,
    required this.precipitationProbabilityPercent,
    required this.precipitationSumMm,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMaxC;
  final double tempMinC;
  final int precipitationProbabilityPercent;
  final double precipitationSumMm;

  String get emoji => weatherEmojiForCode(weatherCode);
  String get condition => weatherConditionForCode(weatherCode);
}

/// A single fetched weather snapshot: current conditions plus a short
/// (3-day) forecast, for the farmer's current device location.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationLabel,
    required this.currentTempC,
    required this.currentHumidityPercent,
    required this.currentWindKph,
    required this.currentWeatherCode,
    required this.daily,
    required this.fetchedAt,
  });

  final String locationLabel;
  final double currentTempC;
  final int currentHumidityPercent;
  final double currentWindKph;
  final int currentWeatherCode;

  /// Index 0 is today, index 1 (if present) is tomorrow, etc.
  final List<DailyForecast> daily;
  final DateTime fetchedAt;

  String get currentEmoji => weatherEmojiForCode(currentWeatherCode);
  String get currentCondition => weatherConditionForCode(currentWeatherCode);

  DailyForecast? get today => daily.isNotEmpty ? daily.first : null;
  DailyForecast? get tomorrow => daily.length > 1 ? daily[1] : null;
}

/// Maps Open-Meteo's WMO weather codes to a farmer-friendly emoji/label.
/// https://open-meteo.com/en/docs — "WMO Weather interpretation codes".
String weatherEmojiForCode(int code) {
  if (code == 0) return '☀️';
  if (code <= 3) return '⛅';
  if (code == 45 || code == 48) return '🌫️';
  if (code >= 51 && code <= 57) return '🌦️';
  if (code >= 61 && code <= 67) return '🌧️';
  if (code >= 71 && code <= 77) return '🌨️';
  if (code >= 80 && code <= 82) return '🌧️';
  if (code >= 95) return '⛈️';
  return '🌤️';
}

String weatherConditionForCode(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Variable';
}

/// Fetches real, location-based weather for the dashboard's Weather tab
/// and the report screen's weather-aware advisory card.
///
/// Deliberately built with **no API key**: [Open-Meteo](https://open-meteo.com)
/// is a free, keyless forecast API, and reverse geocoding (turning
/// coordinates into a "City, State" label) uses BigDataCloud's free
/// client-side reverse-geocode endpoint — both consistent with
/// KrishiNetra's existing "don't require a paid key just to see basic
/// info" design (see `kGeminiApiKey`'s own doc comment).
///
/// A [ChangeNotifier] so widgets can simply wrap themselves in an
/// `AnimatedBuilder(animation: weatherService, ...)` to rebuild whenever
/// a fetch starts, finishes, or fails — no separate listener plumbing.
class WeatherService extends ChangeNotifier {
  WeatherSnapshot? snapshot;
  bool isLoading = false;

  /// Short, farmer-readable reason the last [refresh] failed, or null.
  /// Never a raw exception string — see [_friendlyError].
  String? error;

  /// Fetches a fresh snapshot for the device's current location. Safe to
  /// call repeatedly (e.g. pull-to-refresh, or a screen's initState
  /// safety-net check) — failures are captured in [error] rather than
  /// thrown, so a denied permission or a flaky connection can never crash
  /// the caller.
  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final Position position = await _resolvePosition();
      final String locationLabel = await _reverseGeocode(position.latitude, position.longitude);
      final Uri uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum'
        '&timezone=auto&forecast_days=3',
      );
      final http.Response response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Weather service returned HTTP ${response.statusCode}');
      }
      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      snapshot = _parse(body, locationLabel);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Position> _resolvePosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.reduced),
    );
  }

  /// Best-effort "City, State" label. Falls back to a coordinate string
  /// on any failure — reverse geocoding is a nicety, never a blocker for
  /// showing the actual forecast.
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final Uri uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lon&localityLanguage=en',
      );
      final http.Response response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
        final String? city = (body['city'] as String?)?.trim().isNotEmpty == true
            ? body['city'] as String
            : (body['locality'] as String?);
        final String? state = body['principalSubdivision'] as String?;
        if (city != null && city.isNotEmpty) {
          return (state != null && state.isNotEmpty) ? '$city, $state' : city;
        }
      }
    } catch (_) {
      // Non-critical — fall through to a coordinate label below.
    }
    return '${lat.toStringAsFixed(2)}°N, ${lon.toStringAsFixed(2)}°E';
  }

  WeatherSnapshot _parse(Map<String, dynamic> body, String locationLabel) {
    final Map<String, dynamic> current = body['current'] as Map<String, dynamic>;
    final Map<String, dynamic> daily = body['daily'] as Map<String, dynamic>;

    final List<dynamic> dates = daily['time'] as List<dynamic>;
    final List<dynamic> codes = daily['weather_code'] as List<dynamic>;
    final List<dynamic> tempsMax = daily['temperature_2m_max'] as List<dynamic>;
    final List<dynamic> tempsMin = daily['temperature_2m_min'] as List<dynamic>;
    final List<dynamic> precipProb = daily['precipitation_probability_max'] as List<dynamic>;
    final List<dynamic> precipSum = daily['precipitation_sum'] as List<dynamic>;

    final List<DailyForecast> forecasts = [
      for (int i = 0; i < dates.length; i++)
        DailyForecast(
          date: DateTime.parse(dates[i] as String),
          weatherCode: (codes[i] as num).toInt(),
          tempMaxC: (tempsMax[i] as num).toDouble(),
          tempMinC: (tempsMin[i] as num).toDouble(),
          precipitationProbabilityPercent: (precipProb[i] as num).toInt(),
          precipitationSumMm: (precipSum[i] as num).toDouble(),
        ),
    ];

    return WeatherSnapshot(
      locationLabel: locationLabel,
      currentTempC: (current['temperature_2m'] as num).toDouble(),
      currentHumidityPercent: (current['relative_humidity_2m'] as num).toInt(),
      currentWindKph: (current['wind_speed_10m'] as num).toDouble(),
      currentWeatherCode: (current['weather_code'] as num).toInt(),
      daily: forecasts,
      fetchedAt: DateTime.now(),
    );
  }

  String _friendlyError(Object e) {
    final String msg = e.toString();
    if (msg.contains('permission denied')) {
      return 'Location permission is needed to show weather for your field.';
    }
    if (msg.contains('services disabled')) {
      return 'Turn on location services on this device to see local weather.';
    }
    return 'Could not fetch weather right now — check your connection and try again.';
  }
}

/// App-wide singleton — every weather-reading widget shares one fetch and
/// one cached snapshot instead of each independently hitting the API.
final WeatherService weatherService = WeatherService();
