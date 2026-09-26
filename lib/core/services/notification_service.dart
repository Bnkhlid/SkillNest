import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isTestMode =>
      kIsWeb || !Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS;

  // Channel IDs
  static const String channelGeneral = 'skillnest_general';
  static const String channelReminders = 'skillnest_reminders';
  static const String channelCapture = 'skillnest_capture';
  // One recurring notification per weekday means the message changes every
  // day, while Android/iOS still keep the schedule after the app is closed.
  static const int _morningReminderBaseId = 9200;
  static const int _eveningReminderBaseId = 9210;
  static const int _weeklyReminderId = 9220;
  static const List<(String, String)> _morningPrompts = [
    (
      'Good morning',
      'Start small: open one saved lesson and give it ten focused minutes.',
    ),
    ('A fresh start', 'Choose one task that will make today feel productive.'),
    (
      'Small steps count',
      'Your next skill grows with one short learning session.',
    ),
    (
      'Your learning space is ready',
      'Revisit something you saved and turn it into progress.',
    ),
    ('One focused session', 'Pick a lesson, silence distractions, and begin.'),
    ('Make room to grow', 'A tiny task completed today is still a win.'),
    (
      'Open SkillNest',
      'Plan one useful thing to learn before the day gets busy.',
    ),
  ];
  static const List<(String, String)> _eveningPrompts = [
    (
      'Good night',
      'Take two minutes to organise tomorrow, then give yourself proper rest.',
    ),
    (
      'Close the day well',
      'Mark what you finished and choose one gentle priority for tomorrow.',
    ),
    (
      'Tomorrow starts tonight',
      'Clear one small task from your mind before you sleep.',
    ),
    (
      'A calmer morning',
      'Set tomorrow’s first task now so you can rest without overthinking.',
    ),
    (
      'Wind down gently',
      'Review your day, save anything useful, and protect your sleep.',
    ),
    (
      'Two-minute reset',
      'Organise your next step now—future you will thank you.',
    ),
    (
      'Rest with a clear mind',
      'Finish or plan one task, then switch off and recharge.',
    ),
  ];
  bool _timeZoneReady = false;

  /// Initializes local notifications with platform settings.
  Future<void> init({bool requestPermissionOnStartup = false}) async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      // Create Android Notification Channels
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelGeneral,
              'General Notifications',
              description: 'General SkillNest updates and notifications',
              importance: Importance.defaultImportance,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelReminders,
              'Learning Reminders',
              description:
                  'Reminders to revisit unread saves and daily digests',
              importance: Importance.high,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelCapture,
              'Capture & Files',
              description: 'Background capture and local file attachments',
              importance: Importance.low,
            ),
          );

          if (requestPermissionOnStartup) {
            await androidPlugin.requestNotificationsPermission();
          }
        }
      }

      _isInitialized = true;
      // A timezone lookup must never prevent normal/local notifications.
      try {
        await _configureTimeZone();
      } catch (e) {
        debugPrint('Timezone configuration warning: $e');
      }
    } catch (e) {
      debugPrint(
        'NotificationService init warning (ignored in test/fallback): $e',
      );
      _isInitialized = true; // Mark initialized in fallback mode
    }
  }

  Future<void> _configureTimeZone() async {
    if (_timeZoneReady || isTestMode) return;
    tz_data.initializeTimeZones();
    final deviceZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceZone.identifier));
    _timeZoneReady = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Explicitly requests notification permissions on Android 13+ & iOS.
  Future<bool> requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final darwinPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await darwinPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<bool> notificationsAllowed() async {
    try {
      await init();
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final darwinPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final permissions = await darwinPlugin?.checkPermissions();
        return permissions?.isEnabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Requests permission, schedules the reminders, and sends an immediate test.
  Future<bool> enableAndTestLearningReminders({
    required bool morningEnabled,
    required bool eveningEnabled,
    required bool weeklyEnabled,
    required int morningMinutes,
    required int eveningMinutes,
    String userName = '',
  }) async {
    await init();
    await requestPermissions();
    if (!await notificationsAllowed()) return false;
    await configureLearningReminders(
      morningEnabled: morningEnabled,
      eveningEnabled: eveningEnabled,
      weeklyEnabled: weeklyEnabled,
      morningMinutes: morningMinutes,
      eveningMinutes: eveningMinutes,
      userName: userName,
    );
    await showNotification(
      id: 9100,
      title: 'SkillNest notifications are on',
      body: 'Your learning reminders are ready.',
      channelId: channelReminders,
      payload: 'notification_test',
    );
    return true;
  }

  /// Shows a local notification safely with channel configuration.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelGeneral,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == channelReminders
            ? 'Learning Reminders'
            : (channelId == channelCapture
                  ? 'Capture & Files'
                  : 'General Notifications'),
        importance: channelId == channelReminders
            ? Importance.high
            : (channelId == channelCapture
                  ? Importance.low
                  : Importance.defaultImportance),
        priority: channelId == channelReminders
            ? Priority.high
            : Priority.defaultPriority,
      );

      const darwinDetails = DarwinNotificationDetails();
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification display failed safely (non-blocking): $e');
    }
  }

  /// Notification for background metadata/capture completion.
  Future<void> showCaptureCompleteNotification({
    required String resourceTitle,
    String? source,
  }) async {
    final sub = (source != null && source.isNotEmpty) ? ' ($source)' : '';
    await showNotification(
      id: resourceTitle.hashCode,
      title: 'Resource Saved',
      body: '"$resourceTitle" has been captured to your library.$sub',
      channelId: channelCapture,
    );
  }

  /// Alias for capture success notification
  Future<void> showCaptureSuccess({required String title, String? source}) =>
      showCaptureCompleteNotification(resourceTitle: title, source: source);

  /// Notification for backup completion.
  Future<void> showBackupCompleteNotification({
    required int resourceCount,
    String? filePath,
  }) async {
    await showNotification(
      id: 9991,
      title: 'Backup Created',
      body: 'Successfully backed up $resourceCount resources to safe archive.',
      channelId: channelGeneral,
      payload: filePath,
    );
  }

  /// Alias for backup success notification
  Future<void> showBackupSuccess({required int itemCount, String? filePath}) =>
      showBackupCompleteNotification(
        resourceCount: itemCount,
        filePath: filePath,
      );

  /// Notification for daily digest.
  Future<void> showDailyDigest({required int unreadCount}) async {
    await showNotification(
      id: 9992,
      title: 'Daily Reading Digest',
      body: 'You have $unreadCount unread resources waiting in your library.',
      channelId: channelReminders,
    );
  }

  /// Notification for unread reminder.
  Future<void> showReminder({
    required String title,
    required int daysUnread,
  }) async {
    await showNotification(
      id: title.hashCode,
      title: 'Revisit Save',
      body: '"$title" has been waiting in your library for $daysUnread days.',
      channelId: channelReminders,
    );
  }

  /// Notification for daily digest / unread reminder.
  Future<void> showReminderNotification({
    required String title,
    required String body,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: channelReminders,
    );
  }

  /// Schedules gentle, recurring learning prompts using the device's local time.
  /// Android uses inexact alarms, so it does not require the restricted exact-alarm permission.
  Future<bool> configureLearningReminders({
    required bool morningEnabled,
    required bool eveningEnabled,
    required bool weeklyEnabled,
    required int morningMinutes,
    required int eveningMinutes,
    String userName = '',
    bool requestPermission = false,
  }) async {
    await init();
    if (isTestMode) return true;
    if (requestPermission && !await requestPermissions()) return false;
    await _configureTimeZone();
    // Also remove the old fixed daily reminders from previous app versions.
    await _plugin.cancel(id: 9101);
    await _plugin.cancel(id: 9102);
    await _plugin.cancel(id: 9103);
    for (var day = 0; day < 7; day++) {
      await _plugin.cancel(id: _morningReminderBaseId + day);
      await _plugin.cancel(id: _eveningReminderBaseId + day);
    }
    await _plugin.cancel(id: _weeklyReminderId);

    final name = userName.trim().isEmpty ? '' : ', ${userName.trim()}';
    if (morningEnabled) {
      for (var day = 0; day < _morningPrompts.length; day++) {
        final prompt = _morningPrompts[day];
        await _scheduleRecurring(
          id: _morningReminderBaseId + day,
          title: '${prompt.$1}$name',
          body: prompt.$2,
          minutes: morningMinutes,
          weekday: DateTime.monday + day,
        );
      }
    }
    if (eveningEnabled) {
      for (var day = 0; day < _eveningPrompts.length; day++) {
        final prompt = _eveningPrompts[day];
        await _scheduleRecurring(
          id: _eveningReminderBaseId + day,
          title: '${prompt.$1}$name',
          body: prompt.$2,
          minutes: eveningMinutes,
          weekday: DateTime.monday + day,
        );
      }
    }
    if (weeklyEnabled) {
      await _scheduleRecurring(
        id: _weeklyReminderId,
        title: 'Your weekly reset$name',
        body:
            'Review what you learned, organise your saved resources, and choose one goal for the week.',
        minutes: morningMinutes <= 1425 ? morningMinutes + 15 : morningMinutes,
        weekday: DateTime.sunday,
      );
    }
    return true;
  }

  Future<void> _scheduleRecurring({
    required int id,
    required String title,
    required String body,
    required int minutes,
    int? weekday,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (weekday == null) {
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    } else {
      while (when.weekday != weekday || !when.isAfter(now)) {
        when = when.add(const Duration(days: 1));
      }
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminders,
          'Learning Reminders',
          channelDescription: 'Gentle prompts to return to SkillNest',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: 'learning_reminder',
    );
  }

  /// Cancels a notification by id.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Notification cancel failed safely: $e');
    }
  }

  /// Alias for cancelAll.
  Future<void> cancelAllNotifications() => cancelAll();

  /// Returns all currently active notifications displayed in the system tray.
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (isTestMode) return const [];
    try {
      final list = await _plugin.getActiveNotifications();
      return list;
    } catch (e) {
      debugPrint('getActiveNotifications failed safely: $e');
      return const [];
    }
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Notification cancelAll failed safely: $e');
    }
  }
}

