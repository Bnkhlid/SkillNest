import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLauncher {
  static const MethodChannel _nativeChannel = MethodChannel('com.skillnest.app/share');

  static Future<bool> openUrl(String rawUrl) async {
    var target = rawUrl.trim();
    if (target.isEmpty) return false;

    if (!target.startsWith('http://') && !target.startsWith('https://') && !target.startsWith('mailto:')) {
      target = 'https://$target';
    }

    final uri = Uri.tryParse(target);
    if (uri == null) return false;

    // 1. Try standard url_launcher with external application
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {
      // url_launcher channel error or uninitialized platform channel -> fallback
    }

    // 2. Try platformDefault mode
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (launched) return true;
    } catch (_) {
      // fallback
    }

    // 3. Native Android MethodChannel Intent fallback
    try {
      final res = await _nativeChannel.invokeMethod<bool>('openUrl', {'url': target});
      if (res == true) return true;
    } catch (_) {
      // Native fallback failed
    }

    return false;
  }
}
