# SkillNest — Google Play Store Production Preparation Guide

This document contains all the information, metadata, store listing copy, Data Safety questionnaire answers, keystore setup instructions, and the final audit checklist required for Google Play Store submission.

---

## 1. Application Identity & Versioning

- **App Name:** SkillNest
- **Package Name (Application ID):** `com.learningvault.learning_vault`
- **Version Name:** `1.0.0`
- **Version Code:** `1`
- **Min SDK:** `24` (Android 7.0 Nougat — 99.8%+ device compatibility)
- **Target SDK:** `36` (Android 16 — satisfies Google Play 2026 requirements)
- **Compile SDK:** `36`

---

## 2. Release Signing Setup (Upload Keystore)

To produce your signed production Android App Bundle (`.aab`) for Google Play:

### Step A: Generate your upload keystore (Run in PowerShell / Terminal once):
```powershell
keytool -genkey -v -keystore d:\SkillNest\learning_vault\android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*(Enter a secure password when prompted and note it down).*

### Step B: Create `android/key.properties`:
Create a file at `d:\SkillNest\learning_vault\android\key.properties` (this file is git-ignored):
```properties
storeFile=upload-keystore.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

### Step C: Build your production release bundle:
```powershell
flutter build appbundle --release
```
The resulting file will be located at:
`build/app/outputs/bundle/release/app-release.aab`

---

## 3. Google Play Store Listing Metadata Draft

### App Title (Max 30 characters)
> **SkillNest: Learning Library**

### Short Description (Max 80 characters)
> **Organize links, notes & documents in a clean, offline-first personal library.**

### Full Description (Max 4000 characters)
> **SkillNest** is your focused, offline-first personal knowledge vault and learning library. Designed with a clean Neo-Brutalist visual identity, SkillNest helps students, developers, researchers, and lifelong learners capture, categorize, and retain valuable information without clutter or distraction.
>
> 🚀 **Key Features:**
> • **Fast Capture & Sharing:** Share links, articles, and text directly from browsers and social apps into your inbox in a single tap.
> • **Hierarchical Collections:** Organize your learning journey with nested collections, color-coded accents, and custom emojis.
> • **Interactive Sticky Notes:** Jot down quick takeaways, action items, and study checklists on colorful digital sticky notes.
> • **Smart In-App Reader & Quick Preview:** Long-press any card for a rich preview, or switch to clean Reader Mode for uninterrupted reading.
> • **Offline-First & Private:** Your library, notes, and local files reside 100% on your device in an encrypted SQLite database. No account required.
> • **Full Integrity Backups:** Export and import full vault backups as SHA-256 verified ZIP archives whenever you want.
> • **Smart Reminders & Streak Tracking:** Stay consistent with customizable learning notifications and study analytics.
>
> 🔒 **Privacy by Design:**
> We believe your knowledge belongs to you. SkillNest does not require sign-up, does not track your reading content, and stores your entire vault offline on your device.

### Category & Tags
- **Primary Category:** Education (or Productivity)
- **Tags:** Learning, Notes, Bookmarks, Productivity, Study, Personal Knowledge Management

---

## 4. Google Play Data Safety Declaration

When completing the **Data Safety** questionnaire in Google Play Console, answer as follows:

| Question | Answer |
| :--- | :--- |
| **Does your app collect or share user data?** | **Yes** *(due to Firebase Analytics/FCM telemetry)* |
| **Is all user data encrypted in transit?** | **Yes** *(all Firebase network traffic uses HTTPS/TLS)* |
| **Do you provide a way for users to request data deletion?** | **Yes** *(users can permanently delete all data in-app or by uninstalling)* |

### Data Types Breakdown:
1. **App Activity / App Info & Performance:**
   - **Data Collected:** Diagnostics / Crash Data / Device or Other IDs (Firebase Installation ID & FCM Token).
   - **Purpose:** App functionality, Analytics.
   - **Is it linked to user identity?** **No** (all metrics are anonymized and not linked to personal identity).
2. **Personal Info / Financial / Health / Location:**
   - **Collected?** **No** (None).
3. **User Content (Photos, Videos, Files, Notes, URLs):**
   - **Collected or Shared?** **No** (All user content remains 100% on-device in the local SQLite database).

---

## 5. Google Play Testing Requirements (Personal Accounts)

> [!IMPORTANT]
> If your Google Play Developer Account was created after **November 13, 2023** as a **Personal Account**, Google requires:
> 1. Running a **Closed Test** with at least **12 opted-in testers**.
> 2. Testers must remain opted-in for at least **14 consecutive days**.
> 3. After completing the 14-day test, apply for Production Access in the Play Console dashboard.

---

## 6. Comprehensive Pre-Release Audit Table

| Category | Status | Details | Action Required |
| :--- | :--- | :--- | :--- |
| **Target SDK** | **PASS** | Set to API 36 (Android 16) | None |
| **Compile SDK** | **PASS** | Set to API 36 | None |
| **Min SDK** | **PASS** | Set to API 24 (Android 7.0+) | None |
| **Release Signing** | **PASS** | `key.properties` dynamic loading configured with debug fallback for local dev | Create `key.properties` before production upload |
| **Application ID** | **PASS** | `com.learningvault.learning_vault` verified | None |
| **Version Code** | **PASS** | `1` (Version `1.0.0+1`) | None |
| **R8 / Code Shrinking** | **PASS** | `isMinifyEnabled = true` with tailored `proguard-rules.pro` | None |
| **Permissions** | **PASS** | Minimum necessary: `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`. No dangerous storage permissions | None |
| **Android Backup** | **PASS** | Custom `data_extraction_rules.xml` & `backup_rules.xml` configured | None |
| **Firebase / FCM** | **PASS** | Client configuration verified. No server keys or secrets in client code | None |
| **Privacy Policy** | **PASS** | Comprehensive `privacy_policy.md` created matching code | Host at public URL for Play Console |
| **Data Safety** | **PASS** | Factual responses drafted based on actual code | Enter answers into Play Console |
| **Adaptive Icon** | **PASS** | Branded vector adaptive icon (`@mipmap-anydpi-v26/ic_launcher.xml`) | None |
| **Splash Screen** | **PASS** | Branded Android 12+ splash theme (`#D0F4F0` background) | None |
| **Unit & Widget Tests** | **PASS** | All 214 tests passing 100% | None |
| **Store Listing** | **PASS** | Title, short & full descriptions, tags prepared | Copy into Play Console |
