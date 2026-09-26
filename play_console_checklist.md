# Google Play Console Submission Checklist — SkillNest

A comprehensive pre-launch, testing, and production checklist for publishing **SkillNest** (`com.learningvault.learning_vault`).

---

## 1. Before Upload (Prerequisites)

- [ ] **Google Play Console Account**: An active Google Play Developer account is registered and verified.
- [ ] **Application Created**: App created in Google Play Console with default language set to English (US) or preferred locale.
- [ ] **Application ID Match**: Verified that the Play Console application package matches `com.learningvault.learning_vault`.
- [ ] **Upload Keystore Generated**: Upload keystore (`*.jks`) generated securely and stored in a private backup location (never committed to public Git).
- [ ] **Privacy Policy URL Hosted**: The contents of `privacy_policy.md` are hosted publicly (e.g. GitHub Pages, Notion, or personal domain) and the URL is accessible over HTTPS.
- [ ] **Store Listing Metadata Ready**: Title, Short Description, and Full Description copied from `play_store_preparation.md` or `PLAY_STORE_HANDOFF.md`.
- [ ] **Store Listing Assets Ready**:
  - [ ] App Icon (512x512 PNG, 32-bit color, max 1MB)
  - [ ] Feature Graphic (1024x500 PNG or JPEG, max 15MB)
  - [ ] Phone Screenshots (At least 2 screenshots, 16:9 or 18:9 aspect ratio, min 1080px)
- [ ] **App Content Declarations**:
  - [ ] **Privacy Policy**: Link provided.
  - [ ] **Ads**: Declare **"No, my app does not contain ads"**.
  - [ ] **App Access**: Declare **"All functionality is available without special access"** (No login/password required).
  - [ ] **Target Age & Content Rating**: Complete questionnaire (Rated for Everyone / PEGI 3 / General audience).
  - [ ] **Data Safety**: Complete the questionnaire using the answers from `play_console_data_safety.md`.
  - [ ] **Government Apps**: Declare **"No"**.
  - [ ] **Financial Features**: Declare **"None"**.

---

## 2. Release Signing & Upload

- [ ] **Create Signed Release Bundle**:
  1. Set up `android/key.properties` with your upload keystore path and passwords.
  2. Run:
     ```powershell
     flutter build appbundle --release
     ```
  3. Verify the generated bundle at `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **Upload to Google Play**:
  1. Open Google Play Console > Select **SkillNest**.
  2. Under **Release**, navigate to **Testing** > **Closed testing** (or Internal testing).
  3. Create a new release and drag/drop `app-release.aab`.
  4. Verify that Google Play detects `versionCode: 1` and `versionName: 1.0.0` with `targetSdk = 36`.
  5. Add release notes:
     ```text
     Initial production release of SkillNest - offline-first learning vault, link organizer, and study habit tracker.
     ```

---

## 3. Closed Testing Track & Verification Requirements

> [!IMPORTANT]
> **Check Account Type & Testing Requirements:**
> - **Personal Developer Accounts created after November 13, 2023**: Google Play mandates that you run a **Closed Test with at least 20 opted-in testers for at least 14 consecutive days** before applying for production access.
> - **Organization / Business Developer Accounts** (or personal accounts created before Nov 13, 2023): The 20-tester / 14-day rule does NOT mandate a 14-day block, although conducting internal or closed testing is still recommended.

### If 14-Day Closed Testing Applies:
1. Create a **Closed Testing Track** in Play Console.
2. Add a Google Group or email list with at least **20 distinct tester email addresses**.
3. Send the opt-in link to all 20 testers and ensure they accept the invite and install the app.
4. Keep the closed test active for **14 consecutive days**.
5. After 14 days, complete the Play Console questionnaire regarding tester feedback and apply for Production Access.

---

## 4. Production Release

- [ ] Navigate to **Release** > **Production** in Google Play Console.
- [ ] Create a new release (or promote the release from Closed Testing).
- [ ] Select the verified `app-release.aab`.
- [ ] Review release rollout percentage (100% full rollout or phased rollout).
- [ ] Click **Save** and **Start rollout to Production**.
- [ ] Monitor Google Play Review status (typically 1 to 3 business days).
