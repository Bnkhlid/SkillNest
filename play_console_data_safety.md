# Google Play Data Safety Declaration Guide — SkillNest

This document provides exact, code-verified responses for completing the **Data Safety** section in Google Play Console for **SkillNest** (`com.learningvault.learning_vault`).

---

## 1. Overview & Data Collection Summary

| Question in Google Play Console | Proposed Answer | Reason Based on Actual Codebase Behavior | Manual Verification Status |
| :--- | :--- | :--- | :--- |
| **Does your app collect or share any of the required user data types?** | **Yes** | The app integrates Google Firebase Analytics and Firebase Cloud Messaging (FCM), which process anonymous device IDs and app interaction telemetry. | Verified from code |
| **Is all of the user data collected by your app encrypted in transit?** | **Yes** | All network traffic (Firebase telemetry, FCM, and MetadataService link preview requests) uses HTTPS/TLS. | Verified from code |
| **Do you provide a way for users to request that their data be deleted?** | **Yes** | All user library content is stored 100% locally in an on-device SQLite database. Deleting items or uninstalling the app permanently erases all data from the device. | Verified from code |
| **Does your app allow users to create an account?** | **No** | SkillNest operates in an offline-first architecture with zero mandatory account creation or cloud login. | Verified from code |

---

## 2. Specific Data Types Breakdown

### A. Location
- **Approximate Location / Precise Location**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** SkillNest does not access device GPS or location hardware (`ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` are not requested in `AndroidManifest.xml`).
  - **Manual Verification:** Verified from code.

### B. Personal Info (Name, Email, Phone, User IDs)
- **Name / Email / User IDs**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** The user profile display name ("Mohamed") and avatar are stored strictly inside the local SQLite database and are never uploaded to any remote server.
  - **Manual Verification:** Verified from code.

### C. Financial Info (Payment info, Purchase history)
- **Financial Info**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** SkillNest has no in-app purchases, billing SDKs, or financial transactions.
  - **Manual Verification:** Verified from code.

### D. Health and Fitness
- **Health / Fitness info**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** Not applicable.
  - **Manual Verification:** Verified from code.

### E. Messages (Emails, SMS, In-app messages)
- **Messages**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** The app does not transmit emails, SMS, or chat messages.
  - **Manual Verification:** Verified from code.

### F. Photos and Videos
- **Photos / Videos**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** When users attach local files, they are processed locally on-device via Android Storage Access Framework (SAF) and copied to private app storage. No photos or media are transmitted externally.
  - **Manual Verification:** Verified from code.

### G. Audio Files
- **Voice / Sound recordings**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** Not applicable.
  - **Manual Verification:** Verified from code.

### H. Files and Docs
- **Files / Docs**:
  - **Collected:** **No**
  - **Shared:** **No**
  - **Reason:** Document attachments and backups remain strictly on the local device or user-chosen local storage.
  - **Manual Verification:** Verified from code.

### I. App Activity (App interactions)
- **App Interactions (e.g. page views, taps)**:
  - **Collected:** **Yes**
  - **Shared:** **No**
  - **Collection Purpose:** **Analytics** (Firebase Analytics)
  - **Is data ephemeral?**: **No** (aggregated on Firebase servers for analytics dashboards)
  - **Is this collection required or optional?**: **Required** (automatic with Firebase SDK)
  - **Reason:** Standard aggregated lifecycle events (`app_open`, `resource_created`, `collection_created`) are logged to understand feature usage. Content strings (titles, URLs, notes) are explicitly excluded.
  - **Manual Verification:** Verified from code.

### J. App Info and Performance
- **Crash Logs / Diagnostics**:
  - **Collected:** **Yes**
  - **Shared:** **No**
  - **Collection Purpose:** **Analytics / App functionality**
  - **Reason:** Handled by standard Firebase / Google Play services crash and performance diagnostics.
  - **Manual Verification:** Verified from code.

### K. Device or Other IDs
- **Device or other IDs (e.g. Firebase Installation ID, FCM Token)**:
  - **Collected:** **Yes**
  - **Shared:** **No**
  - **Collection Purpose:** **App functionality** (delivering push notifications via Firebase Cloud Messaging) & **Analytics**
  - **Reason:** Firebase assigns an anonymous installation identifier to route push notifications and count active app instances.
  - **Manual Verification:** Verified from code.

---

## 3. Data Safety Submission Checklist for Console

1. Navigate to **App Content** > **Data Safety** in Google Play Console.
2. Select **Yes** to "Does your app collect or share user data?".
3. Select **Yes** to "Is all data encrypted in transit?".
4. Select **Yes** to "Can users request that their data be deleted?".
5. Check only the following data types:
   - **App activity** > **App interactions** (Collected -> Analytics)
   - **App info and performance** > **Diagnostics / Crash data** (Collected -> Analytics)
   - **Device or other IDs** > **Device or other IDs** (Collected -> App functionality & Analytics)
6. Ensure all other categories (Location, Personal Info, Financial, Photos/Videos, Health) are marked as **Not collected / Not shared**.
