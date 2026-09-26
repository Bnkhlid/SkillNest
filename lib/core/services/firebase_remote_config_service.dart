import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

const skillNestVersion = '1.0.0';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.url,
    required this.message,
    required this.forceUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String url;
  final String message;
  final bool forceUpdate;

  bool get hasNewVersion =>
      compareSemanticVersions(currentVersion, latestVersion) < 0;
  bool get required =>
      compareSemanticVersions(currentVersion, minimumVersion) < 0 ||
      forceUpdate && hasNewVersion;
  bool get hasValidUrl => Uri.tryParse(url)?.hasScheme == true;
}

/// Non-blocking Remote Config update information with local safe defaults.
class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService._();
  static final instance = FirebaseRemoteConfigService._();

  FirebaseRemoteConfig? _remoteConfig;
  UpdateInfo _info = _defaults();
  UpdateInfo get info => _info;

  static UpdateInfo _defaults() => const UpdateInfo(
    currentVersion: skillNestVersion,
    latestVersion: skillNestVersion,
    minimumVersion: skillNestVersion,
    url: '',
    message: 'A new version of SkillNest is available.',
    forceUpdate: false,
  );

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: const Duration(hours: 12),
        ),
      );
      await rc.setDefaults({
        'latest_version': skillNestVersion,
        'minimum_supported_version': skillNestVersion,
        'update_url': '',
        'update_url_ios': '',
        'update_url_android': '',
        'update_message': 'A new version of SkillNest is available.',
        'force_update': false,
      });
      _remoteConfig = rc;
      _readValues(); // cached/default values immediately
      unawaited(refresh());
    } catch (e) {
      _debug('Remote Config unavailable: $e');
    }
  }

  Future<UpdateInfo> refresh() async {
    final rc = _remoteConfig;
    if (rc == null) return _info;
    try {
      await rc.fetchAndActivate();
      _readValues();
    } catch (e) {
      _debug('Remote Config refresh failed safely: $e');
    }
    return _info;
  }

  void _readValues() {
    final rc = _remoteConfig!;
    String url = rc.getString('update_url').trim();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosUrl = rc.getString('update_url_ios').trim();
      if (iosUrl.isNotEmpty) url = iosUrl;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidUrl = rc.getString('update_url_android').trim();
      if (androidUrl.isNotEmpty) url = androidUrl;
    }

    _info = UpdateInfo(
      currentVersion: skillNestVersion,
      latestVersion: rc.getString('latest_version').trim().isEmpty
          ? skillNestVersion
          : rc.getString('latest_version').trim(),
      minimumVersion: rc.getString('minimum_supported_version').trim().isEmpty
          ? skillNestVersion
          : rc.getString('minimum_supported_version').trim(),
      url: url,
      message: rc.getString('update_message').trim().isEmpty
          ? 'A new version of SkillNest is available.'
          : rc.getString('update_message').trim(),
      forceUpdate: rc.getBool('force_update'),
    );
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[SkillNest Remote Config] $message');
  }
}

int compareSemanticVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final left = parse(a), right = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < left.length ? left[i] : 0,
        y = i < right.length ? right[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
