import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:krishinetra/features/profile/domain/models/farmer_profile.dart';

/// Persists the one-per-device [FarmerProfile] to [SharedPreferences] —
/// same storage mechanism and one-per-device scope as `LanguageManager`
/// and `SoilReportHistoryStore`, so this doesn't introduce a new pattern
/// for what's still fundamentally a single-farmer-per-device app.
///
/// [ChangeNotifier] so screens can wrap themselves in
/// `AnimatedBuilder(animation: farmerProfileService, ...)` and rebuild
/// whenever the profile is loaded or saved — same approach as
/// `WeatherService`.
class FarmerProfileService extends ChangeNotifier {
  static const String _prefsKey = 'krishinetra.farmer_profile_v1';

  FarmerProfile? profile;
  bool _hydrated = false;

  /// Restores the persisted profile. Call once from `main()` alongside
  /// `languageManager.initialize()` / `reportHistoryStore.hydrate()`.
  /// Fails soft — a storage error just leaves [profile] null, same
  /// contract as the other hydrate methods in the app.
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_prefsKey);
      if (raw != null) {
        profile = FarmerProfile.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      profile = null;
    }
    notifyListeners();
  }

  Future<void> save(FarmerProfile updated) async {
    profile = updated.copyWith(updatedAt: DateTime.now());
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(profile!.toJson()));
    } catch (_) {
      // Best-effort — the in-memory profile still applies for the rest of
      // this session even if the write itself failed.
    }
  }

  Future<void> clear() async {
    profile = null;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Best-effort, same as save().
    }
  }
}

/// App-wide singleton.
final FarmerProfileService farmerProfileService = FarmerProfileService();
