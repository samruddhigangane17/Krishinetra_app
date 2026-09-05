// Tests for SarvamTranslationService.
//
// `SARVAM_API_KEY` is never set for this test run (no `--dart-define` is
// passed by `flutter test` here), so `isConfigured` is always `false` in
// this suite — which is itself the most important behavior to lock down:
// with no key, every call must safely fall through to the original text
// rather than throwing, hanging, or crashing the app. That's exactly the
// "don't break offline functionality" requirement for this integration.
//
// Run with: flutter test test/core/services/sarvam_service_test.dart
// To additionally exercise the real API call path against a live key:
// flutter test --dart-define=SARVAM_API_KEY=your_key
import 'package:flutter_test/flutter_test.dart';
import 'package:krishinetra/core/services/sarvam_service.dart';

void main() {
  group('SarvamTranslationService', () {
    late SarvamTranslationService service;

    setUp(() {
      service = SarvamTranslationService();
    });

    test('isConfigured is false with no SARVAM_API_KEY dart-define', () {
      // Locks in the "no key committed in source" requirement: without an
      // explicit --dart-define, there is no fallback constant to silently
      // activate a real network call.
      expect(service.isConfigured, isFalse);
    });

    test('translate returns original text unchanged when unconfigured', () async {
      const String input = 'Your soil health score is 82/100.';
      final String result = await service.translate(
        input,
        sourceLanguage: 'en',
        targetLanguage: 'mr',
      );
      expect(result, input);
    });

    test('translate short-circuits when source and target languages match', () async {
      const String input = 'यह एक परीक्षण है';
      final String result = await service.translate(
        input,
        sourceLanguage: 'hi',
        targetLanguage: 'hi',
      );
      expect(result, input);
    });

    test('translate returns blank text unchanged without attempting a call', () async {
      final String result = await service.translate(
        '   ',
        sourceLanguage: 'en',
        targetLanguage: 'ta',
      );
      expect(result, '   ');
    });

    test('translateBatch preserves length and order when unconfigured', () async {
      final List<String> input = <String>[
        'Apply urea in two split doses.',
        'Water the field every 3 days.',
        'Watch for yellowing leaves.',
      ];
      final List<String> result = await service.translateBatch(
        input,
        sourceLanguage: 'en',
        targetLanguage: 'te',
      );
      expect(result, input);
      expect(result.length, input.length);
    });

    test('translateBatch returns an empty list unchanged', () async {
      final List<String> result = await service.translateBatch(
        <String>[],
        sourceLanguage: 'en',
        targetLanguage: 'kn',
      );
      expect(result, isEmpty);
    });

    test('translateBatch handles a mix of blank and non-blank strings without throwing', () async {
      final List<String> input = <String>['', 'Real content here', '   '];
      final List<String> result = await service.translateBatch(
        input,
        sourceLanguage: 'en',
        targetLanguage: 'gu',
      );
      expect(result, input); // unconfigured -> all unchanged
    });

    test(
      'repeated calls with the same text do not throw and stay consistent (cache path)',
      () async {
        const String input = 'Reduce nitrogen application by 20%.';
        final String first = await service.translate(
          input,
          sourceLanguage: 'en',
          targetLanguage: 'mr',
        );
        final String second = await service.translate(
          input,
          sourceLanguage: 'en',
          targetLanguage: 'mr',
        );
        expect(first, input);
        expect(second, input);
      },
    );

    test('every supported LanguageOption code round-trips through translate() safely', () async {
      // en, hi, mr, kn, ta, gu, te — KrishiNetra's current supported set
      // (see LanguageOption.supported). None of these should throw even
      // with no key configured.
      const List<String> codes = <String>['en', 'hi', 'mr', 'kn', 'ta', 'gu', 'te'];
      for (final String code in codes) {
        if (code == 'en') continue;
        final String result = await service.translate(
          'Test string',
          sourceLanguage: 'en',
          targetLanguage: code,
        );
        expect(result, isA<String>());
        expect(result, isNotEmpty);
      }
    });
  });
}
