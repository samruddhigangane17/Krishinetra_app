# KrishiNetra — Localization Part 2 (UI localization)

Scope, per the Part 2 brief: **splash, landing, login, language selection,
dashboard, navigation, settings**. `soil_scan_screen`, the recommendation
report screen, `chatbot_screen`, and `schemes_screen` were intentionally
left untouched (out of scope — flagged in the Part 1 audit as ~90 more
strings to localize in a later pass). Sarvam integration was explicitly
out of scope for this pass and was not touched.

---

## 1. What changed

### Localization runtime (new)
No Flutter SDK / network access is available in this sandbox, so
`flutter gen-l10n` codegen from `.arb` files isn't runnable here (same
constraint noted in the Part 1 audit, §7). Instead:

- **`lib/l10n/app_*.arb`** (7 files, from Part 1) stay the
  translator-facing source of truth — one JSON file per locale, 58 keys
  each, with `@key` description/placeholder metadata on the English file.
- **`lib/l10n/l10n_strings.g.dart`** (generated) — a plain
  `Map<String, Map<String, String>>` of every string, keyed by locale
  then message key.
- **`lib/l10n/app_localizations.dart`** (generated getter list, hand-authored
  class/delegate shape) — a small hand-rolled `AppLocalizations` class +
  `LocalizationsDelegate<AppLocalizations>` that mirrors what
  `flutter gen-l10n` would normally produce: one typed getter per simple
  message (`l10n.getStarted`), one method per message with a placeholder
  (`l10n.welcomeBack(name)`, `l10n.codeSentTo(phone)`,
  `l10n.resendOtpIn(seconds)`). Falls back to English, then to the raw key,
  if a translation is ever missing — never throws or shows a blank string.
- Both generated files are produced by **`gen_dart_l10n.py`** (repo root,
  not shipped in the app) from `l10n_data.json`, which itself comes from
  Part 1's `gen_l10n.py`. Regenerate via `python3 gen_dart_l10n.py` if a
  translation changes — never hand-edit the two generated files.
- **`lib/core/services/locale_controller.dart`** (new) — a single
  `ValueNotifier<Locale>`. `main.dart` wraps `MaterialApp` in a
  `ValueListenableBuilder` on this notifier, so changing it anywhere
  (language-selection screen at onboarding, or the Profile/Settings
  language switcher later) live-updates every localized screen —
  no restart needed.
- **`main.dart`** — wired `locale`, `supportedLocales`, and
  `localizationsDelegates` (`AppLocalizations.delegate` +
  `GlobalMaterialLocalizations`/`GlobalWidgetsLocalizations`/
  `GlobalCupertinoLocalizations`) into `MaterialApp`.
- **`pubspec.yaml`** — added the `flutter_localizations` SDK dependency
  (no `generate: true` / `l10n.yaml` — we deliberately did **not** turn on
  `flutter gen-l10n` codegen, to avoid it generating its own conflicting
  `AppLocalizations` class alongside the hand-rolled one).

### Screens localized
- `splash_screen.dart` — tagline.
- `landing_page.dart` — subtitle, 3 feature chips, "Get Started" button.
- `language_selection_screen.dart` — heading/hint/continue button; the
  previous hand-spliced hardcoded Hindi line
  (`'अपनी भाषा चुनें'` next to the English heading, and
  `'Continue / आगे बढ़ें'`) is gone — the heading now renders in whichever
  locale is currently active, and picking a language sets
  `localeController` immediately.
- `login_screen.dart` — all labels/buttons/banners/errors.
- `dashboard_shell.dart` — nav rail/bar labels (6), Home tab, History tab
  (including per-report `SoilHealthStatus` label via a small
  `_statusLabel()` helper — `SoilHealthStatus.label` itself is untouched
  since the out-of-scope report screen still uses it), and the Profile
  tab, which is this app's Settings surface (language switcher, sign out).
- `app_theme.dart` — added Noto Sans Devanagari/Kannada/Tamil/Telugu/
  Gujarati as a `fontFamilyFallback` on the whole `TextTheme` (Manrope/
  Inter only cover Latin glyphs).

### Service-layer changes (needed for clean localization, not scope creep)
- **`auth_service.dart`**: `AuthFailure` used to carry a hardcoded English
  `message`. Replaced with an `AuthErrorCode` enum
  (`otpSendFailed` / `otpIncomplete` / `verificationFailed` /
  `googleUnavailable`) — the service layer stays locale-agnostic (as it's
  already backend-agnostic), and `login_screen.dart` maps the code to
  `AppLocalizations` text. Also removed `AuthUser.greetingName` (was a
  hardcoded `'Guest Farmer'` / `'Farmer'` fallback baked into the domain
  model); `dashboard_shell.dart` now computes it via a small
  `_greetingName(l10n, user)` helper instead.

## 2. Text-overflow fixes for regional languages

Kannada/Telugu/Tamil/Gujarati strings commonly run 20-40% longer than
their English source (e.g. "Get Started" → "ప్రారంభించండి"). Fixed
concretely, not just in the abstract:

- **Fonts**: added Noto Sans script-family fallbacks (see above) so
  Devanagari/Kannada/Tamil/Telugu/Gujarati glyphs render consistently
  instead of depending on whatever font happens to be on the host system
  (a real risk on a bare web/CI target, not just a device concern).
- **Landing "Get Started" button**: was a hardcoded `width: 320` — longer
  translations would clip. Now a `ConstrainedBox(maxWidth: 320)` +
  `SizedBox(width: double.infinity)`, with the label allowed to wrap to
  2 lines with ellipsis as a last resort.
- **Splash tagline**: was unconstrained single-line; now horizontally
  padded and allowed 2 lines with ellipsis.
- **Nav rail/bar labels**: added `overflow: TextOverflow.ellipsis` (+
  `softWrap: false` on the rail) via both the shared theme
  (`navigationBarTheme`/`navigationRailTheme` label styles) and the
  per-`Text` widgets, so a long translated label truncates instead of
  wrapping into the icon above it or overflowing the fixed nav width.
- **Buttons** (`Get OTP`, `Verify & Proceed`, `Sign in with Google`,
  `Continue`, `Start Scan`, `Sign out`): `maxLines: 1` +
  `TextOverflow.ellipsis` added to each button label; the auth buttons
  already used `minimumSize` (not a fixed `Size`) so they can also grow
  taller if a translation needs to wrap.
- **Profile/Settings rows** (`_ProfileRow`): label and value `Text`
  widgets wrapped in `Flexible` + `ellipsis` instead of bare `Text()` in
  a `Row`, so a longer translated label (or a long email/phone value)
  can't push the row past its bounds.
- **OTP "code sent to" banner**: allowed 2 lines + ellipsis instead of 1,
  since `codeSentTo` + a phone number can run long in some languages.

## 3. `flutter analyze`

**Could not be run** — same constraint as Part 1 (§7 of
`LOCALIZATION_AUDIT.md`): no Flutter SDK and no network access in this
sandbox to fetch one. Substitute manual review performed instead:

- Brace/paren/bracket balance checked programmatically across every file
  touched in this pass, plus every out-of-scope file, to confirm nothing
  was left syntactically broken — all balanced.
- Cross-checked every `l10n.<key>` / `sheetL10n.<key>` call site in `lib/`
  against `AppLocalizations`'s generated getters/methods — no undefined
  key referenced, no defined key left unused-relevant (58/58 match).
- Confirmed no leftover reference to `AuthUser.greetingName` (removed
  this pass) anywhere in `lib/`.
- Confirmed the `.arb` files, `l10n_strings.g.dart`, and
  `app_localizations.dart` all agree on the same 58 keys.
- Reviewed every remaining literal `Text('...')` in touched files by hand
  — the only ones left are non-translatable: the `KrishiNetra` brand name,
  the 🇮🇳 flag emoji + `+91` country code prefix, and the Google `G` glyph.

**Action needed on your machine / CI, same as Part 1**: run
`flutter pub get && flutter analyze` before merging, and paste any
findings back — this manual pass is not a substitute for the real
analyzer (type errors, unused imports it would catch that don't show up
as brace mismatches, etc.).

## 4. Known gaps / next steps

Carried forward from the Part 1 audit, unchanged by this pass (all
explicitly out of scope for Part 2):
- `soil_scan_screen.dart`, `recommendation_report_screen.dart`,
  `chatbot_screen.dart`, `schemes_screen.dart` remain English-only.
- `SoilHealthStatus.label` (used by the report screen) is still
  hardcoded English — `dashboard_shell.dart`'s History tab now uses its
  own localized `_statusLabel()` instead of touching the shared getter,
  so the two will need reconciling whenever the report screen is
  localized.
- `BhashiniTranslationService` is still fully built but unwired.
- Sarvam is not integrated (explicitly out of scope for this pass).
- The hardcoded Gemini API key flagged in Part 1 is still unrotated —
  unrelated to localization, still worth fixing separately.
