import 'package:flutter/material.dart';

/// App-wide current [Locale], as a [ValueNotifier] so [MaterialApp] can
/// rebuild with the new locale the instant it changes — from the
/// onboarding language-selection screen, or later from the in-app
/// language switcher on the Profile/Settings tab — without needing to
/// restart the app or thread a rebuild callback through every screen.
///
/// Kept deliberately simple (no state-management package dependency) to
/// match the rest of the app, which doesn't use one either.
final ValueNotifier<Locale> localeController = ValueNotifier<Locale>(
  const Locale('en'),
);
