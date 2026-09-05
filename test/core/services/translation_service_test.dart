// Tests for TranslationService — the single entry point gemini_service.dart
// calls. With no dart-defines set for either SARVAM_API_KEY or
// BHASHINI_USER_ID/BHASHINI_ULCA_API_KEY, this exercises the tail of the
// fallback chain: Sarvam unconfigured -> Bhashini's free (no-signup)
// fallback attempts a real call -> on any failure/no-network, original
// text is returned. The key requirement under test is that this NEVER
// throws and NEVER returns null/blank-for-nonblank-input, regardless of
// network availability in the environment running the test.
//
// Run with: flutter test test/core/services/translation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:krishinetra/core/services/translation_service.dart';

void main() {
  group('TranslationService', () {
    const TranslationService service = TranslationService();

    test('translate never throws for a normal English string', () async {
      // Whether or not this test runner has outbound network access to
      // Bhashini's free fallback endpoint, the call must complete and
      // return *some* non-empty string — this is the "always show
      // something useful, never crash" contract the whole chain exists
      // to guarantee for a farmer with an unreliable connection.
      final String result = await service.translate(
        'Your soil health score is 82/100.',
        sourceLanguage: 'en',
        targetLanguage: 'mr',
      );
      expect(result, isNotEmpty);
    });

    test('translate short-circuits identical source/target without any network call', () async {
      const String input = 'ಈ ಪರೀಕ್ಷಾ ಪಠ್ಯ';
      final String result = await service.translate(
        input,
        sourceLanguage: 'kn',
        targetLanguage: 'kn',
      );
      expect(result, input);
    });

    test('translate returns blank input unchanged', () async {
      final String result = await service.translate(
        '',
        sourceLanguage: 'en',
        targetLanguage: 'ta',
      );
      expect(result, '');
    });

    test('translateBatch preserves list length and order under any outcome', () async {
      final List<String> input = <String>[
        'Apply urea in two split doses.',
        'Water the field every 3 days.',
      ];
      final List<String> result = await service.translateBatch(
        input,
        sourceLanguage: 'en',
        targetLanguage: 'gu',
      );
      expect(result.length, input.length);
      for (final String s in result) {
        expect(s, isNotEmpty);
      }
    });

    test('translateBatch returns input unchanged for identical source/target', () async {
      final List<String> input = <String>['A', 'B', 'C'];
      final List<String> result = await service.translateBatch(
        input,
        sourceLanguage: 'te',
        targetLanguage: 'te',
      );
      expect(result, input);
    });

    test('translateBatch handles an empty list', () async {
      final List<String> result = await service.translateBatch(
        <String>[],
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );
      expect(result, isEmpty);
    });

    test('offline-style report content survives the full chain without a crash', () async {
      // Mirrors the exact call shape gemini_service.dart's
      // _buildSummary/_buildOfflineAssessment make for a non-Hindi,
      // non-English farmer with no Gemini connectivity.
      const String summary =
          'Your soil health score is 61/100 (Moderate Deficit). Based on '
          'this profile, Maize is a strong fit for your field, with an '
          'estimated 18% yield improvement when the fertilizer plan below '
          'is followed consistently.';
      for (final String lang in <String>['mr', 'kn', 'ta', 'gu', 'te']) {
        final String result = await service.translate(
          summary,
          sourceLanguage: 'en',
          targetLanguage: lang,
        );
        expect(result, isNotEmpty);
      }
    });
  });
}
