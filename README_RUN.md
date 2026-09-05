# KrishiNetra — debugged & merged

## Merge note (fertilizer-history feature)

This project (originally `krishinetra_final`) has been merged with the
fertilizer-history/recommendation feature from a second `krishinetra_modular`
project. Added on top of this app's existing screens/navigation/auth/
dashboard (all unchanged):

- **Previously-used fertilizer logging**: an optional "Previously Used
  Fertilisers" section on the Scan screen (`soil_scan_screen.dart`) where a
  farmer can log zero or more past fertilizer applications (name, optional
  quantity, optional date) before running a scan.
- **Fertilizer-aware recommendations**: `gemini_service.dart` now threads
  logged fertilizer history into both the Gemini prompt (as context only,
  never treated as proof of a deficiency/excess) and the offline
  rule-based engine.
- **Organic/natural alternatives**: a small offline knowledge base in
  `gemini_service.dart` maps common conventional fertilizers (Urea, DAP,
  SSP, MOP, NPK, Zinc Sulphate, etc.) to NCONF-referenced
  (nconf.dac.gov.in) organic/natural alternatives, shown on the report
  screen (`recommendation_report_screen.dart`) as two new cards —
  "Fertilizer Context" and "Potential Organic/Natural Alternatives" — that
  only render when the farmer actually logged history.
- **Models**: `soil_models.dart` gained `FertilizerHistoryEntry` and
  `FertilizerAlternativeGroup`, plus new optional fields on `SoilInputs`
  and `SoilHealthAssessment`.

No existing screen, route, or dependency was redesigned or removed. The
Gemini API key continues to be supplied only via
`--dart-define=GEMINI_API_KEY=...`; no key is hardcoded anywhere in the
merged project.

---


## What was actually wrong

**1. App froze right when login finished (the "stuck on login page" bug).**
In `lib/features/landing/landing_page.dart`, the navigation chain
Landing → Language → Login → Dashboard was wired with three nested
`Navigator.push` / `pushReplacement` calls, but the *same* `BuildContext`
(`ctx`, captured from the Language Selection screen) was reused for two
different navigation steps. The moment the Login screen replaced the
Language screen, that captured `ctx` belonged to an already-disposed
widget. When the farmer finished login (OTP verify, Google sign-in, or
"Continue as Guest"), the app called `Navigator.of(ctx)` on that dead
context, which throws `"Looking up a deactivated widget's ancestor is
unsafe"` — a crash at exactly the moment the app should have moved on to
the dashboard. **This is why the app appeared to hang on the login
screen.**

Fix: each navigation step now uses the `BuildContext` that belongs to
*its own* route (the one handed to it by `MaterialPageRoute`'s own
`builder`), never a context borrowed from a screen further back in the
stack. See the comments added directly in `landing_page.dart`.

**2. "Sign out" did nothing.** `DashboardShell`'s `onSignOut` callback was
wired to an empty `() {}` — tapping it had no effect. It now calls
`authService.signOut()` and returns the farmer to the Landing screen.

**3. Two competing, unwired duplicate frontends were sitting in the repo.**
Alongside the actual wired UI (`landing` → `auth` → `dashboard`), the
project also contained a second, unused set of screens
(`features/home/home_dashboard_screen.dart`, `features/scan/scan_screen.dart`,
`features/results/results_screen.dart`, `features/history/history_screen.dart`)
plus superseded duplicate model/service files
(`lib/models/soil_health.dart`, `lib/services/gemini_service.dart`). None
of these were imported by anything — they were dead leftovers from an
earlier merge pass, and having two near-identical dashboards in the repo
is exactly what reads as "the frontend is completely different from the
intended one." They've been removed; the app now has **one** frontend —
the fully wired, responsive, themed one — used everywhere.

**4. The onboarding Splash screen existed but was never shown.**
`splash_screen.dart` was a complete, polished, animated splash screen
that `main.dart` never referenced — the app went straight to the Landing
page. It's now the actual app entry point: **Splash → Landing → Language
→ Login → Dashboard**, matching the flow the rest of the code (and the
splash screen's own design) was clearly built for. No visuals were
changed — this only restores a screen that already existed in the repo.

**5. No platform target existed at all.** The zip contained only
`lib/` + `pubspec.yaml` — no `android/`, `ios/`, or `web/` folder, so
`flutter run` had nothing to build against. A `web/` target has been
added by hand (`web/index.html`, `web/manifest.json`, theme-matched
icons) so the app can be run immediately with:

```bash
flutter pub get
flutter run -d chrome
```

To add Android/iOS targets, run this once from the project root (safe —
it only adds the missing platform folders, it does not touch `lib/`):

```bash
flutter create --platforms=android,ios .
```

**6. SDK constraint was looser than the code actually requires.**
`app_theme.dart` uses `CardThemeData`, an API that only exists from
Flutter 3.27 onward. `pubspec.yaml` previously allowed Flutter
`>=3.19.0`, which would fail to compile on older SDKs. Bumped to
`>=3.27.0` to match what the code actually needs.

**7. Added `analysis_options.yaml`.** `flutter_lints` was listed as a
dev dependency but nothing enabled it.

## What was verified

The Flutter/Dart toolchain and `pub.dev` aren't reachable from this
environment, so `flutter analyze` / `flutter run` couldn't be executed
directly here. In place of that, every `.dart` file was checked with a
Dart-aware tokenizer (correctly handling strings, `${...}` interpolation,
and comments) for balanced brackets/parens, every `package:krishinetra/...`
import was confirmed to resolve to a real file, and every custom
class/enum used across the app was confirmed to be defined somewhere in
the project. All 16 source files passed. Please still run
`flutter pub get && flutter analyze && flutter run` yourself as a final
check before shipping.

## Main flow (unchanged design, now actually reachable end-to-end)

Splash → Landing → Language → Login (Phone OTP / Google / Guest) →
Responsive Dashboard (Home / Scan / History / Profile) → Scan →
Gemini/offline analysis → Report → Save to History → Sign out → back to
Landing.

For live Gemini analysis:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
```

The app has a deterministic offline fallback when no Gemini key/network
is available.
