# KrishiNetra — Stitch frontend merge

This build keeps the existing KrishiNetra Flutter application/services and replaces the main app chrome with the Stitch-generated visual direction:

- Stitch deep forest-green / pale-green palette and Manrope typography.
- Desktop fixed left navigation with Scan New Sample CTA.
- Responsive mobile header, drawer and bottom navigation.
- Stitch-style Home dashboard, Results, AI Farming Plan and Weather views.
- Existing soil scan flow remains wired to the existing Gemini/offline agronomy service.
- Existing AI chatbot, government schemes, report history and profile/language flows remain connected.
- Login was restyled to the Stitch two-column visual while preserving the existing OTP/Google/guest auth service calls.
- Language selection and all existing localized content remain intact.

## Run

Use the same Flutter toolchain required by the original project (Flutter >= 3.27, Dart >= 3.6):

```bash
flutter pub get
flutter run
```

For web:

```bash
flutter run -d chrome
```

The execution environment used to prepare this archive did not have the Flutter SDK installed, so `flutter analyze`/`flutter build` could not be executed here. The source was checked for structural/bracing consistency and the original dependency set was retained.
