# 🌾 KrishiNetra

**An offline-first, multilingual soil intelligence app for Indian farmers.**
Scan a crop or soil photo, enter soil readings, and get a health score, crop suitability, a fertilizer plan, weather-aware advice and matching government schemes, in your own language, with voice read-out.

> Built with Flutter (Web). Works without any API key using a local rule-based engine; gets smarter when a Gemini key is configured.

<!-- Add a live link and screenshots once you have them:
**Live demo:** https://your-app.web.app
![Home](docs/screenshots/home.png)
-->

---

## ✨ Features

| Area | What it does |
|---|---|
| **Soil scan** | Photo + optional N, P, K, pH, moisture, crop stage, organic-input question |
| **Soil health score** | 0–100 score with colour-coded bars per parameter |
| **Crop suitability** | Best-fit crop plus alternatives, scored against N/P/K/pH ranges |
| **What your soil needs** | Primary issue plus plain-language impact |
| **Action plan & fertilizer table** | 4-step plan, and Increase / Maintain / Reduce per nutrient with a "Why?" |
| **Weather-aware advice** | Real forecast for your location, e.g. "Rain expected tomorrow, consider delaying fertilizer" |
| **Listen to Report** | On-device text-to-speech in the selected language |
| **Government schemes** | 100 Maharashtra schemes with search, category and government filters, plus **Recommended For You** matched to your soil report with reasons |
| **Farmer profile** | Name, state, district, land size, crops, standing organic-input preference |
| **History & trends** | Soil-health trend chart that survives app restarts |
| **7 languages** | English, Hindi, Marathi, Kannada, Tamil, Gujarati, Telugu |

---

## 🧠 How the intelligence works

KrishiNetra is **hybrid by design**:

- **Local rule-based engines (no key needed):** health scoring, crop suitability, primary-issue detection, fertilizer dosing, weather advisories and scheme matching are all deterministic and reproducible.
- **Gemini (optional):** if an API key is configured, Gemini analyses the photo (disease/pest detection) and writes the agronomist summary. Without a key the app falls back to the local engine and never hard-fails.
- **Translation:** static UI strings are pre-translated (works offline). Dynamically generated text (AI summaries, chat) is translated at runtime via Sarvam, with Bhashini as fallback.

---

## 🛠 Tech stack

- **Framework:** Flutter / Dart (currently built for Web)
- **AI:** Google Gemini API (optional)
- **Translation:** Sarvam AI API, Bhashini API (fallback); custom i18n generator for static strings
- **Voice:** `flutter_tts` (on-device)
- **Location & weather:** `geolocator`, Open-Meteo (keyless), BigDataCloud reverse geocoding (keyless)
- **Storage:** `shared_preferences` (language, profile, history trend)
- **Media / network:** `image_picker`, `http`
- **Data:** bundled JSON dataset of Maharashtra agricultural schemes
- **Hosting:** Firebase Hosting (see `firebase.json`)

---

## 📁 Project structure

```
lib/
  main.dart
  core/            services (weather, TTS, translation, history, auth), theme, shared widgets
  features/
    auth/          splash, language selection, login
    dashboard/     home, history, weather, navigation shell
    recommendation/  soil scan, Gemini/offline engine, report screen
    schemes/       dataset loader, matching engine, search/filter UI
    profile/       farmer profile model, storage, screen
    chatbot/       AI assistant
    landing/       landing page
  l10n/            generated localization (do not edit by hand)
tools/             l10n_data.json + generators for the l10n files
assets/            images + agriculture_schemes.json
docs/              integration and testing notes
web/               Flutter web shell
```

---

## 🚀 Getting started

**Prerequisites:** Flutter SDK (stable), Chrome.

```bash
git clone https://github.com/samruddhigangane17/Krishinetra_app.git
cd Krishinetra_app
flutter pub get
flutter run -d chrome
```

### Enabling Gemini (optional)

Pass the key at run time. **Never hard-code it in a source file.**

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key_here
```

Get a key at https://aistudio.google.com/apikey. For the Sarvam / Bhashini translation keys, see [`docs/SARVAM_INTEGRATION.md`](docs/SARVAM_INTEGRATION.md).

### Build & deploy

```bash
flutter build web --dart-define=GEMINI_API_KEY=your_key_here
firebase deploy
```

> Location (weather) requires HTTPS or localhost, which Firebase Hosting provides.

---

## 🌐 Adding or editing translations

UI strings live in `tools/gen_l10n.py` (English plus all 6 languages). After editing:

```bash
python tools/gen_l10n.py
python tools/gen_dart_l10n.py
```

This regenerates `lib/l10n/*`. Don't edit the generated files directly.

---

## ⚠️ Known limitations

- Web build only; no Android/iOS project folders yet.
- Scheme dataset covers **Maharashtra only** (the app warns if your profile state differs).
- Full report write-ups are kept for the current session; only trend numbers persist across restarts.
- Several newer screens (report cards, schemes, weather) are still English-only.
- Translations were written by hand and should be reviewed by native speakers.
- Authentication is a local demo implementation, not a production identity provider.
- Fertilizer quantities are rule-of-thumb estimates; confirm with a local agronomist or Krishi Vigyan Kendra.

---

## 🗺 Roadmap

- Persist full reports (so scheme matching survives restarts)
- Localize remaining screens
- Multi-field support
- Scheme data for more states
- Real authentication and a backend

---

## 📄 License

Add a license here (for example MIT) or state that all rights are reserved.
