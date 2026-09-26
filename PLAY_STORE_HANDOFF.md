# SkillNest — Google Play Store Handoff Package

This document outlines the complete release package provided to the Google Play Console account owner to publish **SkillNest** (`com.learningvault.learning_vault`).

---

## 1. What Is Provided In This Package ("I Provide")

### A. Core Build Artifacts & Identification
- **Production Artifact**: Android App Bundle (`app-release.aab`) located at `build/app/outputs/bundle/release/app-release.aab`
- **Application ID / Package Name**: `com.learningvault.learning_vault`
- **Version Name**: `1.0.0`
- **Version Code**: `1`
- **Minimum Android SDK**: API 24 (Android 7.0+)
- **Target Android SDK**: API 36 (Android 16, meets Google Play requirements)

### B. Documentation & Console Declarations
- **[privacy_policy.md](file:///d:/SkillNest/learning_vault/privacy_policy.md)**: Full offline-first privacy policy ready to be hosted at a public HTTPS URL.
- **[play_console_data_safety.md](file:///d:/SkillNest/learning_vault/play_console_data_safety.md)**: Exact answers for Google Play Data Safety form.
- **[play_console_checklist.md](file:///d:/SkillNest/learning_vault/play_console_checklist.md)**: Step-by-step checklist from pre-upload to closed testing and production rollout.

### C. Store Listing Copy

**App Title (30 characters max):**
`SkillNest: Learn & Save Vault`

**Short Description (80 characters max):**
`Save links, organize learning resources, and track your study habits offline.`

**Full Description (4000 characters max):**
```text
SkillNest is your personal offline-first learning companion designed to help you capture, organize, and retain knowledge from across the web.

Key Features:
- Quick Capture: Share links and resources straight into your vault from any app.
- Neo-Brutalist Interface: High-contrast, distraction-free design crafted for focus.
- 100% Offline-First: All your bookmarks, notes, and collections stay on your device in a secure SQLite database.
- Smart Analytics: Track daily study streaks, review completion rates, and analyze your learning patterns.
- Tags & Collections: Organize your knowledge base with custom categories and instant full-text search.
- Complete Privacy: Zero data tracking, zero ad profiling, and zero personal data sharing.

Take control of your learning journey today with SkillNest.
```

### D. Store Graphics Checklist
- **App Icon (512x512)**: Extracted from adaptive launcher icon in `android/app/src/main/res/drawable/skillnest_launch_icon.png`.
- **Feature Graphic (1024x500)**: `MISSING — MANUAL ACTION REQUIRED` (Needs high-res banner asset prepared for Google Play listing).
- **Phone Screenshots**: Captured from device and available in artifact directory (`verify_production_release.png`, `verify_analytics2.png`, `verify_search_results3.png`, `verify_stickynote_list.png`, `verify_settings_landscape.png`).

---

## 2. What The Account Owner Does ("My Friend Does")

1. **Host the Privacy Policy**:
   - Host the markdown/HTML from `privacy_policy.md` on a publicly accessible HTTPS website (e.g. GitHub Pages, Notion, or personal domain).
2. **Create the App in Google Play Console**:
   - App Name: `SkillNest: Learn & Save Vault`
   - Default Language: English (United States)
   - App or Game: `App`
   - Free or Paid: `Free`
3. **Fill Out App Content Declarations**:
   - **Privacy Policy**: Paste your public HTTPS URL.
   - **Ads**: Select "No, my app does not contain ads".
   - **App Access**: Select "All functionality is available without special access".
   - **Target Audience / Content Rating**: Complete questionnaire (Rated Everyone / PEGI 3).
   - **Data Safety**: Fill out using the pre-filled guide in `play_console_data_safety.md`.
4. **Set Up Store Listing**:
   - Paste the Title, Short Description, and Full Description.
   - Upload 512x512 icon, 1024x500 feature graphic, and phone screenshots.
5. **Upload the AAB & Handle Release Signing**:
   - Either:
     - Use Google Play App Signing with the upload-key signed bundle provided, or
     - Build/re-sign the `.aab` using your private production keystore (`android/key.properties`).
6. **Testing & Production Rollout**:
   - If your account is a personal account created after Nov 13, 2023, recruit 20 testers for 14-day closed testing before applying for production access.
   - If your account is an organization or older personal account, proceed with internal testing and launch directly to production.

---

## 3. Security Notice — Zero Secrets in This Package

This package strictly excludes:
- `key.properties` (Signing credentials)
- `*.jks` / `*.keystore` (Private keystores)
- Keystore / alias passwords
- Firebase server / service account secrets
- Private API credentials
