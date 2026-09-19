import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';

/// Enables FIAM safely and prints the FID only in Debug builds.
class FirebaseInAppMessagingService {
  FirebaseInAppMessagingService._();
  static final instance = FirebaseInAppMessagingService._();

  bool _initializationAttempted = false;

  Future<void> initialize() async {
    if (_initializationAttempted) {
      _debug('FIAM initialization already attempted; skipping duplicate call.');
      return;
    }
    _initializationAttempted = true;

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (_) {}
    }

    if (Firebase.apps.isEmpty) {
      _debug('Firebase unavailable; FIAM skipped safely.');
      return;
    }

    try {
      _debug('Firebase initialized; enabling In-App Messaging.');
      final fiam = FirebaseInAppMessaging.instance;
      await fiam.setAutomaticDataCollectionEnabled(true);
      await fiam.setMessagesSuppressed(false);
      _debug('In-App Messaging initialized/enabled.');

      if (kDebugMode) {
        try {
          final fid = await FirebaseInstallations.instance.getId();
          _debug('Installation ID retrieved.');
          debugPrint('[SkillNest FIAM debug] Firebase Installation ID: $fid');
        } catch (idError) {
          _debug('Could not retrieve Installation ID in debug mode: $idError');
        }
      }
    } catch (error, stackTrace) {
      _debug('FIAM initialization failed safely: $error\n$stackTrace');
    }
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[SkillNest FIAM] $message');
  }
}
