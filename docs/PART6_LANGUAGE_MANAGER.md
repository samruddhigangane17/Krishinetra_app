# KrishiNetra — Part 6 (Centralized language-selection system)

Scope: continue from `KrishiNetra_Part5_Sarvam.zip`. Add a proper,
centralized language-selection system: one manager that owns the
farmer's selected language, persists it, and drives every screen that
needs it — replacing the manual constructor-by-constructor threading
that existed before this pass. No screen's visual design, no navigation
destination, and no unrelated service/feature was changed.

---

## 1. What existed before this pass

- `LanguageOption` (7 supported languages + an English `defaultLanguage`)
  and `localeController` (a bare `ValueNotifier<Locale>` driving
  `MaterialApp`/`AppLocalizations`) already existed from Parts 2–5.
- But the *farmer's selected `LanguageOption`* itself (as opposed to the
  `Locale` used for static UI text) had no single owner. It was chosen
  once on `LanguageSelectionScreen`, then manually relayed as a
  constructor parameter through `LanguageSelectionScreen.onContinue` →
  `LandingPage`'s navigation closures → `LoginScreen.onAuthenticated` →
  `_DashboardStarter` → `DashboardShell(selectedLanguage:)`, where it was
  copied into local `State` (`_language`) and re-threaded again to
  `SoilScanScreen`, `ChatbotScreen`, `_History`, `_Home`, and `_Profile`.
  Changing it in-app (`_changeLanguage` on the Profile tab) meant
  updating that local copy *and* separately poking `localeController`.
- Nothing was persisted — a killed/restarted app always came back up in
  English, even for a farmer who had already picked Marathi.

This is exactly the "handling language separately on every screen"
pattern this pass's brief asks to replace.

## 2. What was added: `LanguageManager`

**New file**: `lib/core/services/language_manager.dart` — a single
`LanguageManager` singleton (`languageManager`) that is now the one
place in the app that owns the selected language:

- **`selected`** — a `ValueNotifier<LanguageOption>`, defaulting to
  `LanguageOption.defaultLanguage` (English). Any widget can read
  `languageManager.current` once, or wrap itself in a
  `ValueListenableBuilder<LanguageOption>` to rebuild live.
- **`setLanguage(LanguageOption)`** — the one call site for changing the
  language anywhere in the app. It updates `selected` (so every
  listener rebuilds), updates `localeController` internally (so
  `AppLocalizations`-driven static UI text keeps working exactly as
  before — no screen that reads `l10n.*` needed to change), and
  persists the choice.
- **`initialize()`** — called once from `main()` before `runApp`,
  restores a previously persisted language so a returning farmer's app
  opens directly in their language, with no flash of English first.
- **English stays the default** in every failure mode: nothing
  persisted yet, an unrecognized stored code, or a storage error during
  `initialize()`/`setLanguage()` all leave (or fall back to) English —
  never a crash, never a blocked app start.

**Persistence**: `shared_preferences` (added to `pubspec.yaml` — the
only new dependency in this pass) under one key,
`krishinetra.selected_language_code`, storing just the language's ISO
code (`en`/`hi`/`mr`/`kn`/`ta`/`gu`/`te`). This is the standard,
minimal Flutter mechanism for exactly this kind of small persisted
setting, and works across every platform the project already targets
(mobile, web, desktop) without any platform-specific code.

## 3. Screens refactored to use it (prop-drilling removed)

- **`main.dart`** — `main()` is now `async`, calls
  `await languageManager.initialize()` before `runApp`. `MaterialApp`'s
  own `localeController`-driven `ValueListenableBuilder` is untouched —
  `LanguageManager` keeps that in sync internally, so this was a
  2-line change.
- **`language_selection_screen.dart`** — `onContinue` no longer carries
  a `LanguageOption` parameter (`void Function(BuildContext) onContinue`
  instead of `void Function(BuildContext, LanguageOption)`). The
  "Continue" button now calls `await languageManager.setLanguage(selection)`
  (which handles the locale switch that used to be a direct
  `localeController.value = ...` line here) before calling
  `widget.onContinue(context)`.
- **`landing_page.dart`** — the `onContinue`/`onAuthenticated` closure
  chain no longer captures or re-passes a `LanguageOption` at all (it
  was pure relay — this screen never used the value itself).
  `_DashboardStarter` dropped its `language` field entirely; removed the
  now-unused `language_model.dart` import.
- **`dashboard_shell.dart`** — `DashboardShell` no longer takes a
  `selectedLanguage` constructor parameter. `_DashboardShellState`
  dropped its local `_language` field and `_changeLanguage` method
  entirely. `build()` now wraps its content in a
  `ValueListenableBuilder<LanguageOption>` on `languageManager.selected`,
  so the whole dashboard (nav, Home/History/Profile tabs, and the
  `SoilScanScreen`/`ChatbotScreen` it opens) reacts to a language change
  the same way it already reacted before — live, no restart — just from
  one shared source instead of a locally duplicated copy. The
  Profile tab's language picker now calls `languageManager.setLanguage`
  directly instead of a local `_changeLanguage` callback. Removed the
  now-unused `locale_controller.dart` import (still used, just via
  `language_manager.dart` now).

**Deliberately left unchanged**: `SoilScanScreen`, `ChatbotScreen`,
`_History`, `_Profile`, and `RecommendationReportScreen` all still
accept a `LanguageOption language` constructor parameter — that's a
normal, legitimate parameter (they each *use* it, e.g. for the
Gemini/translation-service prompt language), not the prop-drilling
anti-pattern. Only the layers that were purely relaying the value
without using it (`LandingPage`, the onboarding navigation closures,
and `DashboardShell`'s old local copy) were simplified to read from
`languageManager` instead.

## 4. Requirements checklist

- **Language selector on the existing app** — `LanguageSelectionScreen`
  (onboarding) and the Profile-tab picker (in-app) both already existed
  and are unchanged in appearance; both now write through
  `languageManager.setLanguage` instead of a local/direct locale poke.
- **Regional languages relevant to KrishiNetra** — unchanged set of 7:
  English, Hindi, Marathi, Kannada, Tamil, Gujarati, Telugu
  (`LanguageOption.supported`), matching Sarvam's own coverage from
  Parts 4–5.
- **Store the selected language** — new: persisted via
  `shared_preferences`, restored on next launch by
  `languageManager.initialize()`.
- **English remains the default** — verified in §2 and covered by
  `language_manager_test.dart`'s first test.
- **Changing language updates the app** — unchanged live-update
  behavior (no restart), now driven by one `setLanguage` call instead
  of two separate manual steps (`setState` + `localeController.value =`)
  duplicated at every call site.
- **Preserve existing UI/design** — no widget's visual tree, styling, or
  layout changed; only *where the language value comes from* changed.
- **Don't break navigation/features** — verified below (§5); the
  Splash → Landing → Language → Login → Dashboard flow and every tab
  are unchanged in behavior.
- **Centralized manager instead of per-screen handling** — `LanguageManager`
  (§2) is that centralization; §3 lists exactly what stopped
  relaying the value manually as a result.

## 5. Verification performed

Same sandbox constraint as every prior pass — no Flutter/Dart SDK or
network access here, so `flutter analyze`/`flutter test` couldn't be
run directly. Substitute checks performed:

- Brace/paren/bracket balance across all 29 `lib/**/*.dart` +
  `test/**/*.dart` files — all balanced.
- Grepped for every remaining reference to `selectedLanguage` and every
  `DashboardShell(` instantiation project-wide — exactly one
  instantiation (`landing_page.dart`), matching the new constructor.
- Confirmed `SoilScanScreen`/`ChatbotScreen` still declare
  `required this.language` unchanged, so `dashboard_shell.dart`'s
  `SoilScanScreen(language: language)` / `ChatbotScreen(language: language)`
  calls remain valid against their existing constructors.
- Confirmed `_History`/`_Profile` class definitions in
  `dashboard_shell.dart` are untouched — only how `DashboardShell`
  supplies their `language`/`currentLanguage` arguments changed.
- Re-ran the project-wide `l10n.<key>` cross-check against
  `AppLocalizations` — 56 keys used, all still resolve.
- Re-ran the hardcoded-secret scan — clean, Part 4's Gemini-key fix and
  Part 5's Bhashini fallback fix are both still in place, untouched by
  this pass.
- Manually traced every edited call site against the new
  `LanguageManager` API for type correctness (e.g. `ValueChanged<LanguageOption>`
  accepting `languageManager.setLanguage`, a `Future<void> Function(LanguageOption)`
  — the same async-callback-in-a-void-slot pattern already used
  elsewhere in this codebase, e.g. `OutlinedButton.icon(onPressed: () async {...})`
  in `login_screen.dart`).

### Tests added

**New**: `test/core/services/language_manager_test.dart` — 7 tests using
`SharedPreferences.setMockInitialValues` (no real device/browser storage
touched):
- Defaults to English before any selection/restore.
- `setLanguage` updates the current selection immediately.
- `setLanguage` keeps `localeController` in sync (the contract that
  keeps existing localized screens working unmodified).
- `setLanguage` notifies listeners exactly once per change.
- `setLanguage` persists the choice so a later `SharedPreferences.getInstance()`
  read (simulating the next cold start) sees it.
- Every one of the 7 supported languages can be selected without
  throwing.
- `initialize()` is safe to call more than once.

Run the full suite, including Parts 4–5's tests:

```bash
cd krishinetra
flutter pub get
flutter test
```

## 6. Files touched this pass

**New**
- `lib/core/services/language_manager.dart`
- `test/core/services/language_manager_test.dart`
- `docs/PART6_LANGUAGE_MANAGER.md` (this file)

**Edited**
- `lib/main.dart` — `main()` now `async`, calls `languageManager.initialize()`.
- `lib/features/auth/presentation/pages/language_selection_screen.dart` —
  routes the "Continue" action through `languageManager.setLanguage`;
  `onContinue` signature simplified.
- `lib/features/landing/landing_page.dart` — dropped the now-unnecessary
  `LanguageOption` relay through its navigation closures and
  `_DashboardStarter`.
- `lib/features/dashboard/dashboard_shell.dart` — dropped
  `selectedLanguage`/`_language`/`_changeLanguage`; reads
  `languageManager.selected` via `ValueListenableBuilder` instead.
- `pubspec.yaml` — added `shared_preferences: ^2.3.2`.

**Not touched**: `language_model.dart`, `locale_controller.dart`,
`sarvam_service.dart`, `translation_service.dart`, `bhashini_service.dart`,
`gemini_service.dart`, `login_screen.dart`, `soil_scan_screen.dart`,
`recommendation_report_screen.dart`, `chatbot_screen.dart`,
`schemes_screen.dart`, every `.arb` file, `app_localizations.dart`,
`app_theme.dart`, every widget under `core/widgets/`, and the Part 4/5
test files — all byte-identical to the Part 5 project.

## 7. Known gaps (unchanged, out of this pass's scope)

- `SchemesScreen` still receives no language and stays English-only —
  same gap flagged since `LOCALIZATION_AUDIT.md` §3. With language now
  centralized, wiring it in no longer needs a constructor change at
  all — `SchemesScreen` could read `languageManager.selected` directly
  whenever its content is localized, but that content-translation work
  itself is unchanged/out of scope here, same as every prior pass.
- Deterministic fertilizer/schedule/organics/Do's/Don'ts strings and
  `SoilHealthStatus.label` remain English-only (unchanged from Parts
  2–5).
- A live `flutter test`/`flutter analyze` run on a machine with the SDK
  and network access is still the outstanding action item, as in every
  prior pass.
