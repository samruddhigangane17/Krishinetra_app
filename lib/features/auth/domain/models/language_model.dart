import 'package:flutter/foundation.dart';

@immutable
final class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  final String code;
  final String nativeName;
  final String englishName;

  static const List<LanguageOption> supported = <LanguageOption>[
    LanguageOption(code: 'en', nativeName: 'English', englishName: 'English'),
    LanguageOption(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi'),
    LanguageOption(code: 'mr', nativeName: 'मराठी', englishName: 'Marathi'),
    LanguageOption(code: 'kn', nativeName: 'ಕನ್ನಡ', englishName: 'Kannada'),
    LanguageOption(code: 'ta', nativeName: 'தமிழ்', englishName: 'Tamil'),
    LanguageOption(code: 'gu', nativeName: 'ગુજરાતી', englishName: 'Gujarati'),
    LanguageOption(code: 'te', nativeName: 'తెలుగు', englishName: 'Telugu'),
  ];

  /// Fallback language used wherever a language hasn't been explicitly
  /// resolved yet (e.g. service calls made before onboarding completes).
  static const LanguageOption defaultLanguage = LanguageOption(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
  );
}
