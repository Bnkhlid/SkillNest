import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../vault.dart';

/// Handles Firebase Cloud Messaging without storing or uploading user data.
///
/// Console notification messages are displayed by Android itself while the app
/// is in the background. Foreground notification messages are shown through
/// the established local-notification service and its existing general channel.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  bool _initializationAttempted = false;
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  StreamSubscription<RemoteMessage>? _openedMessages;
  StreamSubscription<String>? _tokenRefreshes;
  AppLifecycleListener? _lifecycleListener;

  Future<void> initialize() async {
    if (_initializationAttempted) return;
    _initializationAttempted = true;

    try {
      // FirebaseUsageAnalytics initializes the default app first. This guard
      // also keeps messaging harmless on unsupported/test platforms.
      if (Firebase.apps.isEmpty) {
        _debug('FCM skipped because Firebase is unavailable.');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      _foregroundMessages = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
        onError: _onStreamError,
      );
      _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _addRemoteNotificationToBell(message),
        onError: _onStreamError,
      );
      _tokenRefreshes = messaging.onTokenRefresh.listen(
        (_) => _debug('FCM registration token refreshed.'),
        onError: _onStreamError,
      );

      // Listen for app resuming to foreground so notifications delivered while
      // the app was backgrounded are automatically synchronized to the in-app bell.
      _lifecycleListener?.dispose();
      _lifecycleListener = AppLifecycleListener(
        onResume: () {
          unawaited(Vault.I.syncActiveSystemNotifications());
        },
      );

      if (!kIsWeb && Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Do not request POST_NOTIFICATIONS here. SkillNest already asks only
      // from its explicit "Enable & test notifications" action, avoiding an
      // unexpected or repeated Android 13+ permission prompt.
      final settings = await messaging.getNotificationSettings();
      _debug(
        'FCM notification permission status: ${settings.authorizationStatus.name}.',
      );

      // The token remains on-device/Firebase only; it is never logged, stored,
      // or sent to an app backend.
      final token = await messaging.getToken();
      if (token == null) {
        _debug('FCM registration token unavailable.');
      } else {
        _debug('FCM registration token obtained.');
        // DEBUG-ONLY: copy this from Logcat when testing a Firebase Console
        // device-targeted message. It is never stored, sent to Analytics, or
        // emitted in release builds.
        if (kDebugMode) debugPrint('[SkillNest FCM debug token] $token');
      }

      // Covers an Android notification that launched a terminated app.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _addRemoteNotificationToBell(initialMessage);
      }

      // Synchronize any notifications already waiting in the system notification tray.
      unawaited(Vault.I.syncActiveSystemNotifications());
    } catch (error, stackTrace) {
      _debug('FCM initialization failed safely: $error\n$stackTrace');
      await _cancelListeners();
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final content = _extractMessageContent(message);
      if (content == null) {
        _debug('FCM foreground notification had no visible content.');
        return;
      }

      Vault.I.addNotification(
        title: content.$1,
        body: content.$2,
        // Reuses the existing local notification channel and also adds this
        // message to the in-app bell, like other SkillNest notifications.
        pushLocal: true,
      );
      _debug('FCM foreground notification added to the in-app bell.');
    } catch (error, stackTrace) {
      _debug('FCM foreground notification failed safely: $error\n$stackTrace');
    }
  }

  void _addRemoteNotificationToBell(RemoteMessage message) {
    try {
      final content = _extractMessageContent(message);
      if (content == null) {
        _debug('FCM notification opened without visible content.');
        return;
      }
      Vault.I.addNotification(
        title: content.$1,
        body: content.$2,
        // Android already showed this background notification in the system
        // tray, so do not create a second system notification after its tap.
        pushLocal: false,
      );
      _debug('FCM notification added to the in-app bell after open.');
    } catch (error, stackTrace) {
      _debug(
        'FCM opened-notification handling failed safely: $error\n$stackTrace',
      );
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _debug('FCM stream failed safely: $error\n$stackTrace');
  }

  Future<void> _cancelListeners() async {
    await _foregroundMessages?.cancel();
    await _openedMessages?.cancel();
    await _tokenRefreshes?.cancel();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _foregroundMessages = null;
    _openedMessages = null;
    _tokenRefreshes = null;
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[SkillNest FCM] $message');
  }
}

/// Helper that extracts title and body from both notification payload
/// and custom data payloads sent via Firebase Console or Admin SDK.
(String, String)? _extractMessageContent(RemoteMessage message) {
  final notif = message.notification;
  final title = notif?.title ??
      message.data['title'] as String? ??
      message.data['notification_title'] as String?;
  final body = notif?.body ??
      message.data['body'] as String? ??
      message.data['message'] as String? ??
      message.data['notification_body'] as String? ??
      '';
  if ((title == null || title.isEmpty) && body.isEmpty) {
    return null;
  }
  return (title?.isNotEmpty == true ? title! : 'SkillNest', body);
}

/// Must remain a top-level entry point for Android's background isolate.
/// Android displays normal FCM notification messages in the system tray while
/// backgrounded; this handler persists the notification so it is visible in the bell.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final content = _extractMessageContent(message);
    if (content != null) {
      await _persistBackgroundNotification(content.$1, content.$2);
    }
    if (kDebugMode) debugPrint('[SkillNest FCM] Background message received and recorded.');
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        '[SkillNest FCM] Background handling failed safely: $error\n$stackTrace',
      );
    }
  }
}

Future<void> _persistBackgroundNotification(String title, String body) async {
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocDir.path, 'skillnest'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'app_notifications.json'));
    List<dynamic> list = [];
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        list = jsonDecode(content) as List<dynamic>;
      } catch (_) {}
    }
    final alreadyExists = list.any(
      (item) => item is Map && item['title'] == title && item['body'] == body,
    );
    if (!alreadyExists) {
      list.insert(0, {
        'id': 'n_${DateTime.now().microsecondsSinceEpoch}',
        'title': title,
        'body': body,
        'read': false,
        'resourceId': null,
      });
      if (list.length > 50) list = list.sublist(0, 50);
      await file.writeAsString(jsonEncode(list));
    }
  } catch (_) {}
}

