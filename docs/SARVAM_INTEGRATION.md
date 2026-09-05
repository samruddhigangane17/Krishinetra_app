# KrishiNetra — Sarvam AI Integration

Scope: wire a real Sarvam AI translation client into the existing
localization architecture (`LocaleController` / `AppLocalizations` /
`BhashiniTranslationService`), and use it to close the one gap both
prior audits (`LOCALIZATION_AUDIT.md`, `LOCALIZATION_PART2.md`) flagged
as unaddressed: the offline agronomy engine's non-Hindi, non-English
farmers previously saw an untranslated English summary plus an
apologetic parenthetical instead of real content in their language. No
existing UI, screen, or unrelated behaviour was changed.

---

## 1. Files changed

**New**
- `lib/core/services/sarvam_service.dart` — `SarvamTranslationService`,
  a clean client for Sarvam's official `POST /translate` REST endpoint.
- `lib/core/services/translation_service.dart` — `TranslationService`,
  a thin facade: Sarvam first, Bhashini as a fail-soft secondary,
  original text last. This is the one entry point other code should call.
- `docs/SARVAM_INTEGRATION.md` — this file.

**Edited**
- `lib/features/recommendation/data/gemini_service.dart` — the offline
  rule-based engine now calls `translationService` instead of leaving
  non-Hindi languages in English:
  - `_buildSummary` (renders the report's agronomist-summary paragraph
    when Gemini isn't configured/reachable) — the old "(An AI-generated
    summary in {language} will appear here once this app is connected
    to a live Gemini API key...)" placeholder is gone; the English base
    summary is now actually translated.
  - The "no internet, photo couldn't be analyzed" note in
    `_buildOfflineAssessment` — was Hindi-or-English only, now
    translated for every supported language.
  - `chat()`'s two fallback messages ("AI assistant isn't reachable" /
    "couldn't get an answer") — same Hindi-or-English-only gap, same fix.
  - `_buildOfflineAssessment` and `_buildSummary` changed from
    synchronous to `Future`-returning so they can `await` a translation;
    both existing call sites were updated to `await` them. No other
    signature, field, or return type in the file changed.
- `RUN_INSTRUCTIONS.txt` — appended a short "Sarvam AI integration"
  section with the run command; the existing Part 2 notes above it are
  untouched.

**Not touched:** `bhashini_service.dart` (still fully functional, now
actually used — see §4), `main.dart`, `locale_controller.dart`,
`app_localizations.dart`/`l10n_strings.g.dart`/`app_*.arb`, every
screen/widget file, `pubspec.yaml`, and the Gemini *online* call path
(`_callGeminiApi`, `buildAgronomistPrompt`, `answerQuickPrompt`) — all
byte-identical to the project as received.

---

## 2. Dependency added

**None.** Sarvam AI publishes official Python and JavaScript SDKs, but
no Dart/Flutter SDK exists, so — exactly like the existing
`BhashiniTranslationService` — `SarvamTranslationService` talks to
Sarvam's plain REST API using the `http` package, which was already a
project dependency (`http: ^1.2.2` in `pubspec.yaml`). `pubspec.yaml`
is unchanged.

---

## 3. Environment variable required

**`SARVAM_API_KEY`** — passed at build/run time via
`--dart-define=SARVAM_API_KEY=your_key`, read with
`String.fromEnvironment('SARVAM_API_KEY')` in `sarvam_service.dart`.

- Never hardcoded, never committed — there is no in-source constant to
  paste a key into (unlike the legacy `kBhashiniUserId`/
  `kBhashiniUlcaApiKey` pattern in `bhashini_service.dart`, which this
  pass deliberately did not imitate for the new service).
- If the variable is absent or blank, `SarvamTranslationService
  .isConfigured` is `false` and every Sarvam call becomes a safe
  no-op — `TranslationService` falls through to Bhashini, then to the
  original text. The app behaves exactly as it did before this pass
  when no key is supplied.
- Get a key at https://dashboard.sarvam.ai.

---

## 4. How Sarvam is called

`SarvamTranslationService` calls Sarvam's official text-translation
endpoint documented at
https://docs.sarvam.ai/api-reference/text/translate-text:

```
POST https://api.sarvam.ai/translate
Content-Type: application/json
api-subscription-key: <SARVAM_API_KEY>

{
  "input": "Your soil health score is 82/100 (Good)...",
  "source_language_code": "en-IN",
  "target_language_code": "mr-IN",
  "model": "sarvam-translate:v1",
  "mode": "formal"
}
```

Response: `{ "request_id": "...", "translated_text": "...",
"source_language_code": "en-IN" }` — `translated_text` is what's used;
anything else (error status, timeout, malformed body) causes the
original text to be returned instead (see §5).

- **Model**: `sarvam-translate:v1` — covers all 22 scheduled Indian
  languages, so it needs no per-language model switch and already
  covers every language KrishiNetra offers (`hi`, `mr`, `kn`, `ta`,
  `gu`, `te`) plus English.
- **Language codes**: `LanguageOption.code` (`en`, `hi`, `mr`, `kn`,
  `ta`, `gu`, `te` — the existing model, unchanged) is mapped to
  Sarvam's `xx-IN` codes (`en-IN`, `hi-IN`, ...) internally by
  `SarvamTranslationService._toSarvamCode`. Callers never deal with
  Sarvam's code format directly.
- **Batching**: Sarvam's `/translate` endpoint accepts one `input`
  string per call (no native batch endpoint, unlike Bhashini's
  inference API). `translateBatch` issues one request per uncached
  string, run concurrently via `Future.wait` so total latency stays
  close to a single round trip rather than N sequential ones.
- **Caching**: an in-memory `Map<String, String>` keyed by
  `sourceCode|targetCode|text`, shared by the single app-wide
  `sarvamTranslationService` instance — re-rendering the same report or
  re-selecting the same language never re-hits the API for text already
  translated this session. (Process-lifetime only, matching Bhashini's
  existing cache — no disk/database persistence.)
- **Timeout**: 12 seconds per request (`http`'s `.timeout(...)`),
  slightly tighter than Bhashini's 15s since a single short string is
  cheaper than the two-step pipeline-discovery-then-inference wait
  Bhashini needs.
- **Error handling**: every failure mode — missing/invalid key (403),
  bad request (400/422), rate limit (429), server error (500), timeout,
  or an unparseable response — is caught inside `_translateOne` and
  logged (`print`, `avoid_print`-suppressed, matching the rest of the
  codebase's error-logging style); the original text is returned for
  that string. One string failing never blanks out or throws for the
  rest of a batch.
- **Length guard**: Sarvam caps `input` at 2000 characters for
  `sarvam-translate:v1`; any string longer than that is left
  untranslated rather than sent to a call that would 400/422.

### Fallback chain (`TranslationService`, reusing the existing architecture)

```
translationService.translate(text, sourceLanguage: 'en', targetLanguage: lang)
  1. Sarvam configured?  → try Sarvam. Any string actually translated → return it.
  2. Bhashini configured? → try Bhashini (existing service, now actually called).
  3. → return the original text unchanged.
```

`LocaleController`/`LanguageOption` are untouched — they still decide
*which* language the UI wants; `TranslationService` only decides *how*
a given string gets there, exactly reusing rather than replacing the
existing architecture.

---

## 5. How to run it

```bash
cd krishinetra
flutter pub get
flutter run --dart-define=SARVAM_API_KEY=your_sarvam_key
```

For a web/release build:

```bash
flutter build web --dart-define=SARVAM_API_KEY=your_sarvam_key
```

Without the flag, the app runs exactly as it did before this pass
(offline engine falls back to Bhashini, then to English) — no key means
no behaviour change, not a crash.

### Testing performed

No Flutter/Dart SDK or outbound network access to `api.sarvam.ai` is
available in the sandbox that prepared this ZIP (same constraint noted
in both prior audits for `flutter analyze`), so a live end-to-end call
could not be executed here. What was verified instead:

- The exact request/response shape (`/translate`, `api-subscription-key`
  header, `input`/`source_language_code`/`target_language_code`/`model`
  fields, `translated_text` response field) was confirmed against
  Sarvam's own current API reference documentation
  (https://docs.sarvam.ai/api-reference/text/translate-text) at the
  time of writing, not reconstructed from memory.
- Every file touched was checked for brace/paren/bracket balance and for
  every new `await`/`Future<...>` signature change being reflected at
  its call site (both `_buildOfflineAssessment` call sites in
  `analyzeSoilAndRecommend`, and `_buildSummary`'s one call site).
- Confirmed `sarvam_service.dart` and `translation_service.dart` import
  cleanly into `gemini_service.dart`'s existing import block with no
  circular dependency (`translation_service.dart` imports
  `bhashini_service.dart` + `sarvam_service.dart` only; neither of those
  imports anything from `features/`).
- Confirmed no other file in the project references
  `_buildOfflineAssessment`/`_buildSummary`, so the signature change
  (sync → `Future`) can't have broken an unseen caller.

**Action needed on your machine / CI, same as prior passes**: run
`flutter pub get && flutter analyze` before merging, and do a live run
with a real `SARVAM_API_KEY` to confirm the translated report text
end-to-end — that step needs network access this sandbox doesn't have.

---

## 6. Known gaps / next steps (unchanged scope, flagged for later)

- Sarvam is wired into the offline engine's summary + fallback strings
  only, per this pass's brief. The deterministic fertilizer/schedule/
  organics/Do's/Don'ts strings, `SoilHealthStatus.label`, and the four
  screens flagged in `LOCALIZATION_PART2.md` §4
  (`soil_scan_screen.dart`, `recommendation_report_screen.dart`,
  `chatbot_screen.dart`, `schemes_screen.dart`) are still English-only —
  now that `translationService` exists, wiring those in is a much
  smaller follow-up than building the client was.
- `answerQuickPrompt` in `gemini_service.dart` still accepts a
  `language` parameter it doesn't use (pre-existing gap, noted in
  `LOCALIZATION_AUDIT.md` §5) — left untouched this pass to keep the
  change set focused.
- The hardcoded Gemini API key (`kGeminiApiKey`) flagged in
  `LOCALIZATION_AUDIT.md` §5 is still unrotated — unrelated to this
  pass, still worth fixing separately.
