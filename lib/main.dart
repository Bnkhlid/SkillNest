import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_theme.dart';
import 'core/services/share_service.dart';
import 'core/services/firebase_usage_analytics.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/firebase_remote_config_service.dart';
import 'core/services/firebase_in_app_messaging_service.dart';
import 'screens/add_resource.dart';
import 'screens/analytics.dart';
import 'screens/collections.dart';
import 'screens/details.dart';
import 'screens/inbox.dart';
import 'screens/onboarding.dart';
import 'screens/root_shell.dart';
import 'screens/settings.dart';
import 'screens/splash.dart';
import 'screens/trash.dart';
import 'screens/viewer.dart';
import 'vault.dart';

/// Central route names.
class RoutePaths {
  static const onboarding = '/onboarding';
  static const root = '/root';
  static const add = '/add';
  static const inbox = '/inbox';
  static const details = '/details';
  static const collection = '/collection';
  static const viewer = '/viewer';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const trash = '/trash';
}

/// Lets any screen switch the root tab (e.g. Home search icon → Search tab).
final ValueNotifier<int> appTab = ValueNotifier<int>(0);

/// Global navigator key for safe intent-based share navigation
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseUsageAnalytics.instance.initialize();
  await Vault.I.init();
  await FirebaseMessagingService.instance.initialize();
  unawaited(FirebaseRemoteConfigService.instance.initialize());
  unawaited(FirebaseInAppMessagingService.instance.initialize());
  ShareService.instance.init(navKey: appNavigatorKey);
  runApp(const ProviderScope(child: LearningVaultApp()));
}

class LearningVaultApp extends StatelessWidget {
  const LearningVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Vault.I,
      builder: (context, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'SkillNest',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: Vault.I.themeMode,
        home: const SplashScreen(),
        routes: {
          RoutePaths.onboarding: (_) => const OnboardingScreen(),
          RoutePaths.root: (_) => const RootShell(),
          RoutePaths.inbox: (_) => const InboxScreen(),
          RoutePaths.analytics: (_) => const AnalyticsScreen(),
          RoutePaths.settings: (_) => const SettingsScreen(),
          RoutePaths.trash: (_) => const TrashScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case RoutePaths.add:
              final args = settings.arguments;
              final addArgs = args is AddArgs
                  ? args
                  : (args is String ? AddArgs(initialUrl: args) : null);
              return MaterialPageRoute(
                builder: (_) => AddResourceScreen(args: addArgs),
              );
            case RoutePaths.details:
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => DetailsScreen(itemId: id),
              );
            case RoutePaths.viewer:
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => ViewerScreen(itemId: id),
              );
            case RoutePaths.collection:
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => CollectionDetailScreen(collectionId: id),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}
