import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for [Sarvam AI](https://www.sarvam.ai)'s official `/translate`
/// REST endpoint (https://docs.sarvam.ai/api-reference/text/translate-text)
/// — KrishiNetra's primary text translator, used for exactly the same
/// farmer-facing content [BhashiniTranslationService] targets (offline
/// agronomy-engine strings, chat fallbacks, and — once wired further —
/// deterministic report content) into the farmer's selected Indian
/// language.
///
/// Sarvam AI requires an `api-subscription-key` header on every request
/// (see https://docs.sarvam.ai/api-reference/authentication). **The key is
/// never hardcoded here.** It's read exclusively from the
/// `SARVAM_API_KEY` environment variable, supplied at build/run time via
/// `--dart-define=SARVAM_API_KEY=your_key` (or the equivalent entry in a
/// CI secret / `--dart-define-from-file`). There is no in-source constant
/// to paste a key into, unlike the legacy Bhashini service — if the
/// variable isn't set, [isConfigured] is `false` and every call is a safe
/// no-op that returns the original text.
///
/// ## Request shape
/// `POST https://api.sarvam.ai/translate`
/// ```json
/// {
///   "input": "Your soil health score is 82/100.",
///   "source_language_code": "en-IN",
///   "target_language_code": "mr-IN",
///   "model": "sarvam-translate:v1",
///   "mode": "formal"
/// }
/// ```
/// `sarvam-translate:v1` is used because it covers all 22 scheduled Indian
/// languages (including every language KrishiNetra offers — hi, mr, kn,
/// ta, gu, te) with a single model, so no per-language model switching is
/// needed.
///
/// Every public method fails soft: on a missing key, timeout, non-200
/// response, or any parsing error, the original (untranslated) text is
/// returned unchanged rather than throwing — the exact same "always show
/// *something* useful" contract as [BhashiniTranslationService], so
/// callers never need a separate error branch.
final class SarvamTranslationService {
  SarvamTranslationService();

  /// Set at build/run time, e.g.
  /// `flutter run --dart-define=SARVAM_API_KEY=your_key` (or the release/
  /// CI equivalent). Never hardcoded, never committed.
  static const String _envApiKey = String.fromEnvironment('SARVAM_API_KEY');

  static const String _endpoint = 'https://api.sarvam.ai/translate';

  /// `sarvam-translate:v1` covers all 22 scheduled Indian languages
  /// (mayura:v1 would also work for KrishiNetra's current 6 target
  /// languages, but sarvam-translate:v1 needs no model switch if more
  /// languages are added later).
  static const String _model = 'sarvam-translate:v1';

  static const Duration _timeout = Duration(seconds: 12);

  bool get isConfigured => _envApiKey.trim().isNotEmpty;

  /// Exact-text translation cache (keyed by source|target|text), so
  /// re-rendering the same report/screen — or asking the same question
  /// twice — never re-hits the API for text already translated this
  /// session.
  final Map<String, String> _textCache = <String, String>{};

  /// Maps KrishiNetra's plain ISO codes (`en`, `hi`, `mr`, `kn`, `ta`,
  /// `gu`, `te`, as used by [LanguageOption]/[LocaleController]) to the
  /// `xx-IN` codes Sarvam's API expects (`en-IN`, `hi-IN`, ...). Falls
  /// back to `en-IN` for anything unrecognized rather than sending an
  /// invalid code to the API.
  static const Map<String, String> _sarvamLanguageCodes = <String, String>{
    'en': 'en-IN',
    'hi': 'hi-IN',
    'mr': 'mr-IN',
    'kn': 'kn-IN',
    'ta': 'ta-IN',
    'gu': 'gu-IN',
    'te': 'te-IN',
    'bn': 'bn-IN',
    'ml': 'ml-IN',
    'pa': 'pa-IN',
    'od': 'od-IN',
  };

  String _toSarvamCode(String isoCode) => _sarvamLanguageCodes[isoCode] ?? '$isoCode-IN';

  /// Translates a single string from [sourceLanguage] to [targetLanguage]
  /// (plain ISO codes, e.g. `en` -> `mr`). Returns [text] unchanged if the
  /// languages match, the text is blank, Sarvam isn't configured, or the
  /// call fails for any reason.
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty || sourceLanguage == targetLanguage) return text;
    final List<String> result = await translateBatch(
      <String>[text],
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    return result.first;
  }

  /// Translates several strings, one Sarvam request per string (the
  /// `/translate` endpoint accepts one `input` string per call — unlike
  /// Bhashini's inference API). Requests run concurrently via
  /// [Future.wait] to keep total latency close to one round trip rather
  /// than N sequential ones.
  ///
  /// Returns [texts] unchanged (same length/order) if Sarvam isn't
  /// configured. If [sourceLanguage] equals [targetLanguage], the inputs
  /// are returned unchanged too — no need to round-trip identical
  /// languages through the API.
  Future<List<String>> translateBatch(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (texts.isEmpty || sourceLanguage == targetLanguage) return texts;
    if (!isConfigured) return texts;

    final String sourceCode = _toSarvamCode(sourceLanguage);
    final String targetCode = _toSarvamCode(targetLanguage);

    final List<String> results = List<String>.from(texts);
    final List<Future<void>> pending = <Future<void>>[];

    for (int i = 0; i < texts.length; i++) {
      final String text = texts[i];
      if (text.trim().isEmpty) continue;

      final String cacheKey = _cacheKey(sourceCode, targetCode, text);
      final String? cached = _textCache[cacheKey];
      if (cached != null) {
        results[i] = cached;
        continue;
      }

      // Sarvam's `/translate` input is capped at 2000 characters for
      // sarvam-translate:v1; anything longer is left untranslated rather
      // than sent to a call guaranteed to 400/422.
      if (text.length > 2000) continue;

      pending.add(
        _translateOne(text, sourceCode: sourceCode, targetCode: targetCode).then((
          String translated,
        ) {
          results[i] = translated;
          _textCache[cacheKey] = translated;
        }),
      );
    }

    if (pending.isNotEmpty) {
      // Each individual call already fails soft (see [_translateOne]), so
      // this never throws — one bad string just leaves its own result
      // untouched rather than blanking out the whole batch.
      await Future.wait(pending);
    }

    return results;
  }

  Future<String> _translateOne(
    String text, {
    required String sourceCode,
    required String targetCode,
  }) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'api-subscription-key': _envApiKey,
            },
            body: jsonEncode({
              'input': text,
              'source_language_code': sourceCode,
              'target_language_code': targetCode,
              'model': _model,
              'mode': 'formal',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
          'Sarvam translate returned ${response.statusCode} for '
          '$sourceCode->$targetCode: ${response.body}',
        );
        return text;
      }

      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      final String? translated = body['translated_text'] as String?;
      return (translated != null && translated.trim().isNotEmpty) ? translated.trim() : text;
    } on TimeoutException {
      // ignore: avoid_print
      print('Sarvam translate timed out for $sourceCode->$targetCode.');
      return text;
    } catch (error) {
      // ignore: avoid_print
      print('Sarvam translate failed for $sourceCode->$targetCode: $error');
      return text;
    }
  }

  String _cacheKey(String sourceCode, String targetCode, String text) =>
      '$sourceCode|$targetCode|$text';
}

/// App-wide singleton — every screen/service shares one Sarvam client (and,
/// importantly, its translation cache), the same pattern as
/// [BhashiniTranslationService]'s own singleton in `bhashini_service.dart`.
final SarvamTranslationService sarvamTranslationService = SarvamTranslationService();
