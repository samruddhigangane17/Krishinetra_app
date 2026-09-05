# KrishiNetra — Localization Audit (Part 1)

Scope: full audit of the Flutter app under `lib/`. No functional or
structural changes were made as part of this pass — this is a read-only
inventory to plan localization work against.

---

## 1. Screens & widgets inventory

| Layer | File | Role |
|---|---|---|
| Entry | `lib/main.dart` | App root, wires Splash → Landing |
| Screen | `features/auth/presentation/pages/splash_screen.dart` | Animated branded splash |
| Screen | `features/landing/landing_page.dart` | Marketing/entry screen, "Get Started" |
| Screen | `features/auth/presentation/pages/language_selection_screen.dart` | Onboarding language picker (grid of 7 languages) |
| Screen | `features/auth/presentation/pages/login_screen.dart` | Phone OTP / Google / Guest sign-in |
| Shell | `features/dashboard/dashboard_shell.dart` | Bottom-nav / rail shell with 6 tabs: Home, Scan, Chat, Schemes, History, Profile. Also contains `_Home`, `_History`, `_Profile` tab bodies inline |
| Screen | `features/recommendation/presentation/pages/soil_scan_screen.dart` | N/P/K/pH + photo + crop + fertilizer-history input form |
| Screen | `features/recommendation/presentation/pages/recommendation_report_screen.dart` | Soil health report: score, summary, fertilizer plan, timeline, organics, Do's/Don'ts, "Ask Agronomist" panel, disease card, share/save |
| Screen | `features/chatbot/presentation/pages/chatbot_screen.dart` | Open-ended farming assistant chat |
| Screen | `features/schemes/presentation/pages/schemes_screen.dart` | Static reference list of 8 Government of India farmer schemes |
| Model | `features/auth/domain/models/language_model.dart` | `LanguageOption` (code/nativeName/englishName), 7 supported languages |
| Model | `features/recommendation/domain/models/soil_models.dart` | `SoilHealthAssessment`, `SoilHealthStatus` (has hardcoded English `.label` getter), `SoilInputs`, `FertilizerHistoryEntry`, etc. |
| Service | `core/services/auth_service.dart` | Mock phone/Google/guest auth, hardcoded English status/error strings |
| Service | `core/services/report_history_store.dart` | In-memory report history (no strings) |
| Service | `core/services/bhashini_service.dart` | Bhashini + Google-Translate-fallback text translator (see §4) |
| Service | `features/recommendation/data/gemini_service.dart` | Gemini API client + offline rule-based agronomy engine (see §3, §5) |
| Widgets | `core/widgets/{ui_kit,app_common_widgets,branded_logo_header,radar_pulse_loader}.dart` | Shared chrome; `app_common_widgets.dart` and `branded_logo_header.dart` each contain one hardcoded `Text(...)` |
| Theme | `core/theme/app_theme.dart` | Colors/typography only, no strings |

Total: **9 screens**, 2 domain models with UI-facing strings, 4 services, 5 shared-widget files.

---

## 2. Hard-coded UI text

**No localization framework is wired into the project at all** — no
`flutter_localizations`, no `.arb` files, no `intl_utils`/codegen, no
`AppLocalizations.of(context)` pattern anywhere in `lib/`. `intl: ^0.19.0`
is a dependency but is used only for `DateFormat` (date formatting in
`dashboard_shell.dart`'s History tab), never for message translation.

Every user-facing string in the UI layer (buttons, labels, headers,
hints, empty states, snackbars, nav-rail/nav-bar labels) is an inline
English string literal passed straight to `Text(...)` or an
`InputDecoration`. Counted literal `Text('...')` calls per file:

| File | Hardcoded `Text()` strings |
|---|---:|
| `recommendation_report_screen.dart` | ~26 |
| `soil_scan_screen.dart` | ~17 |
| `dashboard_shell.dart` | ~15 (incl. the 6 nav labels `Home/Scan/Chat/Schemes/History/Profile`) |
| `login_screen.dart` | ~14 |
| `schemes_screen.dart` | 4 static header/disclaimer strings, **plus a fully English static content block** — 8 scheme entries × 5 string fields each (name, summary, benefit, eligibility, portal) = ~40 more strings, all hardcoded as `const` data |
| `language_selection_screen.dart` | 4 (ironically, the language picker screen's own copy is English/Hindi-mixed, not localized per selection) |
| `chatbot_screen.dart` | 2 UI strings + 4 hardcoded English suggestion chips |
| `landing_page.dart` | 1 (+3 feature-chip labels as const data) |
| `main.dart` | 1 (`title: 'KrishiNetra'`) |
| `soil_models.dart` | 3 (`SoilHealthStatus.label`: "Optimal" / "Moderate Deficit" / "Critical Deficit") |
| `auth_service.dart` | ~6 (guest/display names, all error and status messages) |
| `app_common_widgets.dart`, `branded_logo_header.dart` | 1 each |

**Notable pattern:** several screens hand-splice a single hardcoded
Hindi string next to the English one, e.g. `login_screen.dart`'s
`Text('Get OTP / OTP प्राप्त करें')` and `Text('Welcome Farmer / किसान
आपका स्वागत है')`, and `language_selection_screen.dart`'s
`Text('Continue / आगे बढ़ें')`. This only covers Hindi and only for a
handful of strings — Marathi, Kannada, Tamil, Gujarati, and Telugu
farmers (5 of the 7 selectable languages) see no translated UI chrome
anywhere, and even Hindi-selecting farmers only get it on these few
specific strings, not the rest of the screen.

---

## 3. Current language system

- `LanguageOption` (`language_model.dart`) defines 7 languages: English,
  Hindi, Marathi, Kannada, Tamil, Gujarati, Telugu — code, native name,
  English name only. No string-catalog concept exists on this model.
- `LanguageSelectionScreen` lets the farmer pick one at onboarding; the
  choice is passed forward through `LandingPage → LoginScreen →
  DashboardShell(selectedLanguage:)`.
- `DashboardShell` holds the chosen `LanguageOption` as mutable state
  (`_language`) and exposes an in-app switcher on the Profile tab
  (`_openLanguagePicker`), so it *can* change live without restart.
- **However, that `_language` value is only ever threaded into two
  places:** `SoilScanScreen`/`RecommendationReportScreen` →
  `GeminiAgriService` (as a "respond in this language" prompt
  instruction, §5) and `ChatbotScreen` → `GeminiAgriService.chat`. It is
  **never** applied to any static widget text.
  - `SchemesScreen` isn't even given the language (`const SchemesScreen()`,
    no parameter) — it is 100% English, unconditionally, for every
    selected language.
  - The Home tab only displays the selected language's **name** as a
    label (`Text(language)` next to a translate icon) — it does not
    translate the tab's own content into that language.
  - Nav-rail/nav-bar labels (`Home/Scan/.../Profile`), all form field
    labels, all headers, all buttons, all empty-state copy: English
    regardless of selection.
- There is no `Locale`/`MaterialApp.locale`/`supportedLocales` set on
  `MaterialApp` in `main.dart` — the app never participates in Flutter's
  own localization/RTL/pluralization machinery at all.

**Bottom line:** language selection today only steers *AI-generated*
content (Gemini's summary/chat text), not the app's own UI chrome or the
static Schemes content.

---

## 4. Bhashini / Google Translate integration

`core/services/bhashini_service.dart` defines a complete,
well-documented `BhashiniTranslationService`:

- Two-step Bhashini flow (pipeline-config discovery, then inference)
  using the public MeitY pipeline ID, gated behind a `kBhashiniUserId` /
  `kBhashiniUlcaApiKey` placeholder pair (currently unset —
  `isConfigured` is `false` by default) or matching `--dart-define`s.
- Automatic fallback to the **unofficial/unauthenticated Google
  Translate web endpoint** (`translate.googleapis.com/translate_a/single`)
  whenever Bhashini isn't configured or a Bhashini call fails — used
  today as the de-facto default path.
- Both single-string (`translate`) and batched (`translateBatch`) entry
  points, with an in-memory pipeline-config cache and an in-memory
  translated-text cache.
- Fails soft everywhere: on any error it returns the original
  (untranslated) text rather than throwing.

**This service is fully built but completely unwired.** A repo-wide
search confirms `bhashiniTranslationService` / `BhashiniTranslationService`
are referenced only inside `bhashini_service.dart` itself (its own
definition + the singleton) — no screen, widget, or other service ever
calls `.translate(...)` or `.translateBatch(...)`. It is dead code from
the UI's perspective today, sitting ready for the next phase.

There is a second, narrower "translation" surface inside
`gemini_service.dart` itself: the *offline* rule-based engine's
`_buildAgronomistSummary` special-cases `language.code == 'hi'` with a
hand-written Hindi paragraph, and for every other non-English language
falls back to English plus an apologetic parenthetical ("An AI-generated
summary in {language} will appear here once this app is connected to a
live Gemini API key..."). This is exactly the gap Bhashini was written
to close but isn't yet plugged into.

---

## 5. Gemini / chatbot

`features/recommendation/data/gemini_service.dart` (839 lines) is the
single Gemini touchpoint, used from two call sites:

1. **Soil analysis** (`SoilScanScreen` → `analyzeSoilAndRecommend`):
   builds a structured agronomist prompt (`buildAgronomistPrompt`)
   that explicitly asks Gemini to *"Respond in {language.englishName}
   ({language.nativeName})"* and requests strict JSON back
   (`agronomistSummary`, `healthScore`, `diseaseName`,
   `diseaseTreatment`). On success this is merged with **deterministic,
   English-only** locally-computed pieces — fertilizer dosages,
   schedule, organic alternatives, Do's/Don'ts, recommended crop — which
   are never translated regardless of language (see `_buildDos`,
   `_buildDonts`, `_buildSchedule`, etc., all hardcoded English string
   builders). So even a fully-configured Gemini call only localizes the
   summary paragraph and disease name/treatment; the rest of the report
   stays English.
2. **Chat** (`ChatbotScreen` → `chat`): also asks Gemini to respond in
   the selected language; the "AI unreachable" fallback message is
   hand-translated for Hindi only (`language.code == 'hi'`), English for
   everything else.
3. **Quick-prompt** (`RecommendationReportScreen`'s "Ask Agronomist" →
   `answerQuickPrompt`): entirely canned, keyword-matched English
   strings (nitrogen/irrigation/pH/phosphorus/potassium/disease); the
   `language` parameter is accepted but **not used** to vary the answer
   language at all (confirmed by inspection — no `language.code` branch
   exists in this method body).

**Offline fallback engine:** when `isConfigured` is `false` or the live
call throws, `_buildOfflineAssessment` produces a fully deterministic
report — same English-only fertilizer/schedule/organics/Do's/Don'ts
logic, plus the Hindi-or-English-only summary noted in §4. This is the
path exercised by default today, because of the finding below.

**Security finding — hardcoded API key:** `kGeminiApiKey` in
`gemini_service.dart` contains what appears to be a live-looking Gemini
API key string committed directly in source
(`const String kGeminiApiKey = 'AQ.Ab8RN6...'`). The code prefers
`--dart-define=GEMINI_API_KEY` when present, but falls back to this
committed constant otherwise. **This should be rotated/removed before
any public repo or release build**, independent of the localization
work — flagging it here since it was encountered during this audit, not
fixing it (per "no major changes" scope for Part 1).

Model in use: `gemini-3.6-flash` via the `v1beta` REST endpoint.

---

## 6. Reports / recommendations content

`RecommendationReportScreen` (1734 lines) renders, per report:
- Health score ring + status label (`SoilHealthStatus.label` — English
  only, §2)
- Agronomist summary (partially localized via Gemini/offline engine, §5)
- Disease/pest card (Gemini-sourced name/treatment when present)
- Primary crop recommendation + yield-increase estimate
- Chemical fertilizer dosage table, application timeline, organic
  alternatives — **all English, deterministic, never localized**
- Fertilizer-history context notes + NCONF organic-alternative
  suggestions (from the merged fertilizer-history feature) — English only
- Do's/Don'ts lists — English only
- "Ask Gemini Agronomist" quick-prompt panel (§5)
- Save-to-History and Share-on-WhatsApp actions (WhatsApp share text is
  assembled from the same English strings)

`SchemesScreen` is a fully static, offline-safe reference screen for 8
central government farmer schemes (PM-KISAN, PMFBY, KCC, Soil Health
Card, PM-KMY, e-NAM, PMKSY, MSP) — every field (name, summary, benefit,
eligibility, portal) is a hardcoded English `const` string, and the
screen never receives a `LanguageOption` at all (§3).

---

## 7. `flutter analyze`

**Could not be run in this sandbox** — no Flutter SDK or `dart` binary
is installed in this container, and outbound network access is
disabled, so the SDK could not be fetched either. As a substitute, this
pass did a manual review of all 21 `lib/**/*.dart` files:

- Brace/paren/bracket balance checked programmatically across every
  file — all balanced, no truncated blocks.
- No `.arb` files, no generated localization code, nothing that would
  itself trip codegen-related analyzer errors.
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
  plus `prefer_const_constructors` / `prefer_const_literals_to_create_immutables`.

**Action needed on your machine / CI:** run `flutter pub get && flutter
analyze` before starting Part 2, and paste any findings back in — this
audit's manual pass is not a substitute for the real analyzer, particularly
for type errors, unused-import warnings, or lint violations it would
normally catch.

---

## 8. Summary — what Part 2 needs to solve

1. **No localization framework at all.** Needs `flutter_localizations` +
   `.arb` catalogs (or equivalent) wired into `MaterialApp`, covering all
   ~130+ hardcoded UI strings inventoried in §2 across 9 screens + 5
   shared-widget files + 2 model files + 1 service.
2. **`LanguageOption` selection needs to actually drive UI text**, not
   just the Gemini prompt language — today `SchemesScreen` doesn't even
   receive it, and every other screen ignores it for its own chrome.
3. **`BhashiniTranslationService` is fully built but never called** —
   the natural next step is wiring it in for exactly the content it was
   designed for (the offline engine's non-Hindi fallback, and/or the
   deterministic fertilizer/schedule/organics/Do's/Don'ts strings that
   Gemini never touches).
4. **Deterministic report content (fertilizer plan, timeline, organics,
   Do's/Don'ts, `SoilHealthStatus.label`) is English-only even when
   Gemini is configured and even when Bhashini would be available** —
   this is likely the highest-impact gap for a farmer who selected a
   non-English, non-Hindi language.
5. **Hardcoded Gemini API key** (`kGeminiApiKey`) — flagged as a
   security item, out of scope for this localization pass but should be
   rotated/removed separately.
6. `flutter analyze` should be run in a real Flutter environment before
   Part 2 begins (see §7).
