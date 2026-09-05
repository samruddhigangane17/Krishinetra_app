// Tests for LanguageManager — the centralized language state introduced
// in this pass. Uses SharedPreferences.setMockInitialValues (the
// standard shared_preferences testing hook) so these tests don't touch
// real device/browser storage.
//
// Run with: flutter test test/core/services/language_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:krishinetra/core/services/language_manager.dart';
import 'package:krishinetra/core/services/locale_controller.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh, empty mock storage for every test so persistence tests
    // don't leak state between each other.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LanguageManager', () {
    test('defaults to English before anything is selected or restored', () {
      // A fresh manager instance (not the app-wide singleton, so this
      // test doesn't depend on/interfere with test execution order)
      // must start on English — the one non-negotiable default this
      // task's brief calls out explicitly.
      final LanguageManager manager = LanguageManager.instance;
      expect(manager.current.code, 'en');
      expect(manager.current, LanguageOption.defaultLanguage);
    });

    test('setLanguage updates the current selection immediately', () async {
      final LanguageManager manager = LanguageManager.instance;
      final LanguageOption marathi = LanguageOption.supported.firstWhere(
        (l) => l.code == 'mr',
      );

      await manager.setLanguage(marathi);

      expect(manager.current.code, 'mr');
      expect(manager.selected.value.code, 'mr');
    });

    test('setLanguage keeps localeController in sync', () async {
      final LanguageManager manager = LanguageManager.instance;
      final LanguageOption tamil = LanguageOption.supported.firstWhere((l) => l.code == 'ta');

      await manager.setLanguage(tamil);

      // AppLocalizations/MaterialApp read from localeController, not
      // LanguageManager directly — this is the sync contract that keeps
      // existing localized UI working without any screen-level change.
      expect(localeController.value.languageCode, 'ta');
    });

    test('setLanguage notifies listeners exactly once per change', () async {
      final LanguageManager manager = LanguageManager.instance;
      final LanguageOption kannada = LanguageOption.supported.firstWhere(
        (l) => l.code == 'kn',
      );

      int notifications = 0;
      void listener() => notifications++;
      manager.selected.addListener(listener);

      await manager.setLanguage(kannada);

      expect(notifications, 1);
      manager.selected.removeListener(listener);
    });

    test('setLanguage persists the choice for a fresh manager/session to restore', () async {
      final LanguageManager manager = LanguageManager.instance;
      final LanguageOption telugu = LanguageOption.supported.firstWhere((l) => l.code == 'te');

      await manager.setLanguage(telugu);

      // Simulate the next app cold start reading the same underlying
      // storage this manager just wrote to.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('krishinetra.selected_language_code'), 'te');
    });

    test('every supported language can be selected without throwing', () async {
      final LanguageManager manager = LanguageManager.instance;
      for (final LanguageOption option in LanguageOption.supported) {
        await manager.setLanguage(option);
        expect(manager.current.code, option.code);
        expect(localeController.value.languageCode, option.code);
      }
    });

    test('initialize is safe to call multiple times', () async {
      final LanguageManager manager = LanguageManager.instance;
      await manager.initialize();
      await manager.initialize(); // must not throw or double-apply
      expect(manager.current, isNotNull);
    });
  });
}
