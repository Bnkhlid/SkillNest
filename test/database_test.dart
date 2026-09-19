import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/features/collections/data/collection_repository.dart';
import 'package:learning_vault/features/resources/data/resource_repository.dart';
import 'package:learning_vault/models.dart';

void main() {
  late AppDatabase db;
  late ResourceRepository resourceRepo;
  late CollectionRepository collectionRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    resourceRepo = ResourceRepository(db.resourceDao, db.tagDao);
    collectionRepo = CollectionRepository(db.collectionDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift SQLite Database & Repositories', () {
    test('fresh database starts empty', () async {
      final resources = await resourceRepo.watchAll().first;
      final collections = await collectionRepo.getCollections();
      final trash = await resourceRepo.watchTrash().first;

      expect(resources, isEmpty);
      expect(collections, isEmpty);
      expect(trash, isEmpty);
    });

    test('creates and retrieves collections', () async {
      final colId = await collectionRepo.createCollection(
        name: 'Product Design',
        emoji: '🎨',
        accent: 1,
      );

      final collections = await collectionRepo.getCollections();
      expect(collections.length, 1);
      expect(collections.first.id, colId);
      expect(collections.first.name, 'Product Design');
      expect(collections.first.emoji, '🎨');
    });

    test('creates, updates, and retrieves resources with tags', () async {
      final colId = await collectionRepo.createCollection(
        name: 'AI Engineering',
        emoji: '🤖',
      );

      final resId = await resourceRepo.addResource(
        url: 'https://arxiv.org/abs/1706.03762?utm_source=social',
        title: 'Attention Is All You Need',
        collectionId: colId,
        tags: {'transformers', 'ai', 'research'},
        minutes: 25,
      );

      final item = await resourceRepo.findById(resId);
      expect(item, isNotNull);
      expect(item!.title, 'Attention Is All You Need');
      expect(item.collectionId, colId);
      expect(item.tags, containsAll({'transformers', 'ai', 'research'}));
      expect(item.status, ResourceStatus.unread);
      expect(item.minutes, 25);
    });

    test('soft delete moves resource to trash and restore recovers it', () async {
      final resId = await resourceRepo.addResource(
        url: 'https://example.com/article',
        title: 'Sample Article',
      );

      expect((await resourceRepo.watchAll().first).length, 1);
      expect((await resourceRepo.watchTrash().first).length, 0);

      // Soft delete
      await resourceRepo.softDelete(resId);

      expect((await resourceRepo.watchAll().first).length, 0);
      final trashList = await resourceRepo.watchTrash().first;
      expect(trashList.length, 1);
      expect(trashList.first.item.id, resId);

      // Restore
      await resourceRepo.restore(resId);

      expect((await resourceRepo.watchAll().first).length, 1);
      expect((await resourceRepo.watchTrash().first).length, 0);
    });

    test('permanent delete and empty trash', () async {
      final resId = await resourceRepo.addResource(
        url: 'https://example.com/trash-me',
        title: 'Trash Me',
      );

      await resourceRepo.softDelete(resId);
      expect((await resourceRepo.watchTrash().first).length, 1);

      await resourceRepo.emptyTrash();
      expect((await resourceRepo.watchTrash().first).length, 0);
      expect(await resourceRepo.findById(resId), isNull);
    });

    test('toggle favorite, status changes, notes and register open', () async {
      final resId = await resourceRepo.addResource(
        url: 'https://example.com/deep-dive',
        title: 'Deep Dive',
      );

      // Favorite
      await resourceRepo.toggleFavorite(resId, true);
      var item = await resourceRepo.findById(resId);
      expect(item!.favorite, isTrue);

      // Status
      await resourceRepo.setStatus(resId, ResourceStatus.completed);
      item = await resourceRepo.findById(resId);
      expect(item!.status, ResourceStatus.completed);

      // Notes
      await resourceRepo.updateNotes(resId, 'Key takeaways: 1. Keep it simple.');
      item = await resourceRepo.findById(resId);
      expect(item!.note, 'Key takeaways: 1. Keep it simple.');

      // Register open
      await resourceRepo.registerOpen(resId);
      item = await resourceRepo.findById(resId);
      expect(item!.openCount, 1);
      expect(item.lastOpenedAt, isNotNull);
    });

    test('sticky notes create, add item, toggle item, and delete note', () async {
      // 1. Create sticky note
      await db.stickyNoteDao.insertNote(
        const StickyNotesCompanion(
          id: Value('note_123'),
          title: Value('Project Tasks'),
          colorValue: Value(0xFFFDF6E2),
        ),
      );

      var notes = await db.stickyNoteDao.getAllNotesWithItems();
      expect(notes.length, 1);
      expect(notes.first.note.id, 'note_123');
      expect(notes.first.note.title, 'Project Tasks');
      expect(notes.first.items, isEmpty);

      // 2. Add items
      await db.stickyNoteDao.insertItem(
        const StickyItemsCompanion(
          id: Value('item_1'),
          noteId: Value('note_123'),
          textContent: Value('Finish documentation'),
          state: Value('todo'),
          position: Value(0),
        ),
      );

      notes = await db.stickyNoteDao.getAllNotesWithItems();
      expect(notes.first.items.length, 1);
      expect(notes.first.items.first.id, 'item_1');
      expect(notes.first.items.first.textContent, 'Finish documentation');
      expect(notes.first.items.first.state, 'todo');

      // 3. Toggle item state
      await db.stickyNoteDao.updateItemState('item_1', 'done');
      notes = await db.stickyNoteDao.getAllNotesWithItems();
      expect(notes.first.items.first.state, 'done');

      // 4. Delete item
      await db.stickyNoteDao.deleteItem('item_1');
      notes = await db.stickyNoteDao.getAllNotesWithItems();
      expect(notes.first.items, isEmpty);

      // 5. Delete sticky note
      await db.stickyNoteDao.deleteNote('note_123');
      notes = await db.stickyNoteDao.getAllNotesWithItems();
      expect(notes, isEmpty);
    });
  });
}
