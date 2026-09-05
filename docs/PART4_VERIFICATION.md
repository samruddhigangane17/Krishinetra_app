# KrishiNetra — Part 4 (Sarvam verification + API-key fix)

Scope: pick up the project as received (`KrishiNetra_Part3_Sarvam.zip`),
verify the Sarvam AI integration described in `SARVAM_INTEGRATION.md`
actually matches the code (not just the doc), fix one leftover security
gap, and repackage. No unrelated code was rewritten.

---

## 1. What was found on inspection

The Sarvam integration described in `docs/SARVAM_INTEGRATION.md` was
already fully implemented in the code, not just documented:

- `lib/core/services/sarvam_service.dart` — real `SarvamTranslationService`
  client for Sarvam's `POST /translate` endpoint, key read only from
  `String.fromEnvironment('SARVAM_API_KEY')`, no in-source constant,
  fails soft on every error path, in-memory cache, 12s timeout, 2000-char
  guard, `en/hi/mr/kn/ta/gu/te` (+ `bn/ml/pa/od` for future growth) mapped
  to Sarvam's `xx-IN` codes.
- `lib/core/services/translation_service.dart` — the `TranslationService`
  facade (Sarvam → Bhashini → original text) that `gemini_service.dart`
  actually calls, confirmed at all 5 call sites (chat fallback ×2, offline
  "no internet" note, `_buildSummary`, and the general offline-summary
  translation path).
- `_buildOfflineAssessment` / `_buildSummary` are `Future`-returning and
  both call sites (`analyzeSoilAndRecommend`, twice) correctly `await`
  them.
- `main.dart`, `locale_controller.dart`, `app_localizations.dart`, the
  7 `.arb` files, and every screen file were confirmed byte-identical to
  what Part 2/3 shipped — the Sarvam pass did not touch UI or navigation,
  exactly as its own doc claims.

**Verification performed in this pass** (no Flutter/Dart SDK or network
access is available in this sandbox, same constraint as every prior
pass — see §7 of `LOCALIZATION_AUDIT.md`):

- Brace/paren/bracket balance checked programmatically across all 26
  `lib/**/*.dart` files — all balanced.
- Every `l10n.<key>` call site in `lib/` cross-checked against
  `AppLocalizations`'s defined getters/methods — 56 keys used, all 56
  found defined (59 defined total; 3 are unused helpers, not a gap).
- All 7 `.arb` files confirmed to carry the same 58 keys each — no drift
  between locales.
- Confirmed `translation_service.dart` imports only `bhashini_service.dart`
  + `sarvam_service.dart` (no circular dependency, no import from
  `features/`).
- Confirmed no other file references `_buildOfflineAssessment` or
  `_buildSummary`, so their sync→`Future` signature change (made in the
  Sarvam pass) can't have broken an unseen caller.
- Project-wide grep for hardcoded secret-shaped strings
  (`AQ.`/`AIza`/`sk-` prefixes) across `.dart`/`.yaml`/`.md`/`.txt`/`.json`.

## 2. What was fixed in this pass

**Hardcoded Gemini API key removed.** `kGeminiApiKey` in
`gemini_service.dart` held a live-looking key committed directly in
source. This was flagged as a security finding in `LOCALIZATION_AUDIT.md`
§5, carried forward unfixed in `LOCALIZATION_PART2.md` §4, and carried
forward unfixed again in `SARVAM_INTEGRATION.md` §6 — three passes in a
row deferred it as "unrelated to localization." Since this pass's brief
explicitly requires keeping API keys out of source code, it's fixed now:

- `kGeminiApiKey` is now `''` instead of a real key.
- The resolution order is unchanged (`_envApiKey` from
  `--dart-define=GEMINI_API_KEY=...` first, `kGeminiApiKey` as fallback)
  — only the fallback's *value* changed, not the logic. With no define
  supplied, `GeminiAgriService.isConfigured` is now correctly `false` and
  the app uses the offline rule-based engine, exactly as it already does
  today whenever Gemini is unreachable. No behavior change for anyone
  already supplying `GEMINI_API_KEY` via `--dart-define`.
- This now matches the pattern already used for `SARVAM_API_KEY` and
  `BHASHINI_USER_ID`/`BHASHINI_ULCA_API_KEY` — every credential in the
  project is now dart-define-only, none committed.

One line changed in one file; nothing else in `gemini_service.dart` was
touched.

## 3. Scalability for additional Indian languages

Confirmed the integration needs no code change to add a language beyond
the current 7 — only data:

1. Add an entry to `LanguageOption.supported` in `language_model.dart`.
2. Add the matching `xx-IN` mapping to `_sarvamLanguageCodes` in
   `sarvam_service.dart` (4 of the 22 scheduled languages — `bn`, `ml`,
   `pa`, `od` — are already mapped ahead of need; any code missing from
   the map still works via the `'$isoCode-IN'` fallback in
   `_toSarvamCode`).
3. Add a new `lib/l10n/app_<code>.arb` file with the same 58 keys (for
   static UI chrome) — `sarvam-translate:v1` itself already covers all
   22 scheduled languages with no per-language model switch, so the AI-
   generated report/chat content needs no further work.

## 4. Known gaps (unchanged from `SARVAM_INTEGRATION.md` §6, not this pass's scope)

- Deterministic fertilizer/schedule/organics/Do's/Don'ts strings and
  `SoilHealthStatus.label` are still English-only.
- `soil_scan_screen.dart`, `recommendation_report_screen.dart`,
  `chatbot_screen.dart`, `schemes_screen.dart` still use hardcoded
  English UI chrome (translating *content* via `translationService` is
  wired; translating each screen's own static labels is the Part 2 scope
  that was explicitly deferred).
- `answerQuickPrompt` still accepts a `language` parameter it doesn't
  use.
- No live network call to `api.sarvam.ai` or `generativelanguage.googleapis.com`
  could be executed in this sandbox (no outbound network access) — a real
  run with `flutter run --dart-define=SARVAM_API_KEY=... --dart-define=GEMINI_API_KEY=...`
  on a machine with Flutter and network access is still needed to confirm
  the end-to-end translated report text, same action item every prior
  pass has flagged.

## 5. Action needed on your machine / CI

```bash
cd krishinetra
flutter pub get
flutter analyze
flutter run --dart-define=SARVAM_API_KEY=your_sarvam_key --dart-define=GEMINI_API_KEY=your_gemini_key
```

Without either define, the app runs exactly as before: Gemini falls back
to the offline rule-based engine, and that engine's non-English summary
falls back to Bhashini (if configured) or plain English — no crash, no
missing feature, just less translation coverage.
