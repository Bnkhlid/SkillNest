import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/app_theme.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/core/utils/share_parser.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/screens/add_resource.dart';
import 'package:learning_vault/screens/details.dart';
import 'package:learning_vault/screens/root_shell.dart';
import 'package:learning_vault/screens/settings.dart';
import 'package:learning_vault/vault.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await Vault.I.init(db);
    // Mark notification onboarding handled so no SnackBar timer remains pending in tests
    await Vault.I.dismissNotificationOnboarding();
  });

  tearDown(() async {
    await db.close();
  });

  // Devices tested representing small, standard, Pro Max, and iPad screens:
  const iphoneSE = Size(375, 667); // Small screen (4.7")
  const iphone13 = Size(390, 844); // Standard screen (6.1" with notch)
  const iphone16ProMax = Size(440, 956); // Large screen (6.9" with Dynamic Island)
  const ipadPro = Size(1024, 1366); // Tablet screen (12.9")

  Widget buildTestApp(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      home: child,
    );
  }

  group('iOS Screen Responsiveness & Layout Verification', () {
    for (final (name, size, padding) in [
      ('iPhone SE (375x667)', iphoneSE, const EdgeInsets.only(top: 20, bottom: 0)),
      ('iPhone 13 / 14 / 15 (390x844)', iphone13, const EdgeInsets.only(top: 47, bottom: 34)),
      ('iPhone 16 Pro Max (440x956)', iphone16ProMax, const EdgeInsets.only(top: 59, bottom: 34)),
      ('iPad Pro 12.9" (1024x1366)', ipadPro, const EdgeInsets.only(top: 24, bottom: 20)),
    ]) {
      testWidgets('RootShell & Navigation renders cleanly on $name without overflows', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
            child: buildTestApp(const RootShell()),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.byType(RootShell), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'No layout or overflow exceptions on $name');
      });

      testWidgets('AddResourceScreen from Share Sheet renders cleanly on $name with prefilled post', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const sharedPost = 'Check out this awesome tutorial: https://flutter.dev/docs/get-started';
        final parsedUrl = ShareParser.extractUrl(sharedPost);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
            child: buildTestApp(
              AddResourceScreen(
                args: AddArgs(initialUrl: parsedUrl, source: AddSource.share),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Resource'), findsOneWidget);
        expect(find.byType(TextField), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'AddResourceScreen must have no overflow on $name');
      });

      testWidgets('DetailsScreen & SettingsScreen render cleanly on $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final item = await Vault.I.add(
          title: 'iOS Architecture Guide',
          url: 'https://developer.apple.com/swift',
          source: 'developer.apple.com',
          kind: ResourceKind.article,
        );

        // Details
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
            child: buildTestApp(DetailsScreen(itemId: item.id)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('iOS Architecture Guide'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Settings
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
            child: buildTestApp(const SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Social Media & App Share Parsing for iOS', () {
    final testCases = [
      ('Safari / Chrome URL', 'https://medium.com/@dev/clean-code', 'https://medium.com/@dev/clean-code'),
      ('Twitter / X Post', 'Huge announcement! Read details here https://x.com/flutterdev/status/123456789 (must read)', 'https://x.com/flutterdev/status/123456789'),
      ('LinkedIn Post', 'Excited to share our new release: https://linkedin.com/posts/tech-update_2026?trk=share', 'https://linkedin.com/posts/tech-update_2026?trk=share'),
      ('YouTube Video Link', 'Watch this video:\nhttps://youtu.be/dQw4w9WgXcQ', 'https://youtu.be/dQw4w9WgXcQ'),
      ('Instagram Post / Reel', 'Check out this post https://www.instagram.com/p/C123456789/', 'https://www.instagram.com/p/C123456789/'),
      ('Facebook Share', 'Great article: https://facebook.com/share/p/123456/', 'https://facebook.com/share/p/123456/'),
      ('Reddit Post', 'Discussion on https://reddit.com/r/FlutterDev/comments/123456/update/', 'https://reddit.com/r/FlutterDev/comments/123456/update/'),
      ('Text with URL and parenthesis', 'Here is the link (https://github.com/flutter/flutter)!', 'https://github.com/flutter/flutter'),
    ];

    for (final (sourceApp, rawSharedText, expectedUrl) in testCases) {
      test('Share from $sourceApp accurately extracts URL and saves into Vault', () async {
        final extracted = ShareParser.extractUrl(rawSharedText);
        expect(extracted, expectedUrl);

        final item = await Vault.I.add(
          title: 'Shared from $sourceApp',
          url: extracted!,
          source: Uri.parse(extracted).host,
          kind: ResourceKind.article,
        );

        expect(item.url, expectedUrl);
        expect(Vault.I.items.any((r) => r.url == expectedUrl), isTrue);
      });
    }
  });
}
