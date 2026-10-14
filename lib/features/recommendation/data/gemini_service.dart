import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List, immutable;
import 'package:http/http.dart' as http;

import 'package:krishinetra/core/services/translation_service.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/recommendation/domain/models/soil_models.dart';

/// Previously held a hardcoded fallback API key committed directly in
/// source — flagged as a security issue in `LOCALIZATION_AUDIT.md`,
/// `LOCALIZATION_PART2.md`, and `SARVAM_INTEGRATION.md` across three prior
/// passes, and fixed in this one. The key is now supplied exclusively via
/// `flutter run --dart-define=GEMINI_API_KEY=your_key` (get a free key at
/// https://aistudio.google.com/apikey). No in-source constant exists to
/// paste a key into, matching the pattern already used for
/// `SARVAM_API_KEY` in `sarvam_service.dart` — if the define isn't
/// supplied, [GeminiAgriService.isConfigured] is `false` and the app uses
/// the offline rule-based engine instead, exactly as it does today when
/// Gemini is unreachable.
const String kGeminiApiKey = '';

/// One turn in a chatbot conversation — kept intentionally minimal since
/// it only needs to round-trip back into the next prompt as plain text.
@immutable
final class ChatTurn {
  const ChatTurn({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// Client for Gemini-powered soil + crop-image analysis, with a
/// deterministic rule-based agronomy engine as a first-class fallback —
/// since KrishiNetra's farmers frequently work with no connectivity, the
/// offline path must produce a genuinely useful report, not just an error
/// state.
///
/// Design note on the hybrid split: Gemini is asked for exactly the
/// qualitative judgment calls a language model is good at — the
/// conversational summary, an overall health score, and disease/pest
/// detection from the photo. The fertilizer dosage plan, application
/// timeline, and organic alternatives keep coming from the deterministic
/// rule-based engine below, because a wrong kg/acre number is a much
/// costlier mistake than an imprecise sentence, and free-text extraction
/// of exact dosages from a language model is fragile. This is the
/// "hybrid" in KrishiNetra's hybrid recommendation engine.
final class GeminiAgriService {
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = 'gemini-3.6-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  String get _resolvedApiKey => _envApiKey.isNotEmpty ? _envApiKey : kGeminiApiKey;

  bool get isConfigured => _resolvedApiKey.isNotEmpty;

  /// Convenience entry point matching the simple diagnostic-flow signature:
  /// takes the four soil readings, the selected crop, and an optional crop
  /// photo. Defaults the response language to English. Internally
  /// delegates to [analyzeSoilAndRecommend] so every call site shares one
  /// implementation, one fallback path, and one result shape.
  Future<SoilHealthAssessment> analyzeSoil(
    double? n,
    double? p,
    double? k,
    double? ph,
    String crop, {
    double? moisture,
    Uint8List? imageBytes,
    String? imageMimeType,
    List<FertilizerHistoryEntry> fertilizerHistory = const [],
    LanguageOption language = LanguageOption.defaultLanguage,
    String? cropStage,
    bool? usesOrganicInputs,
  }) {
    return analyzeSoilAndRecommend(
      n: n,
      p: p,
      k: k,
      ph: ph,
      moisture: moisture,
      selectedCrop: crop.isEmpty ? null : crop,
      cropStage: cropStage,
      usesOrganicInputs: usesOrganicInputs,
      language: language,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      fertilizerHistory: fertilizerHistory,
    );
  }

  /// Primary entry point. Sends soil chemistry (and, if provided, a crop
  /// photo as inline Base64 image data) to Gemini for multimodal analysis.
  /// Falls back smoothly to the offline engine on any failure — missing
  /// key, disconnected device, malformed response, or a network/API error.
  Future<SoilHealthAssessment> analyzeSoilAndRecommend({
    double? n,
    double? p,
    double? k,
    double? ph,
    double? moisture,
    String? selectedCrop,
    String? cropStage,
    bool? usesOrganicInputs,
    required LanguageOption language,
    Uint8List? imageBytes,
    String? imageMimeType,
    List<FertilizerHistoryEntry> fertilizerHistory = const [],
  }) async {
    final SoilInputs inputs = SoilInputs(
      nitrogen: n,
      phosphorus: p,
      potassium: k,
      ph: ph,
      moisture: moisture,
      selectedCrop: selectedCrop,
      cropStage: cropStage,
      usesOrganicInputs: usesOrganicInputs,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      fertilizerHistory: fertilizerHistory,
    );

    if (!inputs.hasImage && !inputs.hasAnySoilData) {
      throw ArgumentError(
        'Provide at least a crop/soil photo or one soil reading to analyze.',
      );
    }

    if (!isConfigured) {
      return await _buildOfflineAssessment(inputs, language);
    }

    try {
      final String prompt = buildAgronomistPrompt(inputs: inputs, language: language);
      return await _callGeminiApi(prompt: prompt, inputs: inputs, language: language);
    } catch (error) {
      // ignore: avoid_print
      print('Gemini call failed, falling back offline: $error');
      return await _buildOfflineAssessment(inputs, language);
    }
  }

  /// Builds the structured prompt sent to Gemini, combining soil chemistry,
  /// the target crop, and — when a photo is attached — an explicit
  /// instruction to analyze it for disease/pest symptoms, per the exact
  /// JSON contract [_callGeminiApi] expects back.
  String buildAgronomistPrompt({
    required SoilInputs inputs,
    required LanguageOption language,
  }) {
    final String cropClause = inputs.selectedCrop?.isNotEmpty == true
        ? 'The farmer is specifically considering growing ${inputs.selectedCrop}.'
        : 'The farmer has not pre-selected a crop.';

    // Soil readings are optional now, so the block below degrades from
    // "full lab report" to "partial" to "none entered", and the image
    // clause below picks up the slack when readings are missing.
    final String soilClause = inputs.hasAnySoilData
        ? '''Soil test results (fields the farmer left blank are marked "not provided" — do not invent numbers for those):
- Nitrogen (N): ${inputs.nitrogen?.toStringAsFixed(1) ?? 'not provided'} kg/acre
- Phosphorus (P): ${inputs.phosphorus?.toStringAsFixed(1) ?? 'not provided'} kg/acre
- Potassium (K): ${inputs.potassium?.toStringAsFixed(1) ?? 'not provided'} kg/acre
- Soil pH: ${inputs.ph?.toStringAsFixed(1) ?? 'not provided'}'''
        : 'No soil test readings were entered — the farmer has no soil-test kit.';

    final String imageClause = inputs.hasImage
        ? (inputs.hasCompleteSoilData
              ? 'A photo of the crop/leaf is attached. Examine it closely for '
                    'signs of disease, pest damage, or nutrient-deficiency '
                    'symptoms visible on the leaves or stem.'
              : 'A photo of the crop, leaf, or soil is attached, and it is '
                    'the farmer\'s ONLY (or main) source of data — lab '
                    'readings are missing or incomplete. Examine the image '
                    'closely and do your best to estimate: likely soil '
                    'type/texture and color, visible moisture and organic-'
                    'matter cues, and any nutrient-deficiency, disease, or '
                    'pest symptoms on the plant. Give your best-effort '
                    'healthScore and agronomistSummary from these visual '
                    'cues, and explicitly say in agronomistSummary that '
                    'this is a photo-based estimate rather than a lab-'
                    'verified result, since some or all soil numbers were '
                    'not provided.')
        : 'No crop photo was provided — base your analysis on the soil '
              'data only, and leave diseaseName and diseaseTreatment null.';

    final String fertilizerHistoryClause = inputs.fertilizerHistory.isEmpty
        ? ''
        : '''

The farmer also logged these previously-used fertilizers (for context only):
${inputs.fertilizerHistory.map((f) => '- ${f.name}${f.quantity != null ? ' (${f.quantity})' : ''}${f.date != null ? ' on ${f.date!.toIso8601String().split('T').first}' : ''}').join('\n')}
Use this only to add context to your summary (e.g. noting what nutrient that fertilizer typically supplies). Do NOT treat this history by itself as proof of a current deficiency or excess — only the soil test results above establish that.''';

    return '''
You are an expert agricultural agronomist advising a smallholder farmer in India.

$soilClause

$cropClause
$imageClause$fertilizerHistoryClause

Analyze this soil data and the crop image. Respond in ${language.englishName}
(${language.nativeName}) with warm, plain language suitable for a farmer
with limited formal literacy.

Return ONLY a JSON object with exactly these keys:
{
  "agronomistSummary": "one paragraph, plain-language summary of soil health and any visible crop issues",
  "healthScore": <integer 0-100>,
  "diseaseName": "<name of detected disease/pest, or null if none detected or no photo given>",
  "diseaseTreatment": "<concise treatment plan for the detected issue, or null>"
}
''';
  }

  /// Real Gemini REST call. Sends the prompt as text, plus the crop photo
  /// (if any) as inline Base64 image data, and requests a JSON-only
  /// response so parsing is reliable. On success, merges Gemini's
  /// qualitative findings (summary, score, disease) with the deterministic
  /// fertilizer/crop plan from the offline engine — see the class-level
  /// doc comment for why that split exists.
  Future<SoilHealthAssessment> _callGeminiApi({
    required String prompt,
    required SoilInputs inputs,
    required LanguageOption language,
  }) async {
    final List<Map<String, dynamic>> parts = [
      {'text': prompt},
    ];

    if (inputs.hasImage) {
      parts.add({
        'inline_data': {
          'mime_type': inputs.imageMimeType ?? 'image/jpeg',
          'data': base64Encode(inputs.imageBytes!),
        },
      });
    }

    final Uri uri = Uri.parse('$_endpoint?key=$_resolvedApiKey');

    final http.Response response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {'parts': parts},
            ],
            'generationConfig': {'responseMimeType': 'application/json'},
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Gemini API returned ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;

    final String rawText = (body['candidates'] as List)
        .first['content']['parts']
        .first['text'] as String;

    final Map<String, dynamic> parsed = jsonDecode(rawText) as Map<String, dynamic>;

    final int healthScore = ((parsed['healthScore'] as num?)?.round() ?? 50).clamp(0, 100);
    final String summary = (parsed['agronomistSummary'] as String?)?.trim().isNotEmpty == true
        ? (parsed['agronomistSummary'] as String).trim()
        : 'Analysis complete — see the plan below for next steps.';
    final String? diseaseName = _cleanNullableString(parsed['diseaseName']);
    final String? diseaseTreatment = _cleanNullableString(parsed['diseaseTreatment']);

    final SoilHealthStatus status = healthScore >= 75
        ? SoilHealthStatus.good
        : healthScore >= 45
        ? SoilHealthStatus.moderate
        : SoilHealthStatus.poor;

    // Deterministic pieces (fertilizer dosage, timeline, organics, crop
    // pick, Do's/Don'ts) still come from the same rule-based logic used
    // offline — see class doc comment.
    final String recommendedCrop = _recommendCrop(inputs);
    final int yieldIncreasePercent = ((100 - healthScore) * 0.35).clamp(4, 35).round();
    final List<FertilizerDose> doses = _buildFertilizerDoses(inputs);

    return SoilHealthAssessment(
      healthScore: healthScore,
      status: status,
      agronomistSummary: summary,
      recommendedCrop: recommendedCrop,
      yieldIncreasePercent: yieldIncreasePercent,
      fertilizerDoses: doses,
      scheduleSteps: _buildSchedule(doses),
      organicAlternatives: _buildOrganicAlternatives(inputs),
      dos: _buildDos(inputs),
      donts: _buildDonts(inputs),
      poweredByGemini: true,
      generatedAt: DateTime.now(),
      inputs: inputs,
      diseaseName: diseaseName,
      diseaseTreatment: diseaseTreatment,
      fertilizerContextNotes: _buildFertilizerContextNotes(inputs),
      fertilizerOrganicAlternatives: _buildFertilizerOrganicAlternatives(inputs),
      cropSuitabilities: _computeCropSuitabilities(inputs),
      primaryIssue: _computePrimaryIssue(inputs),
      actionPlan: _buildActionPlan(inputs, recommendedCrop: recommendedCrop),
      fertilizerRecommendationRows: _buildFertilizerRecommendationRows(inputs),
    );
  }

  String? _cleanNullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  /// Answers a quick follow-up question (e.g. "How do I fix low Nitrogen
  /// organically?") using the already-computed [assessment] as context.
  /// Kept as the same offline-safe canned engine as before — a follow-up
  /// chat call to Gemini is a natural next extension of this method.
  Future<String> answerQuickPrompt({
    required String question,
    required SoilHealthAssessment assessment,
    required LanguageOption language,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final String lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('nitrogen')) {
      return 'To raise Nitrogen organically: work in well-rotted farmyard '
          'manure or vermicompost before sowing, inter-crop with legumes '
          'like moong or cowpea to fix atmospheric nitrogen naturally, and '
          'apply an Azotobacter bio-fertilizer at sowing. These build '
          'lasting soil fertility rather than a one-season fix.';
    }

    if (lowerQuestion.contains('irrigat')) {
      return 'For your current soil profile, irrigate lightly right after '
          'each fertilizer application to help nutrients reach the root '
          'zone, then maintain a steady but not waterlogged moisture level '
          '— over-irrigation right after sowing washes nutrients below the '
          'root zone.';
    }

    if (lowerQuestion.contains('ph') || lowerQuestion.contains('acid')) {
      return assessment.inputs.effectivePh < SoilThresholds.idealPhLow
          ? 'Your soil is on the acidic side. Apply agricultural lime a '
                'few weeks before sowing, in split doses, and retest pH '
                'after 4–6 weeks before applying more.'
          : 'Your soil pH is close to ideal for most crops — focus on '
                'maintaining it with balanced organic matter rather than '
                'making large corrections.';
    }

    if (lowerQuestion.contains('phosphorus')) {
      return 'To raise Phosphorus organically: apply rock phosphate or bone '
          'meal ahead of sowing, and inoculate seed or soil with '
          'Phosphate Solubilizing Bacteria (PSB) to unlock phosphorus '
          'already bound in the soil.';
    }

    if (lowerQuestion.contains('potassium')) {
      return 'To raise Potassium organically: work in wood ash or '
          'banana-peel compost, and apply well-decomposed FYM — both are '
          'reliable natural potassium sources for smallholder fields.';
    }

    if (lowerQuestion.contains('disease') || lowerQuestion.contains('pest')) {
      return assessment.hasDiseaseFinding
          ? 'For ${assessment.diseaseName}: ${assessment.diseaseTreatment}'
          : 'No disease was detected in your uploaded photo. If you '
                'notice spots, wilting, or discoloration later, take a '
                'fresh close-up photo and run another scan.';
    }

    return 'Based on your soil report, ${assessment.recommendedCrop} '
        'remains the strongest fit for this field. Follow the fertilizer '
        'schedule above closely, and a fresh soil test in 3–4 months will '
        'show how much these changes have improved your soil health.';
  }

  /// General-purpose farming assistant chat — unlike [answerQuickPrompt]
  /// above, this isn't tied to a specific soil report. It's a live
  /// Gemini text call (no image), for open-ended questions like "what
  /// crop suits red soil" or "when should I sow wheat in Punjab". Falls
  /// back to a short, honest offline message when Gemini isn't
  /// reachable, rather than guessing at an answer with no model behind
  /// it — a wrong farming answer is worse than no answer.
  Future<String> chat({
    required String message,
    required List<ChatTurn> history,
    required LanguageOption language,
  }) async {
    if (!isConfigured) {
      const String englishFallback =
          "Sorry, the AI assistant isn't reachable right now (no internet "
          "or the API key isn't set up). Please try again once you're "
          'connected — or check the Soil Report for context-specific '
          'guidance instead.';
      const String hindiFallback =
          'माफ़ कीजिए, अभी AI सहायक उपलब्ध नहीं है (इंटरनेट या API कुंजी '
          'की समस्या)। कृपया बाद में फिर कोशिश करें।';

      return switch (language.code) {
        'hi' => hindiFallback,
        'en' => englishFallback,
        _ => await translationService.translate(
          englishFallback,
          sourceLanguage: 'en',
          targetLanguage: language.code,
        ),
      };
    }

    final String historyClause = history.isEmpty
        ? ''
        : '\n\nConversation so far:\n${history.map((t) => '${t.isUser ? 'Farmer' : 'You'}: ${t.text}').join('\n')}';

    final String prompt =
        '''
You are KrishiNetra's AI farming assistant, helping smallholder and
marginal farmers in India with practical, plain-language advice on
crops, soil, fertilizers, irrigation, pest/disease management, weather-
driven decisions, and government schemes. You are not a doctor, lawyer,
or financial advisor — for anything outside farming, say so briefly and
redirect back to what you can help with.

Respond in ${language.englishName} (${language.nativeName}), in warm,
simple language suitable for someone with limited formal literacy. Keep
answers concise — a few short sentences or a short bulleted list, not
an essay.
$historyClause

Farmer's new question: $message

Respond with plain text only — no JSON, no markdown headers.
''';

    try {
      final Uri uri = Uri.parse('$_endpoint?key=$_resolvedApiKey');
      final http.Response response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Gemini chat returned ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      final String rawText = (body['candidates'] as List)
          .first['content']['parts']
          .first['text'] as String;
      return rawText.trim();
    } catch (_) {
      const String englishFallback =
          "Sorry, I couldn't get an answer just now. Please try again in "
          'a moment.';
      const String hindiFallback = 'माफ़ कीजिए, अभी जवाब नहीं मिल सका। कृपया दोबारा कोशिश करें।';

      return switch (language.code) {
        'hi' => hindiFallback,
        'en' => englishFallback,
        _ => await translationService.translate(
          englishFallback,
          sourceLanguage: 'en',
          targetLanguage: language.code,
        ),
      };
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Offline rule-based agronomy engine
  // ─────────────────────────────────────────────────────────────

  Future<SoilHealthAssessment> _buildOfflineAssessment(
    SoilInputs inputs,
    LanguageOption language,
  ) async {
    // IMPORTANT: score only the nutrients the farmer actually entered.
    // `effectiveNitrogen` etc. fall back to the *ideal-band midpoint* when a
    // reading is missing (so the fertilizer-dose math never has to
    // null-check) — but feeding that same fallback into the health-score
    // calculation meant every unscored nutrient automatically graded as a
    // perfect 100, so any image-only scan (no lab readings at all) always
    // produced a 100/100 "Soil Health Score" no matter what the photo
    // showed. Missing readings now contribute a neutral 50 instead of an
    // assumed-ideal 100, and if nothing at all was entered, the composite
    // score is a flat neutral 50 rather than a fabricated 100.
    final double nScore = inputs.nitrogen == null
        ? 50
        : _nutrientScore(
            inputs.nitrogen!,
            SoilThresholds.idealNitrogenLow,
            SoilThresholds.idealNitrogenHigh,
            40,
          );
    final double pScore = inputs.phosphorus == null
        ? 50
        : _nutrientScore(
            inputs.phosphorus!,
            SoilThresholds.idealPhosphorusLow,
            SoilThresholds.idealPhosphorusHigh,
            25,
          );
    final double kScore = inputs.potassium == null
        ? 50
        : _nutrientScore(
            inputs.potassium!,
            SoilThresholds.idealPotassiumLow,
            SoilThresholds.idealPotassiumHigh,
            25,
          );
    final double phScore = inputs.ph == null
        ? 50
        : _nutrientScore(
            inputs.ph!,
            SoilThresholds.idealPhLow,
            SoilThresholds.idealPhHigh,
            2.5,
          );

    final int compositeScore = (nScore * 0.30 + pScore * 0.20 + kScore * 0.20 + phScore * 0.30)
        .round()
        .clamp(0, 100);

    final SoilHealthStatus status = compositeScore >= 75
        ? SoilHealthStatus.good
        : compositeScore >= 45
        ? SoilHealthStatus.moderate
        : SoilHealthStatus.poor;

    final String recommendedCrop = _recommendCrop(inputs);
    final int yieldIncreasePercent = ((100 - compositeScore) * 0.35).clamp(4, 35).round();
    final List<FertilizerDose> doses = _buildFertilizerDoses(inputs);

    String summary = await _buildSummary(
      inputs: inputs,
      language: language,
      score: compositeScore,
      status: status,
      recommendedCrop: recommendedCrop,
      yieldIncreasePercent: yieldIncreasePercent,
    );

    // The offline engine has no vision model, so an image-only scan run
    // without connectivity can't actually be read here — be upfront about
    // that instead of quietly presenting a generic (assumed-ideal) score
    // as if it came from the photo.
    if (!inputs.hasCompleteSoilData) {
      const String englishNote =
          "Note: no internet connection right now, so your photo couldn't "
          'actually be analyzed — this is a generic estimate based on '
          'assumed-average soil values, not your real reading. Reconnect '
          'and rescan for a true photo-based analysis, or enter your '
          'soil-test numbers for a precise offline report.';
      const String hindiNote =
          'नोट: इंटरनेट कनेक्शन न होने के कारण आपकी फोटो का विश्लेषण अभी '
          'नहीं हो सका — यह एक सामान्य अनुमान है। सटीक विश्लेषण के लिए '
          'कनेक्ट होने पर दोबारा स्कैन करें।';

      final String note = switch (language.code) {
        'hi' => hindiNote,
        'en' => englishNote,
        _ => await translationService.translate(
          englishNote,
          sourceLanguage: 'en',
          targetLanguage: language.code,
        ),
      };

      summary = '$note\n\n$summary';
    }

    return SoilHealthAssessment(
      healthScore: compositeScore,
      status: status,
      agronomistSummary: summary,
      recommendedCrop: recommendedCrop,
      yieldIncreasePercent: yieldIncreasePercent,
      fertilizerDoses: doses,
      scheduleSteps: _buildSchedule(doses),
      organicAlternatives: _buildOrganicAlternatives(inputs),
      dos: _buildDos(inputs),
      donts: _buildDonts(inputs),
      poweredByGemini: false,
      generatedAt: DateTime.now(),
      inputs: inputs,
      // The offline engine can't analyze a photo — disease detection only
      // ever comes from a real Gemini call.
      diseaseName: null,
      diseaseTreatment: null,
      fertilizerContextNotes: _buildFertilizerContextNotes(inputs),
      fertilizerOrganicAlternatives: _buildFertilizerOrganicAlternatives(inputs),
      cropSuitabilities: _computeCropSuitabilities(inputs),
      primaryIssue: _computePrimaryIssue(inputs),
      actionPlan: _buildActionPlan(inputs, recommendedCrop: recommendedCrop),
      fertilizerRecommendationRows: _buildFertilizerRecommendationRows(inputs),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Crop suitability, "what your soil needs", and the action-plan /
  // fertilizer-recommendation tables — all deterministic, rule-based, and
  // shared by both the Gemini-powered and offline paths so a farmer sees
  // the same reproducible figures either way (only the qualitative
  // summary/disease-detection differs by source — see class doc comment).
  // ─────────────────────────────────────────────────────────────

  /// Scores every crop in [CropReferenceData] by how close the soil
  /// reading sits to that crop's ideal N/P/K/pH band, and returns the
  /// best match plus up to 2 runner-ups, sorted best-first. Purely a
  /// relative closeness comparison — not a yield or profitability model.
  List<CropSuitability> _computeCropSuitabilities(SoilInputs inputs) {
    List<CropSuitability> scored = CropReferenceData.all.map((crop) {
      final double nScore = _nutrientScore(
        inputs.effectiveNitrogen,
        crop.idealNitrogenLow,
        crop.idealNitrogenHigh,
        40,
      );
      final double pScore = _nutrientScore(
        inputs.effectivePhosphorus,
        crop.idealPhosphorusLow,
        crop.idealPhosphorusHigh,
        25,
      );
      final double kScore = _nutrientScore(
        inputs.effectivePotassium,
        crop.idealPotassiumLow,
        crop.idealPotassiumHigh,
        25,
      );
      final double phScore = _nutrientScore(
        inputs.effectivePh,
        crop.idealPhLow,
        crop.idealPhHigh,
        2.5,
      );
      final int percent = (nScore * 0.3 + pScore * 0.2 + kScore * 0.2 + phScore * 0.3)
          .round()
          .clamp(0, 100);
      return CropSuitability(name: crop.name, emoji: crop.emoji, percent: percent);
    }).toList();

    scored.sort((a, b) => b.percent.compareTo(a.percent));
    return scored.take(4).toList();
  }

  /// Human-readable impact bullets for each nutrient/pH/moisture issue —
  /// deliberately short, non-diagnostic, and agronomically generic (not
  /// tied to a specific crop), matching the same plain-language register
  /// as the rest of the offline engine's copy.
  static const Map<String, List<String>> _impactsByIssue = {
    'nitrogen_low': [
      'May slow leaf growth and give plants a pale, yellowish colour',
      'Can reduce overall plant vigour and tillering',
    ],
    'nitrogen_high': [
      'Can cause excess leafy growth at the expense of grain/fruit',
      'Raises the risk of pest and disease pressure',
    ],
    'phosphorus_low': [
      'May affect root development',
      'Can reduce early plant growth and delay flowering',
    ],
    'phosphorus_high': [
      'Can block uptake of zinc and iron, causing hidden deficiencies',
    ],
    'potassium_low': [
      'Weakens stems, increasing the risk of lodging (plants falling over)',
      'Reduces resistance to drought and disease',
    ],
    'potassium_high': [
      'Can interfere with the plant\'s uptake of magnesium and calcium',
    ],
    'ph_low': [
      'Acidic soil locks up phosphorus and micronutrients, making them harder for roots to absorb',
      'Can slow the activity of beneficial soil microbes',
    ],
    'ph_high': [
      'Alkaline soil can lock up iron, zinc, and manganese',
      'May reduce the effectiveness of some fertilizers',
    ],
    'moisture_low': [
      'Drought stress can stunt growth and reduce yield',
      'Nutrient uptake slows when roots don\'t have enough soil moisture',
    ],
    'moisture_high': [
      'Waterlogging can starve roots of oxygen',
      'Raises the risk of root rot and fungal disease',
    ],
  };

  /// Picks the single worst-scoring reading (largest deviation from its
  /// ideal band) as the headline "Primary Issue", or returns null when
  /// every reading is already in its optimal band.
  SoilIssue? _computePrimaryIssue(SoilInputs inputs) {
    final List<({String key, String title, String emoji, double severity})> candidates = [
      (
        key: inputs.effectiveNitrogen < SoilThresholds.idealNitrogenLow ? 'nitrogen_low' : 'nitrogen_high',
        title: inputs.effectiveNitrogen < SoilThresholds.idealNitrogenLow ? 'Low Nitrogen' : 'High Nitrogen',
        emoji: '🔸',
        severity: 100 - _nutrientScore(inputs.effectiveNitrogen, SoilThresholds.idealNitrogenLow, SoilThresholds.idealNitrogenHigh, 40),
      ),
      (
        key: inputs.effectivePhosphorus < SoilThresholds.idealPhosphorusLow ? 'phosphorus_low' : 'phosphorus_high',
        title: inputs.effectivePhosphorus < SoilThresholds.idealPhosphorusLow ? 'Low Phosphorus' : 'High Phosphorus',
        emoji: '🔸',
        severity: 100 - _nutrientScore(inputs.effectivePhosphorus, SoilThresholds.idealPhosphorusLow, SoilThresholds.idealPhosphorusHigh, 25),
      ),
      (
        key: inputs.effectivePotassium < SoilThresholds.idealPotassiumLow ? 'potassium_low' : 'potassium_high',
        title: inputs.effectivePotassium < SoilThresholds.idealPotassiumLow ? 'Low Potassium' : 'High Potassium',
        emoji: '🔸',
        severity: 100 - _nutrientScore(inputs.effectivePotassium, SoilThresholds.idealPotassiumLow, SoilThresholds.idealPotassiumHigh, 25),
      ),
      (
        key: inputs.effectivePh < SoilThresholds.idealPhLow ? 'ph_low' : 'ph_high',
        title: inputs.effectivePh < SoilThresholds.idealPhLow ? 'Acidic Soil (Low pH)' : 'Alkaline Soil (High pH)',
        emoji: '🔸',
        severity: 100 - _nutrientScore(inputs.effectivePh, SoilThresholds.idealPhLow, SoilThresholds.idealPhHigh, 2.5),
      ),
      (
        key: inputs.effectiveMoisture < SoilThresholds.idealMoistureLow ? 'moisture_low' : 'moisture_high',
        title: inputs.effectiveMoisture < SoilThresholds.idealMoistureLow ? 'Low Soil Moisture' : 'Excess Soil Moisture',
        emoji: '🔸',
        severity: 100 - _nutrientScore(inputs.effectiveMoisture, SoilThresholds.idealMoistureLow, SoilThresholds.idealMoistureHigh, 15),
      ),
    ];

    candidates.sort((a, b) => b.severity.compareTo(a.severity));
    final worst = candidates.first;

    // Nothing meaningfully off — every reading is close enough to its
    // ideal band that calling out a "primary issue" would be noise.
    if (worst.severity < 15) return null;

    return SoilIssue(
      title: worst.title,
      emoji: worst.emoji,
      impacts: _impactsByIssue[worst.key] ?? const [],
    );
  }

  /// The report screen's 4-step "Recommended Action Plan" — always the
  /// same 4 stages (Fertilizer → Organic Matter → Timing → Recheck), with
  /// step 1's text tailored to whichever nutrient most needs correcting.
  /// Deliberately free of exact kg/acre figures here (those live only in
  /// [_buildFertilizerDoses]/[fertilizerDoses], which are already flagged
  /// as estimates) — this plan is the "what to do", not the dosage sheet.
  List<ActionStep> _buildActionPlan(SoilInputs inputs, {required String recommendedCrop}) {
    final SoilIssue? issue = _computePrimaryIssue(inputs);

    final String fertilizerStep = issue == null
        ? 'Your readings are close to the ideal range — apply a balanced, '
            'maintenance-level fertilizer dose rather than a heavy correction.'
        : 'Apply the recommended fertilizer for your ${issue.title} at the '
            'rate shown in your fertilizer plan below.';

    return [
      ActionStep(title: 'Step 1 — Fertilizer', description: fertilizerStep),
      const ActionStep(
        title: 'Step 2 — Organic Matter',
        description: 'Add compost or well-decomposed farmyard manure (FYM) to improve soil structure and long-term fertility.',
      ),
      ActionStep(
        title: 'Step 3 — Timing',
        description: 'Apply fertilizer during field preparation or just before sowing $recommendedCrop, following the timeline below.',
      ),
      const ActionStep(
        title: 'Step 4 — Recheck',
        description: 'Reassess your soil in 3–4 months to see how much these changes have improved it, and adjust the next round accordingly.',
      ),
    ];
  }

  /// The "Fertilizer Recommendation" table — Nitrogen / Phosphorus /
  /// Potassium / Organic manure, each with a short "why" so the farmer
  /// understands the reasoning rather than just a label like "Increase".
  /// Recommendation *labels* (Increase/Maintain/Reduce) are relative to
  /// each nutrient's own ideal band; the actual kg/acre figures still
  /// live only in [fertilizerDoses] per the class-level caution against
  /// hard-coding dosage outside a validated model.
  List<FertilizerRecommendationRow> _buildFertilizerRecommendationRows(SoilInputs inputs) {
    String label(double value, double low, double high) {
      if (value < low) return 'Increase';
      if (value > high) return 'Reduce';
      return 'Maintain';
    }

    return [
      FertilizerRecommendationRow(
        input: 'Nitrogen',
        recommendation: label(inputs.effectiveNitrogen, SoilThresholds.idealNitrogenLow, SoilThresholds.idealNitrogenHigh),
        reason: inputs.effectiveNitrogen < SoilThresholds.idealNitrogenLow
            ? 'Your reading is below the ideal band — Nitrogen drives leaf growth and vigour.'
            : inputs.effectiveNitrogen > SoilThresholds.idealNitrogenHigh
                ? 'Your reading is above the ideal band — excess Nitrogen can delay flowering.'
                : 'Already within the ideal band — a maintenance dose keeps it there.',
      ),
      FertilizerRecommendationRow(
        input: 'Phosphorus',
        recommendation: label(inputs.effectivePhosphorus, SoilThresholds.idealPhosphorusLow, SoilThresholds.idealPhosphorusHigh),
        reason: inputs.effectivePhosphorus < SoilThresholds.idealPhosphorusLow
            ? 'Your reading is below the ideal band — Phosphorus supports root and early growth.'
            : inputs.effectivePhosphorus > SoilThresholds.idealPhosphorusHigh
                ? 'Your reading is above the ideal band — excess Phosphorus can lock up zinc/iron.'
                : 'Already within the ideal band — a maintenance dose keeps it there.',
      ),
      FertilizerRecommendationRow(
        input: 'Potassium',
        recommendation: label(inputs.effectivePotassium, SoilThresholds.idealPotassiumLow, SoilThresholds.idealPotassiumHigh),
        reason: inputs.effectivePotassium < SoilThresholds.idealPotassiumLow
            ? 'Your reading is below the ideal band — Potassium strengthens stems and disease resistance.'
            : inputs.effectivePotassium > SoilThresholds.idealPotassiumHigh
                ? 'Your reading is above the ideal band — excess Potassium can block magnesium/calcium uptake.'
                : 'Already within the ideal band — a maintenance dose keeps it there.',
      ),
      const FertilizerRecommendationRow(
        input: 'Organic manure',
        recommendation: 'Recommended',
        reason: 'Improves soil structure, water retention, and microbial health regardless of your N/P/K levels.',
      ),
    ];
  }

  double _nutrientScore(
    double value,
    double idealLow,
    double idealHigh,
    double maxDeviationForZero,
  ) {
    if (value >= idealLow && value <= idealHigh) return 100;
    final double deviation = value < idealLow ? idealLow - value : value - idealHigh;
    final double ratio = (deviation / maxDeviationForZero).clamp(0, 1);
    return 100 * (1 - ratio);
  }

  /// When the farmer pre-selected a crop, honor that choice. Otherwise
  /// defer to [_computeCropSuitabilities] (the same N/P/K/pH-vs-ideal-band
  /// comparison shown on the report's crop suitability card), so the
  /// headline "Recommended Crop" always matches the top suitability match
  /// instead of drifting out of sync with a separate pH-only heuristic.
  String _recommendCrop(SoilInputs inputs) {
    if (inputs.selectedCrop != null && inputs.selectedCrop!.isNotEmpty) {
      return inputs.selectedCrop!;
    }
    final List<CropSuitability> ranked = _computeCropSuitabilities(inputs);
    return ranked.isNotEmpty ? ranked.first.name : 'Wheat';
  }

  double _roundToStep(double value, double step) => (value / step).round() * step;

  List<FertilizerDose> _buildFertilizerDoses(SoilInputs inputs) {
    final double nMid = (SoilThresholds.idealNitrogenLow + SoilThresholds.idealNitrogenHigh) / 2;
    final double pMid = (SoilThresholds.idealPhosphorusLow + SoilThresholds.idealPhosphorusHigh) / 2;
    final double kMid = (SoilThresholds.idealPotassiumLow + SoilThresholds.idealPotassiumHigh) / 2;

    final double ureaKg = _roundToStep(((nMid - inputs.effectiveNitrogen).clamp(0, 100) * 2.0).clamp(10, 60), 5);
    final double dapKg = _roundToStep(((pMid - inputs.effectivePhosphorus).clamp(0, 100) * 1.2).clamp(8, 40), 5);
    final double mopKg = _roundToStep(((kMid - inputs.effectivePotassium).clamp(0, 100) * 1.0).clamp(6, 30), 5);

    return [
      FertilizerDose(name: 'Urea (46% N)', doseKgPerAcre: ureaKg, note: 'Split across basal + two top-dressings'),
      FertilizerDose(name: 'DAP (18-46-0)', doseKgPerAcre: dapKg, note: 'Full dose as basal application'),
      FertilizerDose(name: 'MOP (60% K₂O)', doseKgPerAcre: mopKg, note: 'Apply at flowering / tillering stage'),
    ];
  }

  List<ScheduleStep> _buildSchedule(List<FertilizerDose> doses) {
    final double urea = doses[0].doseKgPerAcre;
    final double dap = doses[1].doseKgPerAcre;
    final double mop = doses[2].doseKgPerAcre;

    return [
      ScheduleStep(
        dayLabel: 'Day 0',
        description:
            'Basal application: full DAP (${dap.toStringAsFixed(0)} kg/acre) '
            'and 50% of Urea (${(urea / 2).toStringAsFixed(0)} kg/acre) before sowing.',
      ),
      ScheduleStep(
        dayLabel: 'Day 20',
        description:
            'First top dressing: 25% of Urea (${(urea * 0.25).toStringAsFixed(0)} '
            'kg/acre) after the first irrigation.',
      ),
      ScheduleStep(
        dayLabel: 'Day 45',
        description:
            'Second top dressing: final 25% Urea (${(urea * 0.25).toStringAsFixed(0)} '
            'kg/acre) along with MOP (${mop.toStringAsFixed(0)} kg/acre) at the '
            'flowering / tillering stage.',
      ),
    ];
  }

  List<String> _buildOrganicAlternatives(SoilInputs inputs) {
    final List<String> alternatives = [
      'Vermicompost — 2 tons/acre mixed into the topsoil before sowing.',
      'Farmyard manure (FYM) — 5 tons/acre, well-decomposed.',
      'Neem cake — 100 kg/acre to naturally deter soil pests.',
    ];

    if (inputs.effectiveNitrogen < SoilThresholds.idealNitrogenLow) {
      alternatives.add('Azotobacter bio-fertilizer to naturally fix atmospheric nitrogen.');
    }
    if (inputs.effectivePhosphorus < SoilThresholds.idealPhosphorusLow) {
      alternatives.add('Phosphate Solubilizing Bacteria (PSB) culture to unlock bound soil phosphorus.');
    }
    if (inputs.effectivePotassium < SoilThresholds.idealPotassiumLow) {
      alternatives.add('Wood ash or banana-peel compost as a natural potassium source.');
    }

    return alternatives;
  }

  List<String> _buildDos(SoilInputs inputs) {
    final List<String> dos = [
      'Get a fresh soil test every 6 months to track changes.',
      'Irrigate lightly right after fertilizer application to aid uptake.',
    ];
    if (inputs.effectivePh < SoilThresholds.idealPhLow) {
      dos.add('Apply agricultural lime in split doses to gradually raise soil pH.');
    } else if (inputs.effectivePh > SoilThresholds.idealPhHigh) {
      dos.add('Apply gypsum to help reclaim alkaline soil over time.');
    } else {
      dos.add('Maintain organic matter to keep your near-ideal pH stable.');
    }
    return dos;
  }

  List<String> _buildDonts(SoilInputs inputs) {
    final List<String> donts = [
      "Don't apply all fertilizer in a single dose — split applications reduce nutrient loss.",
      "Don't over-irrigate immediately after sowing; it washes nutrients below the root zone.",
    ];
    if (inputs.effectivePh < SoilThresholds.idealPhLow) {
      donts.add("Don't rely on urea alone — it can further acidify already-acidic soil.");
    } else if (inputs.effectivePh > SoilThresholds.idealPhHigh) {
      donts.add("Don't irrigate with hard/saline water, as it worsens alkalinity.");
    } else {
      donts.add("Don't skip micronutrient checks — a balanced pH can still hide zinc/iron gaps.");
    }
    return donts;
  }

  Future<String> _buildSummary({
    required SoilInputs inputs,
    required LanguageOption language,
    required int score,
    required SoilHealthStatus status,
    required String recommendedCrop,
    required int yieldIncreasePercent,
  }) async {
    if (language.code == 'hi') {
      return 'आपकी मिट्टी का स्वास्थ्य स्कोर $score/100 है (${status.label})। '
          'इस मिट्टी के लिए $recommendedCrop सबसे उपयुक्त फसल है, और नीचे दी गई '
          'खाद योजना अपनाने पर लगभग $yieldIncreasePercent% अधिक उपज मिलने का अनुमान है।';
    }

    final String base =
        'Your soil health score is $score/100 (${status.label}). Based on '
        'this profile, $recommendedCrop is a strong fit for your field, '
        'with an estimated $yieldIncreasePercent% yield improvement when '
        'the fertilizer plan below is followed consistently.';

    if (language.code == 'en') return base;

    // Previously this branch showed the English text plus an apologetic
    // parenthetical ("An AI-generated summary in {language} will appear
    // here once this app is connected to a live Gemini API key...") for
    // every non-Hindi language. Now it's routed through the shared
    // translation service (Sarvam AI first, Bhashini as a fail-soft
    // secondary) so Marathi, Kannada, Tamil, Gujarati, and Telugu farmers
    // get a real translated summary from the offline engine too — the
    // same gap both localization audits flagged. If neither translator is
    // configured or both fail, [translationService] returns [base]
    // unchanged, which is exactly the previous safe-default behaviour.
    final String translated = await translationService.translate(
      base,
      sourceLanguage: 'en',
      targetLanguage: language.code,
    );
    return translated;
  }

  // ─────────────────────────────────────────────────────────────
  // Fertilizer history → context notes + NCONF organic alternatives
  //
  // Small, fixed knowledge base of common conventional fertilizers and
  // the nutrient each primarily supplies, plus a short list of
  // NCONF-referenced (https://nconf.dac.gov.in/) organic/natural input
  // categories generally recognized for that nutrient. Deliberately
  // conservative: only names matching a known entry produce a note or
  // alternatives — nothing is guessed for an unrecognized fertilizer
  // name, and no dosage or 1:1 replacement is ever stated.
  // ─────────────────────────────────────────────────────────────

  static final List<_KnownFertilizer> _knownFertilizers = [
    _KnownFertilizer(
      keywords: ['urea'],
      nutrientLabel: 'Nitrogen',
      nutrientKey: 'N',
      alternatives: ['Farmyard manure (FYM)', 'Vermicompost', 'Green manure (e.g. Dhaincha, Sunhemp)', 'Azotobacter bio-fertilizer'],
    ),
    _KnownFertilizer(
      keywords: ['ammonium sulphate', 'ammonium sulfate'],
      nutrientLabel: 'Nitrogen',
      nutrientKey: 'N',
      alternatives: ['Farmyard manure (FYM)', 'Vermicompost', 'Green manure'],
    ),
    _KnownFertilizer(
      keywords: ['can', 'calcium ammonium nitrate'],
      nutrientLabel: 'Nitrogen',
      nutrientKey: 'N',
      alternatives: ['Farmyard manure (FYM)', 'Vermicompost', 'Green manure'],
    ),
    _KnownFertilizer(
      keywords: ['dap', 'diammonium phosphate'],
      nutrientLabel: 'Phosphorus (and some Nitrogen)',
      nutrientKey: 'P',
      alternatives: ['Rock phosphate', 'Bone meal', 'Compost', 'Phosphate Solubilising Bacteria (PSB) bio-fertilizer'],
    ),
    _KnownFertilizer(
      keywords: ['ssp', 'single super phosphate'],
      nutrientLabel: 'Phosphorus',
      nutrientKey: 'P',
      alternatives: ['Rock phosphate', 'Compost', 'Phosphate Solubilising Bacteria (PSB) bio-fertilizer'],
    ),
    _KnownFertilizer(
      keywords: ['mop', 'muriate of potash', 'potash'],
      nutrientLabel: 'Potassium',
      nutrientKey: 'K',
      alternatives: ['Wood ash', 'Banana-peel compost', 'Vermicompost'],
    ),
    _KnownFertilizer(
      keywords: ['npk', 'complex fertilizer', 'complex fertiliser'],
      nutrientLabel: 'Nitrogen, Phosphorus & Potassium (balanced)',
      nutrientKey: null,
      alternatives: ['Farmyard manure (FYM)', 'Vermicompost', 'Compost'],
    ),
    _KnownFertilizer(
      keywords: ['zinc sulphate', 'zinc sulfate'],
      nutrientLabel: 'Zinc (micronutrient)',
      nutrientKey: null,
      alternatives: ['Compost', 'Vermicompost'],
    ),
  ];

  _KnownFertilizer? _matchKnownFertilizer(String rawName) {
    final String name = rawName.toLowerCase().trim();
    if (name.isEmpty) return null;
    for (final _KnownFertilizer known in _knownFertilizers) {
      if (known.keywords.any((keyword) => name.contains(keyword))) return known;
    }
    return null;
  }

  /// Short, non-diagnostic notes connecting logged fertilizer history to
  /// the current soil test result. Never claims the history alone proves a
  /// deficiency/excess — only describes what the fertilizer typically
  /// supplies and, when a matching soil reading exists, what that reading
  /// currently shows.
  List<String> _buildFertilizerContextNotes(SoilInputs inputs) {
    if (inputs.fertilizerHistory.isEmpty) return [];

    final List<String> notes = [];
    for (final FertilizerHistoryEntry entry in inputs.fertilizerHistory) {
      final _KnownFertilizer? known = _matchKnownFertilizer(entry.name);
      if (known == null) continue;

      final StringBuffer note = StringBuffer(
        '${entry.name} is typically a ${known.nutrientLabel} fertilizer.',
      );

      if (known.nutrientKey != null && inputs.hasAnySoilData) {
        final SoilHealthStatus status = switch (known.nutrientKey) {
          'N' => SoilThresholds.nitrogenStatus(inputs.effectiveNitrogen),
          'P' => SoilThresholds.phosphorusStatus(inputs.effectivePhosphorus),
          'K' => SoilThresholds.potassiumStatus(inputs.effectivePotassium),
          _ => SoilHealthStatus.good,
        };
        note.write(
          ' Your soil test currently shows ${status.label.toLowerCase()} '
          '${known.nutrientKey} — this history is useful context, but the '
          'soil test result (not the fertilizer history alone) is what '
          'drives this recommendation.',
        );
      } else {
        note.write(' Shown for context only — it does not by itself indicate a current deficiency or excess.');
      }

      notes.add(note.toString());
    }
    return notes;
  }

  /// NCONF-referenced organic/natural alternatives grouped by each
  /// recognized previously-used fertilizer. Skips anything unrecognized
  /// rather than guessing, never claims a 1:1 replacement, and never
  /// invents a dosage.
  List<FertilizerAlternativeGroup> _buildFertilizerOrganicAlternatives(SoilInputs inputs) {
    if (inputs.fertilizerHistory.isEmpty) return [];

    final List<FertilizerAlternativeGroup> groups = [];
    final Set<String> seenNutrientLabels = {};

    for (final FertilizerHistoryEntry entry in inputs.fertilizerHistory) {
      final _KnownFertilizer? known = _matchKnownFertilizer(entry.name);
      if (known == null || known.alternatives.isEmpty) continue;
      // Avoid repeating the same alternative set twice for two entries
      // that supply the same nutrient (e.g. Urea logged twice).
      if (!seenNutrientLabels.add(known.nutrientLabel)) continue;

      groups.add(
        FertilizerAlternativeGroup(previousFertilizer: entry.name, alternatives: known.alternatives),
      );
    }
    return groups;
  }
}

/// App-wide singleton — every screen shares this one Gemini client.
final GeminiAgriService geminiAgriService = GeminiAgriService();

/// A conventional fertilizer recognized by the fertilizer-history context
/// engine — see `GeminiAgriService._knownFertilizers`.
final class _KnownFertilizer {
  const _KnownFertilizer({
    required this.keywords,
    required this.nutrientLabel,
    required this.nutrientKey,
    required this.alternatives,
  });

  /// Lowercase substrings matched against the farmer-entered name.
  final List<String> keywords;
  final String nutrientLabel;

  /// 'N' / 'P' / 'K', or null when this fertilizer's nutrient isn't one
  /// tracked by the soil test (e.g. a micronutrient) or is a balanced mix.
  final String? nutrientKey;
  final List<String> alternatives;
}
