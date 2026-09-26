# SkillNest — ProGuard / R8 Rules for Production Release
# Keep rules for libraries used in SkillNest

# --- Flutter Engine & Core ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# --- Drift / SQLite3 Native Libs ---
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }
-dontwarn org.sqlite.**
-dontwarn sqlite3.**

# --- Flutter Local Notifications ---
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- File Picker & OpenFilex ---
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.crazecoder.openfilex.** { *; }

# --- Firebase Services ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
