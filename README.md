# SkillNest 📚

A premium, 100% offline-first personal learning library built with Flutter (Material 3 & Neo-Brutalist design).

Save articles, videos, PDFs, and notes from anywhere (including system-wide share sheet on Android and iOS), organize them into nested collections, track what you actually finish, and see it all in offline analytics.

---

## 🚀 Getting Started & Building

### Prerequisites
- **Flutter SDK**: 3.12+ (or latest 3.24+)
- **Android Studio / Android SDK**: For Android builds
- **Xcode 15+ & CocoaPods**: For iOS builds (on macOS)

### 1. Android Build

```bash
# Get dependencies
flutter pub get

# Run on connected Android device/emulator
flutter run

# Build release APK
flutter build apk --release

# Build Google Play App Bundle (AAB)
flutter build appbundle --release
```

### 2. iOS Build (macOS)

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Install CocoaPods dependencies
cd ios && pod install && cd ..

# 3. Build iOS release
flutter build ios --release

# Or open in Xcode for codesigning / archiving:
open ios/Runner.xcworkspace
```

### 3. Tests & Code Quality

```bash
# Analyze code (0 issues)
flutter analyze

# Run full test suite (238/238 automated tests pass)
flutter test
```

---

## 🎨 Design System

| Token | Value |
|---|---|
| Spacing grid | 8px scale (4/8/16/24/32) — `app_theme.dart → Insets` |
| Card radius | 12px (`Radii.card`), sheets & dialogs 24px |
| Touch targets | ≥44px everywhere (`Touch.min`, padded tap targets) |
| Accent | Calm teal `#0F6E5F` (light) / `#86D3C1` (dark) |
| Typography | Default San Francisco / Roboto stack, tight letter-spacing on titles |
| Themes | Full light + dark via `ThemeMode` (System / Light / Dark in Settings) |

All colors come from a hand-tuned `ColorScheme` (M3) in `lib/app_theme.dart`.

---

## 📱 Features & Highlights

- **100% Offline-First SQLite**: Backed by Drift with immediate persistence and reactive streams.
- **Universal Share Extension**: Share links, posts, and text directly from Safari, Chrome, Twitter/X, Instagram, LinkedIn, YouTube, Facebook, Reddit on both Android and iOS.
- **Nested Collections**: Create parent and sub-collections with full hierarchy preservation during backup and restore.
- **Full-Text Search & Multi-filter**: Instant search across titles, URLs, tags, sources, notes, and collections.
- **Local Analytics Engine**: Offline computation of 8 KPI metrics, completion rates, source distribution, and weekly activity charts.
- **Encrypted & Safe Backup/Restore**: Export and import complete library archives (`.zip`) safely.
- **Smart Reminders**: Scheduled local morning/evening digests and weekly reviews.

---

## 📂 Architecture

- `lib/core/database/` — Drift SQLite database, DAOs, schema definitions, and migrations.
- `lib/core/services/` — Share sheet parsing, local notifications, backup/restore services, remote config.
- `lib/models.dart` — Immutable domain models (`ResourceItem`, `CollectionModel`, `TrashEntry`, `SearchFilters`).
- `lib/vault.dart` — In-memory reactive state manager and coordinator with the SQLite database.
- `lib/screens/` — UI screens (Home, Search, Collections, Add Resource, Details, Viewer, Analytics, Settings, Trash, Sticky Notes).
- `lib/widgets/` — Reusable Neo-Brutalist components and custom painted charts.
