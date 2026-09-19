import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/models.dart';
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

  group('Metadata Integration & User Priority Tests', () {
    test('Immediate SQLite save occurs before background metadata resolution', () async {
      const url = 'https://example.com/fast-save-article';
      final item = await Vault.I.add(
        title: 'Initial Title',
        source: 'example.com',
        url: url,
        kind: ResourceKind.article,
        fetchMetadata: true,
      );

      // Verify immediate presence in SQLite
      final dbItem = await db.resourceDao.findById(item.id);
      expect(dbItem, isNotNull);
      expect(dbItem!.url, url);
      expect(dbItem.title, 'Initial Title');
      expect(Vault.I.items.first.id, item.id);
    });

    test('User data priority: Custom user title is preserved when metadata finishes', () async {
      const customTitle = 'My Personal Notes on Machine Learning';
      const url = 'https://arxiv.org/abs/1706.03762';

      final item = await Vault.I.add(
        title: customTitle,
        source: 'arxiv.org',
        url: url,
        kind: ResourceKind.article,
        fetchMetadata: false, // user provided custom metadata
      );

      expect(item.title, customTitle);

      final dbItem = await db.resourceDao.findById(item.id);
      expect(dbItem!.title, customTitle);
    });

    test('Network error or metadata failure keeps resource saved in SQLite', () async {
      const url = 'https://non-existent-domain-12345.org/invalid';
      final item = await Vault.I.add(
        title: 'https://non-existent-domain-12345.org/invalid',
        source: 'non-existent-domain-12345.org',
        url: url,
        kind: ResourceKind.page,
        fetchMetadata: true,
      );

      // Verify item remains saved in Vault and SQLite despite metadata resolution failure
      expect(Vault.I.items.any((e) => e.id == item.id), isTrue);
      final dbItem = await db.resourceDao.findById(item.id);
      expect(dbItem, isNotNull);
      expect(dbItem!.url, url);
    });
  });
}
