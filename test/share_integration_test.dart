import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/app_theme.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/screens/add_resource.dart';
import 'package:learning_vault/vault.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await Vault.I.init(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: buildTheme(Brightness.light),
      home: child,
    );
  }

  group('Fast Capture & AddResourceScreen Share Prefill', () {
    testWidgets('prefills URL textfield when AddArgs provides initialUrl', (tester) async {
      const sharedUrl = 'https://flutter.dev/docs/get-started';

      await tester.pumpWidget(
        buildTestableWidget(
          const AddResourceScreen(
            args: AddArgs(initialUrl: sharedUrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the TextField with the prefilled URL
      // (the screen also shows an optional Title field).
      final urlFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == sharedUrl,
      );
      expect(urlFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(urlFieldFinder);
      expect(textField.controller?.text, sharedUrl);
    });

    testWidgets('uses the custom title for link resources when provided', (tester) async {
      const sharedUrl = 'https://flutter.dev/docs/get-started';

      await tester.pumpWidget(
        buildTestableWidget(
          const AddResourceScreen(
            args: AddArgs(initialUrl: sharedUrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Title (optional)'),
        'Flutter Setup Guide',
      );
      await tester.pump();

      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Save Resource');
      await tester.tap(saveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Custom title wins over the URL-derived title.
      expect(Vault.I.items.length, 1);
      expect(Vault.I.items.first.title, 'Flutter Setup Guide');
      expect(Vault.I.items.first.url, sharedUrl);
    });

    testWidgets('allows saving prefilled shared URL and immediately stores in SQLite & Vault', (tester) async {
      const sharedUrl = 'https://news.ycombinator.com/item?id=123456';

      await tester.pumpWidget(
        buildTestableWidget(
          const AddResourceScreen(
            args: AddArgs(initialUrl: sharedUrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A shared URL is saved as a resource, not a note.
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Save Resource');
      expect(saveBtnFinder, findsOneWidget);

      await tester.tap(saveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Verify item saved in Vault and SQLite
      expect(Vault.I.items.length, 1);
      expect(Vault.I.items.first.url, sharedUrl);

      // Verify directly from SQLite
      final dbResources = await db.resourceDao.getActiveResources();
      expect(dbResources.length, 1);
      expect(dbResources.first.url, sharedUrl);
    });

    testWidgets('duplicate detection dialog appears when saving existing URL', (tester) async {
      const existingUrl = 'https://dart.dev/guides';
      await Vault.I.add(
        title: 'Dart Guides',
        source: 'dart.dev',
        url: existingUrl,
        kind: ResourceKind.page,
      );

      expect(Vault.I.items.length, 1);

      // Open AddResourceScreen with tracking parameter version of same URL
      const trackingVariant = 'https://dart.dev/guides?utm_source=twitter';

      await tester.pumpWidget(
        buildTestableWidget(
          const AddResourceScreen(
            args: AddArgs(initialUrl: trackingVariant),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Save Resource');
      await tester.tap(saveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Duplicate dialog should appear
      expect(find.text('Already in your library'), findsOneWidget);
      expect(find.text('Save Anyway'), findsOneWidget);
    });
  });
}
