<div align="center">
  <img src="assets/images/logo_new.png" width="120" alt="Qur'an App Logo" />

  <h1>Qur'an</h1>

  <p>A full-featured, offline-first Quran app built with Flutter.<br/>Reads beautifully, searches intelligently, works without an internet connection.</p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white" />
    <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white" />
    <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-39FF14?style=flat" />
    <img src="https://img.shields.io/badge/Offline-First-brightgreen?style=flat" />
    <img src="https://img.shields.io/badge/AI-On--Device%20BERT-blueviolet?style=flat&logo=onnx" />
    <img src="https://img.shields.io/badge/License-Open%20Source-lightgrey?style=flat" />
  </p>
</div>

---

## Features

### Reading

- **Two Arabic scripts** — Indopak and Utsmani (Hafs)
- **Bismillah rendering** with a dedicated calligraphy font
- **Tajweed coloring** — 7 rules color-coded (Ghunna, Idghaam, Iqlaab, Ikhfaa, Qalqalah, and more)
- **Word-by-word translations** in 16+ languages: English, Urdu, Bengali, Indonesian, Turkish,
  Tamil, Sindhi, Russian, Farsi, Malayalam, Hindi, German, French, Divehi, Chinese, and more
- **Tafseer** (commentary) with expandable inline view
- **Transliteration** (Latin pronunciation) alongside Arabic text
- Browse by **Surah** or **Juz**
- Chapter and Juz background information

### Audio

- Stream or download recitations (Mishary Alafasy, 128kbps)
- Auto-play continuous playback across verses
- Per-surah download management with progress indicator
- Autoscroll to the playing verse

### Search

- **Semantic search** — on-device BERT model finds verses by concept, not just keywords ("I'm
  feeling anxious", "gratitude", "patience in hardship")
- **Hybrid ranking** — semantic similarity boosted by keyword relevance
- **Keyword fallback** — SQL LIKE search when the model isn't loaded
- **Surah name search** — English, Malay, Indonesian, Bangla, Urdu, French
- **Transliteration search** — find verses by how they sound in Latin script

### Bookmarks & Progress

- **Folder-based bookmarks** — organize saved verses into named folders
- **Reading progress** — auto-saves last read position (per surah and per juz)
- **Offline-first sync** — bookmarks saved locally immediately, synced to cloud when signed in
- **Guest mode** — works fully offline without an account

### Personalization

- Light / Dark / System theme (neon green accent on Material Design 3)
- Adjustable Arabic font size (20–50pt) and translation font size
- Toggle word-by-word, tafseer, tajweed, and reading mode independently
- All preferences persisted locally

### Android Home Widget

- Add a verse widget to your home screen
- Manage a playlist of verses (add, remove, shuffle)
- Navigation controls directly from the widget

---

## Tech Stack

| Layer            | Technology                                        |
|------------------|---------------------------------------------------|
| Framework        | Flutter (Dart), Material Design 3                 |
| State management | `provider` (ChangeNotifier)                       |
| Local database   | SQLite via `sqflite` (Quran.db, tafseer.db)       |
| Cloud backend    | Supabase (auth + bookmark sync)                   |
| On-device AI     | ONNX Runtime + BERT (22 MB model)                 |
| Audio            | `audioplayers` + EveryAyah CDN                    |
| Smooth lists     | `scrollable_positioned_list`                      |
| HTML rendering   | `flutter_widget_from_html`                        |
| Fonts            | Custom Arabic fonts: Hafs, QalamMajeed, Besmallah |

---

## Architecture

```
lib/
├── main.dart
├── providers/        # SettingsProvider (theme, fonts, last read, prefs)
├── screens/          # One file per screen
│   ├── home_screen.dart
│   ├── surah_detail_screen.dart
│   ├── juz_detail_screen.dart
│   ├── contextual_search_screen.dart
│   ├── bookmarks_screen.dart
│   ├── auth_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   └── widget_settings_screen.dart
├── services/
│   ├── database_service.dart          # SQLite read/write
│   ├── audio_service.dart             # Download + playback
│   ├── semantic_search_service.dart   # Hybrid BERT + keyword search
│   ├── onnx_bert_service.dart         # On-device BERT inference
│   ├── bert_tokenizer.dart            # WordPiece tokenizer
│   ├── tajweed_service.dart           # Arabic rule coloring
│   ├── supabase_service.dart          # Auth + cloud sync
│   └── widget_service.dart            # Android home widget
├── models/           # Surah, Ayah, TafseerEmbedding, SearchResult
├── data/             # Static juz boundary data
└── widgets/          # AutoHideScrollbar, shared UI components

assets/
├── databases/        # Quran.db, quran_tafsir.db (bundled, read-only)
├── models/           # model.onnx, tokenizer.json, vocab.txt
├── embeddings/       # tafseer_embeddings.bin (pre-computed)
├── fonts/            # Arabic calligraphy fonts
└── images/           # App logo, icons
```

---

## Local Databases

The app ships two read-only SQLite databases:

| Database          | Contents                                                                                                                      |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------|
| `Quran.db`        | Verses (Indopak + Utsmani), translations (Sahih International, Jalalayn), transliterations, word-by-word data, surah metadata |
| `quran_tafsir.db` | Tafseer commentary with pre-computed BERT embeddings for semantic search                                                      |

A third database (`quran_app.db`) is created at runtime for bookmarks and reading progress.

---

## Semantic Search

Search works entirely on-device using a quantized BERT model (~22 MB):

1. User query → WordPiece tokenizer → `model.onnx` (ONNX Runtime)
2. Mean-pooled, L2-normalized 768-dim embedding
3. Cosine similarity against 6,236 pre-computed tafseer embeddings
4. Scores boosted by keyword relevance from the translation database
5. Top results hydrated with verse text from SQLite

If the model hasn't loaded yet, the app falls back to SQL LIKE keyword search automatically.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.x
- Android SDK (API 21+) or Xcode (iOS 12+)
- A [Supabase](https://supabase.com) project (optional — only needed for cloud bookmark sync)

### Setup

```bash
git clone https://github.com/your-username/quran.git
cd quran/quran_flutter_app
flutter pub get
```

Add your Supabase credentials to `lib/main.dart`:

```dart
await
Supabase.initialize
(
url: 'YOUR_SUPABASE_URL',
anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

The app works fully offline without Supabase — signing in is optional.

### Run

```bash
flutter run                  # debug on connected device
flutter run --release        # release build
flutter build apk            # Android APK
flutter build ios            # iOS
```

### Regenerate App Icon

```bash
dart run flutter_launcher_icons
```

---

## Platform Support

| Platform | Status                                |
|----------|---------------------------------------|
| Android  | ✅ Full support (API 21+), home widget |
| iOS      | ✅ Full support                        |
| Web      | ✅ PWA                                 |
| macOS    | ✅ Desktop                             |
| Windows  | ✅ Desktop                             |
| Linux    | ✅ Desktop                             |

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

---

## License

This project is open source. Quran text and translations are in the public domain.
