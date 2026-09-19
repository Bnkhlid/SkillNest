import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/vault.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skillnest_test_');
    dbFile = File('${tempDir.path}/test_vault.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('data survives simulated app restart and process kill', () async {
    // 1. Initial Launch: open DB, initialize Vault, add data
    final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
    final vault1 = Vault.I;
    await vault1.init(db1);

    expect(vault1.items, isEmpty);
    expect(vault1.collections, isEmpty);

    // Add Collection
    final col = await vault1.addCollection('Machine Learning', emoji: '🤖');

    // Add Resource with Tags
    final item1 = await vault1.add(
      title: 'Attention Is All You Need',
      source: 'arxiv.org',
      url: 'https://arxiv.org/abs/1706.03762',
      kind: ResourceKind.pdf,
      collectionId: col.id,
      tags: {'transformers', 'deep-learning'},
    );

    // Add another item and soft delete it
    final item2 = await vault1.add(
      title: 'Draft Notes',
      source: '',
      url: '',
      kind: ResourceKind.note,
    );
    await vault1.delete(item2.id);

    // Modify item1 status, favorite, and note
    await vault1.setStatus(item1.id, ResourceStatus.inProgress);
    await vault1.toggleFavorite(item1.id);
    await vault1.saveNote(
      item1.id,
      'Crucial transformer architecture paper.',
      title: 'Paper takeaways',
    );

    expect(vault1.items.length, 1);
    expect(vault1.trash.length, 1);
    expect(vault1.collections.length, 1);

    // 2. Simulate App Termination: close DB
    await db1.close();

    // 3. Second Launch (App Restart): open new connection to same DB file
    final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
    final vault2 = Vault.I;
    await vault2.init(db2);

    // Verify all data is restored from SQLite!
    expect(vault2.collections.length, 1);
    expect(vault2.collections.first.id, col.id);
    expect(vault2.collections.first.name, 'Machine Learning');
    expect(vault2.collections.first.emoji, '🤖');

    expect(vault2.items.length, 1);
    final restoredItem = vault2.items.first;
    expect(restoredItem.id, item1.id);
    expect(restoredItem.title, 'Attention Is All You Need');
    expect(restoredItem.url, 'https://arxiv.org/abs/1706.03762');
    expect(restoredItem.collectionId, col.id);
    expect(restoredItem.tags, containsAll({'transformers', 'deep-learning'}));
    expect(restoredItem.status, ResourceStatus.inProgress);
    expect(restoredItem.favorite, isTrue);
    expect(restoredItem.note, 'Crucial transformer architecture paper.');
    expect(restoredItem.noteTitle, 'Paper takeaways');

    expect(vault2.trash.length, 1);
    expect(vault2.trash.first.item.id, item2.id);
    expect(vault2.trash.first.item.title, 'Draft Notes');

    await db2.close();
  });
}
