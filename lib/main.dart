import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:krishinetra/core/services/language_manager.dart';
import 'package:krishinetra/core/services/locale_controller.dart';
import 'package:krishinetra/core/services/report_history_store.dart';
import 'package:krishinetra/core/services/weather_service.dart';
import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/presentation/pages/splash_screen.dart';
import 'package:krishinetra/features/landing/landing_page.dart';
import 'package:krishinetra/features/profile/data/farmer_profile_service.dart';
import 'package:krishinetra/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore a previously selected language (if any) before the first
  // frame, so a returning farmer never sees a flash of English before
  // their saved language applies. Fails soft to the English default if
  // nothing was ever saved or storage isn't available — see
  // LanguageManager.initialize().
  await languageManager.initialize();
  // Restore persisted soil-score trend history the same way. Also fails
  // soft — a returning farmer just sees an empty trend chart rather than
  // a startup crash if storage is unavailable.
  await reportHistoryStore.hydrate();
  // Restore the farmer's standing profile (state, land size, crops,
  // organic-input default) — same fail-soft contract as the other two.
  await farmerProfileService.hydrate();
  // Kick off a weather fetch immediately (not awaited) so the Home tab
  // and Weather tab likely already have real data by the time the
  // farmer navigates to them, instead of every screen showing its own
  // loading spinner on first open. Requires a location permission
  // prompt the farmer may dismiss — every weather-reading widget handles
  // that gracefully (see WeatherService.error).
  unawaited(weatherService.refresh());
  runApp(const KrishiNetraApp());
}

class KrishiNetraApp extends StatelessWidget {
  const KrishiNetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp (and therefore every AppLocalizations.of(context)
    // below it) whenever localeController changes — set from the
    // language-selection screen at onboarding or the Profile/Settings
    // language switcher later. This is what makes the language choice
    // take effect live, with no restart.
    return ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'KrishiNetra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // App entry is the branded Splash screen (fully built but previously
          // never wired up), which then hands off to the Landing page — this
          // restores the complete intended onboarding flow: Splash -> Landing
          // -> Language -> Login -> Dashboard.
          home: const _AppRoot(),
        );
      },
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onFinished: () => setState(() => _splashDone = true));
    }
    return const LandingPage();
  }
}
