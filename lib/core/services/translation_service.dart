import 'package:krishinetra/core/services/bhashini_service.dart';
import 'package:krishinetra/core/services/sarvam_service.dart';

/// Single entry point the rest of the app should call for text
/// translation, instead of reaching for [SarvamTranslationService] or
/// [BhashiniTranslationService] directly. Layers both engines behind one
/// fail-soft API so callers never branch on which one is configured:
///
/// 1. **Sarvam AI** ([SarvamTranslationService]) — used first whenever
///    `SARVAM_API_KEY` is configured, since it's KrishiNetra's primary
///    translator (official API, purpose-built for Indian languages).
/// 2. **Bhashini** ([BhashiniTranslationService]) — used as a secondary
///    fallback if Sarvam isn't configured or a Sarvam call fails; keeps
///    the previously-built Bhashini integration meaningful rather than
///    dead code, and gives the app a second independent path to a
///    translated string.
/// 3. **Original text** — if neither is configured or both fail, the
///    untranslated input is returned unchanged. Every call site already
///    has to handle "the text is in English" as a valid outcome (that's
///    the current, working behaviour), so this is never a crash path.
///
/// This mirrors — and reuses — the existing locale architecture:
/// [LocaleController]/[LanguageOption] still decide *which* language the
/// UI wants, this class just decides *how* a given string gets there.
final class TranslationService {
  const TranslationService();

  /// Translates several strings from [sourceLanguage] to [targetLanguage]
  /// (plain ISO codes, e.g. `en` -> `mr`, matching [LanguageOption.code]).
  /// Returns [texts] unchanged (same length/order) if the languages match
  /// or nothing could translate them.
  Future<List<String>> translateBatch(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (texts.isEmpty || sourceLanguage == targetLanguage) return texts;

    if (sarvamTranslationService.isConfigured) {
      try {
        final List<String> result = await sarvamTranslationService.translateBatch(
          texts,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        // Sarvam fails soft internally (returns originals on error), so a
        // successful call that still came back entirely unchanged just
        // means every individual string failed — worth a real attempt via
        // Bhashini rather than accepting untranslated text silently.
        bool anyTranslated = false;
        for (int i = 0; i < texts.length; i++) {
          if (result[i] != texts[i]) {
            anyTranslated = true;
            break;
          }
        }
        if (anyTranslated) return result;
      } catch (error) {
        // ignore: avoid_print
        print('Sarvam batch translation threw, trying Bhashini: $error');
      }
    }

    // Note: no `bhashiniTranslationService.isConfigured` gate here.
    // BhashiniTranslationService.translateBatch already handles the
    // unconfigured case itself — it falls through to a free, no-signup
    // translation endpoint when no real Bhashini credentials are set
    // (see bhashini_service.dart), rather than no-op'ing. Gating on
    // isConfigured here would skip that free fallback entirely and jump
    // straight to returning the original text, which is exactly the
    // "no internet-facing translation at all" state this three-tier
    // chain (Sarvam -> Bhashini -> original text) exists to avoid.
    try {
      return await bhashiniTranslationService.translateBatch(
        texts,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (error) {
      // ignore: avoid_print
      print('Bhashini batch translation failed, using original text: $error');
    }

    return texts;
  }

  /// Translates a single string — see [translateBatch] for the fallback
  /// order. Returns [text] unchanged if the languages match, the text is
  /// blank, or every translator is unavailable/fails.
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
}

/// App-wide singleton facade — the one translation entry point the rest of
/// the app (offline agronomy engine, chat fallbacks, and future screens)
/// should use, instead of reaching for
/// [sarvamTranslationService] / [bhashiniTranslationService].
final TranslationService translationService = TranslationService();
