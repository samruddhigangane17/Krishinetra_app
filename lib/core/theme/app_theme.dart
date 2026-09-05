import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF004122);
  static const Color primaryDark = Color(0xFF002112);
  static const Color primaryLight = Color(0xFF206B40);
  static const Color secondary = Color(0xFF006D33);
  static const Color secondaryLight = Color(0xFF8CF6A4);
  static const Color secondaryDark = Color(0xFF005225);
  static const Color accent = Color(0xFFE86F00);
  static const Color accentLight = Color(0xFFFFDBC8);
  static const Color tertiary = Color(0xFF5E2800);
  static const Color terracotta = accent;
  static const Color soilBrown = Color(0xFF5E2800);
  static const Color mustard = Color(0xFFF2B544);
  static const Color success = Color(0xFF087F3E);
  static const Color warning = Color(0xFFE86F00);
  static const Color error = Color(0xFFBA1A1A);
  static const Color info = Color(0xFF276749);
  static const Color background = Color(0xFFF8F5EA);
  static const Color surface = Color(0xFFE8FFEE);
  static const Color surfaceVariant = Color(0xFFC5ECD2);
  static const Color surfaceContainerLow = Color(0xFFD5FDE3);
  static const Color surfaceContainer = Color(0xFFD0F7DD);
  static const Color surfaceContainerHigh = Color(0xFFCAF1D8);
  static const Color surfaceContainerHighest = Color(0xFFC5ECD2);
  static const Color outline = Color(0xFF707A70);
  static const Color outlineVariant = Color(0xFFBFC9BE);
  static const Color textPrimary = Color(0xFF002112);
  static const Color textSecondary = Color(0xFF404941);
}

abstract final class AppRadii {
  static const double card = 24;
  static const double dialog = 24;
  static const double button = 12;
  static const double chip = 12;
  static const double sheet = 24;
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 12;
  static const double md = 24;
  static const double lg = 40;
  static const double xl = 64;
  static const double xxl = 72;
}

final class AppTheme {
  const AppTheme._();

  static List<String> _fontFallback() => [
    GoogleFonts.notoSansDevanagari().fontFamily!,
    GoogleFonts.notoSansKannada().fontFamily!,
    GoogleFonts.notoSansTamil().fontFamily!,
    GoogleFonts.notoSansTelugu().fontFamily!,
    GoogleFonts.notoSansGujarati().fontFamily!,
  ];

  static TextTheme _buildTextTheme() {
    final display = GoogleFonts.manropeTextTheme();
    final body = GoogleFonts.manropeTextTheme();
    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      displayMedium: display.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
      displaySmall: display.displaySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: display.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineMedium: display.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      titleLarge: body.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      titleMedium: body.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.textPrimary, height: 1.55),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textSecondary),
      labelLarge: body.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      labelMedium: body.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      labelSmall: body.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
    ).apply(fontFamilyFallback: _fontFallback());
  }

  static ThemeData light() {
    final textTheme = _buildTextTheme();
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      outline: AppColors.outline,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      fontFamily: GoogleFonts.manrope().fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 0, backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent, foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.headlineSmall, systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: Colors.white, surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.primary,
        foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
        textStyle: textTheme.labelLarge,
      )),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.primary,
        foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
        textStyle: textTheme.labelLarge,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary, minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
        textStyle: textTheme.labelLarge,
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white, indicatorColor: AppColors.secondaryLight,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: GoogleFonts.manrope().fontFamily, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
