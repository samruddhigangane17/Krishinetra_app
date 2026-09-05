import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `package:flutter_tts` for reading a soil report
/// aloud in the farmer's selected language, using the device's own
/// on-device text-to-speech engine — offline and free, consistent with
/// KrishiNetra's offline-first design (no new API key needed).
///
/// Indian-language voice availability depends entirely on what's
/// installed on the device (Android's Google TTS engine ships several
/// Indian languages by default on recent phones; iOS's built-in voice set
/// covers fewer). When the selected language's voice isn't available,
/// [speak] falls back to English rather than silently mispronouncing
/// everything, and sets [lastFallbackNotice] so the caller can tell the
/// farmer why it sounds different than expected.
final class TtsService {
  TtsService() {
    _tts.setStartHandler(() {
      isSpeaking = true;
      _notifyListeners();
    });
    _tts.setCompletionHandler(() {
      isSpeaking = false;
      _notifyListeners();
    });
    _tts.setCancelHandler(() {
      isSpeaking = false;
      _notifyListeners();
    });
    _tts.setErrorHandler((_) {
      isSpeaking = false;
      _notifyListeners();
    });
  }

  final FlutterTts _tts = FlutterTts();

  bool isSpeaking = false;

  /// Set right after a [speak] call that had to fall back to English (or
  /// couldn't confirm the requested language). Null when no fallback was
  /// needed. Callers should show this once (e.g. a SnackBar) and are free
  /// to clear it.
  String? lastFallbackNotice;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback callback) => _listeners.add(callback);

  void removeListener(VoidCallback callback) => _listeners.remove(callback);

  void _notifyListeners() {
    for (final VoidCallback callback in List<VoidCallback>.of(_listeners)) {
      callback();
    }
  }

  /// Maps KrishiNetra's plain ISO codes to the `xx-IN` locale strings
  /// most device TTS engines expect.
  static const Map<String, String> _ttsLocales = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'mr': 'mr-IN',
    'kn': 'kn-IN',
    'ta': 'ta-IN',
    'gu': 'gu-IN',
    'te': 'te-IN',
  };

  Future<void> speak(String text, String languageCode) async {
    if (text.trim().isEmpty) return;
    lastFallbackNotice = null;

    final String targetLocale = _ttsLocales[languageCode] ?? 'en-IN';

    if (targetLocale != 'en-IN') {
      try {
        final dynamic availability = await _tts.isLanguageAvailable(targetLocale);
        final bool available = availability == true || availability == 1;
        if (available) {
          await _tts.setLanguage(targetLocale);
        } else {
          await _tts.setLanguage('en-IN');
          lastFallbackNotice =
              'This device has no $targetLocale voice installed — reading the report in English instead.';
        }
      } catch (_) {
        // Some platforms/plugin versions don't support checking
        // availability up front — try the locale directly and fail soft
        // to English if the engine rejects it.
        try {
          await _tts.setLanguage(targetLocale);
        } catch (_) {
          await _tts.setLanguage('en-IN');
          lastFallbackNotice = 'Could not switch voices — reading the report in English instead.';
        }
      }
    } else {
      await _tts.setLanguage('en-IN');
    }

    // Slower and clear — meant to be understood outdoors/in the field,
    // not read at a podcast's natural pace.
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking = false;
    _notifyListeners();
  }
}

/// App-wide singleton — the report screen's "Listen to Report" button and
/// any other future TTS entry point share one engine instance.
final TtsService reportTtsService = TtsService();
