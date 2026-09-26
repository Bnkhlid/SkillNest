import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart' show RoutePaths;
import '../../models.dart' show ResourceItem;
import '../../screens/add_resource.dart' show AddArgs, AddSource;
import '../../widgets/components.dart' show LvSnackbar;
import '../utils/share_parser.dart';

class ShareService with WidgetsBindingObserver {
  ShareService._();
  static final ShareService instance = ShareService._();

  static const _channel = MethodChannel('com.skillnest.app/share');

  final _shareStreamController = StreamController<String>.broadcast();
  Stream<String> get onShareReceived => _shareStreamController.stream;

  bool _initialized = false;
  String? _pendingUrl;
  bool _handlingNativeShare = false;
  bool _isAppReady = false;

  bool get hasPendingShare => _pendingUrl != null && _pendingUrl!.isNotEmpty;
  String? get pendingUrl => _pendingUrl;

  /// Outgoing text sharing to system share sheet
  static Future<bool> shareText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      final res = await _channel.invokeMethod<bool>('shareText', {'text': trimmed});
      if (res == true) return true;
    } catch (_) {}
    return false;
  }

  /// Outgoing resource sharing helper
  static Future<void> shareResource(BuildContext context, ResourceItem item) async {
    final buffer = StringBuffer();
    if (item.title.isNotEmpty) buffer.writeln(item.title);
    if (item.url.isNotEmpty) {
      buffer.writeln(item.url);
    } else if (item.note.isNotEmpty) {
      buffer.writeln(item.note);
    }
    final content = buffer.toString().trim();
    if (content.isEmpty) return;

    final shared = await shareText(content);
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        LvSnackbar.show(
          context,
          'Copied to clipboard',
          icon: Icons.copy_rounded,
        );
      }
    }
  }

  /// Marks that RootShell has mounted and it is safe to dispatch navigation.
  void markAppReady() {
    _isAppReady = true;
    if (_pendingUrl != null && _pendingUrl!.isNotEmpty) {
      _dispatchPendingNavigation();
    }
  }

  /// Global navigator key to dispatch navigation when share arrives
  GlobalKey<NavigatorState>? navigatorKey;

  void init({GlobalKey<NavigatorState>? navKey}) {
    if (navKey != null) navigatorKey = navKey;
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTextReceived') {
        if (_handlingNativeShare) return;
        _handlingNativeShare = true;
        final rawText = call.arguments as String?;
        final url = ShareParser.extractUrl(rawText) ??
            (rawText?.trim().isNotEmpty == true ? rawText!.trim() : null);
        if (url != null && url.isNotEmpty) {
          _pendingUrl = url;
          _shareStreamController.add(url);
          _dispatchPendingNavigation();
        }
        try {
          await _channel.invokeMethod<void>('clearSharedText');
        } catch (_) {}
        _handlingNativeShare = false;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A resumed activity is not a fresh launch. Re-reading Android's initial
    // intent here can replay stale share data and disturb the current route.
    // New shares are delivered through the method-channel handler above.
  }

  Future<String?> checkInitialShare() async {
    if (_pendingUrl != null && _pendingUrl!.isNotEmpty) {
      return _pendingUrl;
    }
    try {
      final rawText = await _channel.invokeMethod<String>(
        'getInitialSharedText',
      );
      if (rawText != null && rawText.isNotEmpty) {
        final url = ShareParser.extractUrl(rawText) ??
            (rawText.trim().isNotEmpty ? rawText.trim() : null);
        if (url != null && url.isNotEmpty) {
          _pendingUrl = url;
          return url;
        }
      }
    } catch (_) {
      // Gracefully ignore channel errors on unsupported platforms or during tests
    }
    return null;
  }

  void _dispatchPendingNavigation() {
    if (!_isAppReady) {
      // Hold dispatching until the primary app (RootShell) has mounted,
      // avoiding race conditions with SplashScreen route replacement.
      return;
    }
    final nav = navigatorKey?.currentState;
    if (nav != null && _pendingUrl != null && _pendingUrl!.isNotEmpty) {
      final url = _pendingUrl!;
      _pendingUrl = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.pushNamed(
          RoutePaths.add,
          arguments: AddArgs(initialUrl: url, source: AddSource.share),
        );
      });
    } else if (_pendingUrl != null) {
      // A share can arrive while Flutter is still creating its navigator.
      // Retry on the next frame instead of losing the capture request.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _dispatchPendingNavigation(),
      );
    }
  }

  void consumePendingShare(void Function(String url) onConsume) {
    if (_pendingUrl != null && _pendingUrl!.isNotEmpty) {
      final url = _pendingUrl!;
      _pendingUrl = null;
      onConsume(url);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareStreamController.close();
  }
}
