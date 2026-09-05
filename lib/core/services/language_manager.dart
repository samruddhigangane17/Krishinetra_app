import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:krishinetra/core/services/locale_controller.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';

/// Single, centralized source of truth for KrishiNetra's currently
/// selected [LanguageOption] — the one place every screen should read
/// the farmer's language from and the one place a language change should
/// be made, instead of each screen along the navigation chain (Landing →
/// Login → Dashboard → Profile) receiving and re-relaying its own copy
/// via a constructor parameter, as it did before this pass.
///
/// Three responsibilities, kept in one place on purpose:
///
/// 1. **Live state** — [selected] is a [ValueNotifier], so any widget can
///    either read [current] once (a snapshot) or wrap itself in a
///    [ValueListenableBuilder] to rebuild automatically the moment the
///    language changes, from anywhere in the app (onboarding's
///    language-selection screen, or the in-app switcher on the Profile
///    tab) — no callback needs to be threaded down to reach it.
/// 2. **Sync with Flutter's own localization** — every [setLanguage] call
///    also updates [localeController] (the [Locale] `MaterialApp` and
///    every `AppLocalizations.of(context)` call already key off), so
///    nothing that already reads localized UI text needs to change.
/// 3. **Persistence** — the selection is saved via [SharedPreferences]
///    and restored by [initialize] before the first frame (see
///    `main.dart`), so it survives an app restart. **English remains the
///    default**: if nothing has ever been saved, or the saved value is
///    unrecognized, or storage itself is unavailable, [selected] simply
///    stays at [LanguageOption.defaultLanguage] — never a crash, never a
///    blocked startup.
final class LanguageManager {
  LanguageManager._();

  static final LanguageManager instance = LanguageManager._();

  static const String _prefsKey = 'krishinetra.selected_language_code';

  /// English until [initialize] restores a previously saved choice (if
  /// any) or [setLanguage] is called — matches the [Locale] both
  /// [localeController] and `MaterialApp` already start with.
  final ValueNotifier<LanguageOption> selected = ValueNotifier<LanguageOption>(
    LanguageOption.defaultLanguage,
  );

  /// Convenience snapshot for call sites that just need the current value
  /// once (e.g. building a one-off translation request) rather than a
  /// live rebuild.
  LanguageOption get current => selected.value;

  bool _initialized = false;

  /// Restores a previously saved language choice, if any. Call once from
  /// `main()` before `runApp` — safe to call again (a no-op after the
  /// first successful call) and fails soft: any storage error just
  /// leaves the English default in place instead of blocking or crashing
  /// app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? storedCode = prefs.getString(_prefsKey);
      if (storedCode == null) return;
      final LanguageOption? match = _findByCode(storedCode);
      if (match != null) _apply(match);
    } catch (_) {
      // Storage unavailable in this environment (some web/test
      // sandboxes, first-run permission edge cases, etc.) — English
      // default stands, exactly as if nothing had ever been saved.
    }
  }

  /// Changes the app's active language everywhere at once:
  /// - Updates [selected], so every [ValueListenableBuilder] listening to
  ///   it (the dashboard shell, the language-selection screen, etc.)
  ///   rebuilds immediately.
  /// - Updates [localeController], so `AppLocalizations`-driven static UI
  ///   text, nav labels, and Flutter's own Material/Cupertino
  ///   localizations switch immediately too — no restart needed, exactly
  ///   as the app already behaved before this pass.
  /// - Persists the choice so it's still selected next time the app
  ///   opens. If persisting fails, the change still applies for the rest
  ///   of this session — it just won't survive a restart; the live
  ///   change is never reverted because of a storage error.
  Future<void> setLanguage(LanguageOption language) async {
    _apply(language);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.code);
    } catch (_) {
      // See doc comment above — a storage failure here is intentionally
      // silent to the caller; the language has already taken effect.
    }
  }

  void _apply(LanguageOption language) {
    selected.value = language;
    localeController.value = Locale(language.code);
  }

  LanguageOption? _findByCode(String code) {
    for (final LanguageOption option in LanguageOption.supported) {
      if (option.code == code) return option;
    }
    return null;
  }
}

/// App-wide singleton — the one entry point the rest of the app should
/// use to read or change the farmer's selected language, instead of
/// reaching for [localeController] directly or threading a
/// [LanguageOption] through a chain of constructors.
final LanguageManager languageManager = LanguageManager.instance;
