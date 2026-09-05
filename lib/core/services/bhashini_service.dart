import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for Bhashini — the Government of India / Digital India Bhashini
/// initiative's free NLP API (https://bhashini.gov.in) — used here purely
/// for text-to-text translation of KrishiNetra's farmer-facing content
/// (soil report summaries, fertilizer plans, Do's/Don'ts, chat answers)
/// into the farmer's selected Indian language.
///
/// Why Bhashini and not just "ask Gemini to answer in Hindi/Marathi/...":
/// Gemini already gets a language instruction in its own prompt, but the
/// **offline rule-based engine** (used whenever there's no connectivity or
/// no Gemini key — see [GeminiAgriService]) has no language model of its
/// own and previously only had a hand-written Hindi string, with every
/// other supported language silently falling back to English. Routing
/// that English text through Bhashini's translation pipeline is what lets
/// Marathi, Kannada, Tamil, Gujarati, and Telugu farmers actually read
/// their report in their own language, online or offline-engine-driven.
///
/// ## Getting credentials
/// 1. Sign up at https://bhashini.gov.in and open the "My Profile" ->
///    "Manage API Keys" section to generate a ULCA API key.
/// 2. You'll get a **User ID** and a **ULCA API key**. Paste them below, or
///    (preferred outside local testing) pass them via
///    `flutter run --dart-define=BHASHINI_USER_ID=... --dart-define=BHASHINI_ULCA_API_KEY=...`,
///    which this service checks first automatically.
///
/// ## How the API works (two calls)
/// 1. **Pipeline discovery** — POST to [_pipelineConfigEndpoint] with the
///    source/target language pair to get back a `callbackUrl`, a
///    per-pipeline inference API key, and a `serviceId` for the actual
///    translation model. This is cached per language pair so it only
///    happens once per pair, per app session.
/// 2. **Inference** — POST the text(s) to that `callbackUrl` using the
///    pipeline-specific inference key, and read back the translated
///    text(s).
///
/// Every public method fails soft and layers two strategies:
/// 1. **Real Bhashini** — used automatically once [kBhashiniUserId] /
///    [kBhashiniUlcaApiKey] (or the matching `--dart-define`s) are set.
/// 2. **Free, no-signup fallback** — used automatically whenever Bhashini
///    isn't configured yet (e.g. registration still pending DIBD
///    approval) or a Bhashini call fails, so the app translates content
///    from day one without waiting on approval. See
///    [_translateBatchViaFreeFallback] for details and its caveats.
///
/// If both fail, the original (untranslated) text is returned unchanged
/// rather than throwing — the same "always show *something* useful"
/// posture as the offline agronomy engine this feeds into.
final class BhashiniTranslationService {
  static const String _envUserId = String.fromEnvironment('BHASHINI_USER_ID');
  static const String _envUlcaApiKey = String.fromEnvironment('BHASHINI_ULCA_API_KEY');

  /// Paste your Bhashini User ID + ULCA API key here for local testing
  /// (see class doc comment above for how to get one). Leave the
  /// placeholders as-is to make [isConfigured] false, which keeps every
  /// translation call a safe no-op that just returns the original text.
  static const String kBhashiniUserId = 'YOUR_BHASHINI_USER_ID';
  static const String kBhashiniUlcaApiKey = 'YOUR_BHASHINI_ULCA_API_KEY';

  static const String _pipelineConfigEndpoint =
      'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';

  /// The public MeitY "default" NMT (translation) pipeline. This is the
  /// same pipeline ID used in Bhashini's own sample apps and works for
  /// every English<->Indian-language pair KrishiNetra needs.
  static const String _defaultPipelineId = '64392f96daac500b55c543cd';

  String get _userId => _envUserId.isNotEmpty ? _envUserId : kBhashiniUserId;
  String get _ulcaApiKey => _envUlcaApiKey.isNotEmpty ? _envUlcaApiKey : kBhashiniUlcaApiKey;

  bool get isConfigured =>
      _userId.isNotEmpty &&
      _ulcaApiKey.isNotEmpty &&
      _userId != 'YOUR_BHASHINI_USER_ID' &&
      _ulcaApiKey != 'YOUR_BHASHINI_ULCA_API_KEY';

  /// Pipeline config (callback URL + inference key + serviceId) is stable
  /// for a given language pair, so it's fetched once and reused for every
  /// translation in that pair for the lifetime of the app process.
  final Map<String, _BhashiniPipelineConfig> _pipelineCache = <String, _BhashiniPipelineConfig>{};

  /// Exact-text translation cache, so re-rendering the same report (or
  /// asking the same quick-prompt question twice) doesn't re-hit the API.
  final Map<String, String> _textCache = <String, String>{};

  /// Translates a single string from [sourceLanguage] to [targetLanguage]
  /// (ISO codes, e.g. `en` -> `mr`). Returns [text] unchanged if the
  /// languages match, the text is blank, or translation isn't possible
  /// for any reason.
  Future<String> translate(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty || sourceLanguage == targetLanguage) return text;
    final List<String> result = await translateBatch(
      <String>[text],
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    return result.first;
  }

  /// Translates several strings in one API round trip — always prefer
  /// this over calling [translate] in a loop when translating a whole
  /// report, since Bhashini's inference endpoint natively accepts a batch
  /// of inputs and this keeps latency to a single request.
  ///
  /// Returns [texts] unchanged (same length/order) if Bhashini isn't
  /// configured or the call fails for any reason — callers never need a
  /// separate offline/error branch.
  Future<List<String>> translateBatch(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (texts.isEmpty || sourceLanguage == targetLanguage) return texts;

    if (isConfigured) {
      try {
        return await _translateBatchViaBhashini(
          texts,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      } catch (error) {
        // ignore: avoid_print
        print('Bhashini translation failed, trying free fallback: $error');
      }
    }

    // No Bhashini credentials yet (registration pending DIBD approval), or
    // the call above failed — fall back to a free, no-signup translation
    // endpoint so the app still works today. The moment real Bhashini
    // credentials are set (see [kBhashiniUserId] / [kBhashiniUlcaApiKey]
    // above), this class automatically prefers those instead — nothing
    // else in the app needs to change when that happens.
    return _translateBatchViaFreeFallback(
      texts,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  Future<List<String>> _translateBatchViaBhashini(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // Serve whatever's already cached, and only ask the API for the rest.
    final List<int> uncachedIndices = <int>[];
    final List<String> uncachedTexts = <String>[];
    final List<String> results = List<String>.from(texts);

    for (int i = 0; i < texts.length; i++) {
      final String? cached = _textCache[_cacheKey(sourceLanguage, targetLanguage, texts[i])];
      if (cached != null) {
        results[i] = cached;
      } else if (texts[i].trim().isNotEmpty) {
        uncachedIndices.add(i);
        uncachedTexts.add(texts[i]);
      }
    }

    if (uncachedTexts.isEmpty) return results;

    final _BhashiniPipelineConfig config = await _pipelineConfigFor(sourceLanguage, targetLanguage);

    final http.Response response = await http
        .post(
          Uri.parse(config.callbackUrl),
          headers: {
            'Content-Type': 'application/json',
            config.inferenceKeyName: config.inferenceKeyValue,
          },
          body: jsonEncode({
            'pipelineTasks': [
              {
                'taskType': 'translation',
                'config': {
                  'language': {
                    'sourceLanguage': sourceLanguage,
                    'targetLanguage': targetLanguage,
                  },
                  'serviceId': config.serviceId,
                },
              },
            ],
            'inputData': {
              'input': uncachedTexts.map((String t) => {'source': t}).toList(),
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Bhashini inference returned ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> pipelineResponse = body['pipelineResponse'] as List<dynamic>;
    final List<dynamic> output = pipelineResponse.first['output'] as List<dynamic>;

    for (int j = 0; j < uncachedIndices.length && j < output.length; j++) {
      final String translated = (output[j]['target'] as String?)?.trim() ?? uncachedTexts[j];
      final int originalIndex = uncachedIndices[j];
      results[originalIndex] = translated.isNotEmpty ? translated : uncachedTexts[j];
      _textCache[_cacheKey(sourceLanguage, targetLanguage, uncachedTexts[j])] = results[originalIndex];
    }

    return results;
  }

  /// Free, no-signup translation fallback used automatically whenever real
  /// Bhashini credentials aren't configured yet (e.g. registration still
  /// pending DIBD approval) or a Bhashini call fails. Uses the public,
  /// unauthenticated Google Translate web endpoint — the same one
  /// `translate.google.com` itself calls — so it works immediately with
  /// zero setup. This is meant as a stopgap, not a long-term replacement:
  /// it's unofficial, unversioned, and Google could rate-limit or change
  /// it without notice, which is exactly why [translateBatch] always
  /// prefers real Bhashini the instant credentials are set.
  ///
  /// The endpoint only accepts one string per request, so this issues one
  /// HTTP call per uncached string rather than a single batched call —
  /// fine for a report's worth of strings (a dozen or so), not meant for
  /// bulk translation.
  Future<List<String>> _translateBatchViaFreeFallback(
    List<String> texts, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final List<String> results = List<String>.from(texts);

    for (int i = 0; i < texts.length; i++) {
      final String text = texts[i];
      if (text.trim().isEmpty) continue;

      final String? cached = _textCache[_cacheKey(sourceLanguage, targetLanguage, text)];
      if (cached != null) {
        results[i] = cached;
        continue;
      }

      try {
        final Uri uri = Uri.parse(
          'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=$sourceLanguage&tl=$targetLanguage&dt=t&q=${Uri.encodeComponent(text)}',
        );

        final http.Response response = await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('Free translate endpoint returned ${response.statusCode}');
        }

        // Response shape: [[[ "translated chunk", "original chunk", ... ], ...], ...]
        // — chunks are concatenated back into one string per input.
        final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
        final List<dynamic> segments = decoded.first as List<dynamic>;
        final String translated = segments.map((dynamic segment) => segment[0] as String).join();

        if (translated.trim().isNotEmpty) {
          results[i] = translated.trim();
          _textCache[_cacheKey(sourceLanguage, targetLanguage, text)] = results[i];
        }
      } catch (error) {
        // ignore: avoid_print
        print('Free translation fallback failed for one string, leaving it in English: $error');
        // Leave results[i] as the original English text and move on —
        // one failed string shouldn't blank out the rest of the report.
      }
    }

    return results;
  }

  Future<_BhashiniPipelineConfig> _pipelineConfigFor(
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final String cacheKey = '$sourceLanguage-$targetLanguage';
    final _BhashiniPipelineConfig? cached = _pipelineCache[cacheKey];
    if (cached != null) return cached;

    final http.Response response = await http
        .post(
          Uri.parse(_pipelineConfigEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'userID': _userId,
            'ulcaApiKey': _ulcaApiKey,
          },
          body: jsonEncode({
            'pipelineTasks': [
              {
                'taskType': 'translation',
                'config': {
                  'language': {
                    'sourceLanguage': sourceLanguage,
                    'targetLanguage': targetLanguage,
                  },
                },
              },
            ],
            'pipelineRequestConfig': {'pipelineId': _defaultPipelineId},
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Bhashini pipeline config returned ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;

    final Map<String, dynamic> endpoint =
        body['pipelineInferenceAPIEndPoint'] as Map<String, dynamic>;
    final Map<String, dynamic> inferenceApiKey =
        endpoint['inferenceApiKey'] as Map<String, dynamic>;
    final List<dynamic> responseConfig = body['pipelineResponseConfig'] as List<dynamic>;
    final List<dynamic> firstConfig = responseConfig.first['config'] as List<dynamic>;
    final String serviceId = firstConfig.first['serviceId'] as String;

    final _BhashiniPipelineConfig config = _BhashiniPipelineConfig(
      callbackUrl: endpoint['callbackUrl'] as String,
      inferenceKeyName: inferenceApiKey['name'] as String,
      inferenceKeyValue: inferenceApiKey['value'] as String,
      serviceId: serviceId,
    );

    _pipelineCache[cacheKey] = config;
    return config;
  }

  String _cacheKey(String source, String target, String text) => '$source|$target|$text';
}

/// Resolved pipeline details for one (sourceLanguage, targetLanguage)
/// pair — everything needed to call the actual inference endpoint without
/// repeating the discovery round trip.
final class _BhashiniPipelineConfig {
  const _BhashiniPipelineConfig({
    required this.callbackUrl,
    required this.inferenceKeyName,
    required this.inferenceKeyValue,
    required this.serviceId,
  });

  final String callbackUrl;
  final String inferenceKeyName;
  final String inferenceKeyValue;
  final String serviceId;
}

/// App-wide singleton — every screen/service shares one Bhashini client
/// (and, importantly, its pipeline + translation caches).
final BhashiniTranslationService bhashiniTranslationService = BhashiniTranslationService();
