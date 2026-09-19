import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/app_theme.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/screens/settings.dart';
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

  test('theme builds for light and dark', () {
    expect(buildTheme(Brightness.light).colorScheme.primary, isNot(Colors.transparent));
    expect(buildTheme(Brightness.dark).brightness, Brightness.dark);
  });

  testWidgets('settings screen opens without exceptions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Mohamed Khaled </>'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Open source licenses'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('vault search filters and sort', () async {
    final v = Vault.I;
    await v.add(
      title: 'Attention Is All You Need',
      source: 'arxiv.org',
      url: 'https://arxiv.org/abs/1706.03762',
      kind: ResourceKind.pdf,
      tags: {'transformers'},
    );
    expect(v.items, isNotEmpty);
    final f = SearchFilters()..query = 'transformers';
    expect(v.search(f), isNotEmpty);
  });

  test('trash restore roundtrip', () async {
    final v = Vault.I;
    final item = await v.add(
      title: 'Sample Note',
      source: '',
      url: '',
      kind: ResourceKind.note,
    );
    final id = item.id;
    await v.delete(id);
    expect(v.find(id), isNull);
    expect(v.trash.any((t) => t.item.id == id), isTrue);
    await v.restore(id);
    expect(v.find(id), isNotNull);
  });
}
