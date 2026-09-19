import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Privacy-safe Firebase usage telemetry.
///
/// This is deliberately separate from the local Drift analytics engine. It
/// sends only event names: never titles, URLs, notes, file names, tags,
/// collection names, IDs, or any other library content.
class FirebaseUsageAnalytics {
  FirebaseUsageAnalytics._();

  static final FirebaseUsageAnalytics instance = FirebaseUsageAnalytics._();

  bool _initializationAttempted = false;
  FirebaseAnalytics? _analytics;

  Future<void> initialize() async {
    if (_initializationAttempted) {
      _debug('Firebase initialization already attempted; skipping duplicate call.');
      return;
    }
    _initializationAttempted = true;
    _debug('Firebase initialization started.');

    try {
      await Firebase.initializeApp();
      _debug('Firebase initialization succeeded.');
      _analytics = FirebaseAnalytics.instance;
      _debug('Firebase Analytics instance created.');
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _debug('Firebase Analytics collection enabled.');
      await _analytics!.logAppOpen();
      _debug('Firebase Analytics event attempted: app_open.');

      // Temporary connectivity signal for Firebase DebugView. The "firebase_"
      // prefix is reserved by Firebase, so this uses an app-owned event name.
      // This code is eliminated from release behavior by the debug-mode guard.
      if (kDebugMode) {
        _log('skillnest_analytics_test');
      }
    } catch (error, stackTrace) {
      // Firebase must never prevent SkillNest's offline-first app from
      // starting. Android config can be absent on non-Android test targets.
      _debug('Firebase initialization failed: $error\n$stackTrace');
      _analytics = null;
    }
  }

  void resourceCreated() => _log('resource_created');
  void resourceOpened() => _log('resource_opened');
  void resourceDeleted() => _log('resource_deleted');
  void collectionCreated() => _log('collection_created');
  void searchUsed() => _log('search_used');
  void favoriteChanged() => _log('favorite_changed');
  void noteSaved() => _log('note_saved');
  void backupCreated() => _log('backup_created');
  void backupRestored() => _log('backup_restored');
  void notificationFeatureUsed() => _log('notification_feature_used');

  void _log(String name) {
    final analytics = _analytics;
    if (analytics == null) {
      _debug('Firebase Analytics event skipped because no instance is available: $name.');
      return;
    }
    _debug('Firebase Analytics event attempted: $name.');
    _send(analytics, name);
  }

  Future<void> _send(FirebaseAnalytics analytics, String name) async {
    try {
      // No parameters are intentionally sent with any custom event.
      await analytics.logEvent(name: name);
      _debug('Firebase Analytics event accepted by SDK: $name.');
    } catch (error, stackTrace) {
      _debug('Firebase Analytics event failed: $name; error: $error\n$stackTrace');
    }
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[SkillNest Firebase] $message');
  }
}
