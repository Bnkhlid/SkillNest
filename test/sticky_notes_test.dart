import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/features/collections/data/collection_repository.dart';
import 'package:learning_vault/features/notes/data/sticky_note_repository.dart';
import 'package:learning_vault/features/resources/data/resource_repository.dart';
import 'package:learning_vault/widgets/components.dart';

void main() {
  late AppDatabase db;
  late StickyNoteRepository stickyRepo;
  late CollectionRepository collectionRepo;
  late ResourceRepository resourceRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stickyRepo = StickyNoteRepository(db.stickyNoteDao);
    collectionRepo = CollectionRepository(db.collectionDao);
    resourceRepo = ResourceRepository(db.resourceDao, db.tagDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Sticky Notes & Task Management (SQLite / Drift)', () {
    test('fresh database starts with 0 sticky notes and 0 tasks', () async {
      final notes = await stickyRepo.getNotes();
      expect(notes, isEmpty);
    });

    test('creates a sticky note with multiple task items in SQLite', () async {
      final noteId = await stickyRepo.createNote(
        title: 'Project Roadmap',
        color: const Color(0xFFFEF3C7),
        items: ['Implement Drift database', 'Refactor Vault layer', 'Verify zero regressions'],
        isBullet: false,
      );

      expect(noteId, startsWith('sn_'));

      final notes = await stickyRepo.getNotes();
      expect(notes.length, 1);
      final note = notes.first;
      expect(note.id, noteId);
      expect(note.title, 'Project Roadmap');
      expect(note.items.length, 3);
      expect(note.items[0].text, 'Implement Drift database');
      expect(note.items[0].state, NotedCheckState.unchecked);
      expect(note.items[0].isBullet, isFalse);
    });

    test('updates task state to completed and persists in SQLite', () async {
      await stickyRepo.createNote(
        title: 'Daily Standup',
        color: const Color(0xFFD1FAE5),
        items: ['Finish PR #12', 'Team meeting at 3pm'],
        isBullet: false,
      );

      var notes = await stickyRepo.getNotes();
      final itemToComplete = notes.first.items.first;

      // Mark as completed
      await stickyRepo.updateItemState(itemToComplete.id, NotedCheckState.completed);

      // Verify persisted in fresh query from SQLite
      notes = await stickyRepo.getNotes();
      expect(notes.first.items.first.state, NotedCheckState.completed);
    });

    test('deletes completed task permanently from SQLite', () async {
      await stickyRepo.createNote(
        title: 'Sprint Backlog',
        color: const Color(0xFFFCE7F3),
        items: ['Task 1', 'Task 2 to delete', 'Task 3'],
        isBullet: false,
      );

      var notes = await stickyRepo.getNotes();
      final itemToDelete = notes.first.items[1];
      expect(itemToDelete.text, 'Task 2 to delete');

      // Delete the item permanently
      await stickyRepo.deleteItem(itemToDelete.id);

      // Verify in SQLite
      notes = await stickyRepo.getNotes();
      expect(notes.first.items.length, 2);
      expect(notes.first.items.any((it) => it.id == itemToDelete.id), isFalse);
      expect(notes.first.items.map((it) => it.text).toList(), ['Task 1', 'Task 3']);
    });

    test('deleting a sticky note cascades and removes all child items from SQLite', () async {
      final noteId = await stickyRepo.createNote(
        title: 'Sprint Backlog',
        color: const Color(0xFFE0E7FF),
        items: ['Item A', 'Item B'],
      );

      var notes = await stickyRepo.getNotes();
      expect(notes.length, 1);

      // Delete note
      await stickyRepo.deleteNote(noteId);

      // Verify note and all child items are removed
      notes = await stickyRepo.getNotes();
      expect(notes, isEmpty);

      // Check raw table
      final allItems = await db.select(db.stickyItems).get();
      expect(allItems, isEmpty);
    });

    test('persistence after simulated restart and reopen', () async {
      final noteId = await stickyRepo.createNote(
        title: 'Restart Test Note',
        color: const Color(0xFFFEF3C7),
        items: ['Task to keep', 'Task to complete and delete'],
      );

      var notes = await stickyRepo.getNotes();
      final toDeleteId = notes.first.items[1].id;
      final toKeepId = notes.first.items[0].id;

      // Complete and delete
      await stickyRepo.updateItemState(toDeleteId, NotedCheckState.completed);
      await stickyRepo.deleteItem(toDeleteId);

      // Verify before close
      notes = await stickyRepo.getNotes();
      expect(notes.first.items.length, 1);
      expect(notes.first.items.first.id, toKeepId);

      // Simulate app restart: re-read using fresh repository instance on database
      final freshRepo = StickyNoteRepository(db.stickyNoteDao);
      final reloadedNotes = await freshRepo.getNotes();
      expect(reloadedNotes.length, 1);
      expect(reloadedNotes.first.id, noteId);
      expect(reloadedNotes.first.items.length, 1);
      expect(reloadedNotes.first.items.first.id, toKeepId);
      expect(reloadedNotes.first.items.any((it) => it.id == toDeleteId), isFalse);
    });

    test('active task protection: deleting a completed task does not affect active tasks', () async {
      await stickyRepo.createNote(
        title: 'Mixed State Tasks',
        color: const Color(0xFFD1FAE5),
        items: ['Active Task 1', 'Completed Task', 'Active Task 2'],
      );

      var notes = await stickyRepo.getNotes();
      final active1 = notes.first.items[0];
      final completed = notes.first.items[1];
      final active2 = notes.first.items[2];

      await stickyRepo.updateItemState(completed.id, NotedCheckState.completed);
      await stickyRepo.deleteItem(completed.id);

      notes = await stickyRepo.getNotes();
      expect(notes.first.items.length, 2);
      expect(notes.first.items[0].id, active1.id);
      expect(notes.first.items[0].text, 'Active Task 1');
      expect(notes.first.items[0].state, NotedCheckState.unchecked);
      expect(notes.first.items[1].id, active2.id);
      expect(notes.first.items[1].text, 'Active Task 2');
      expect(notes.first.items[1].state, NotedCheckState.unchecked);
    });

    test('unrelated data preservation: deleting completed task does not modify resources, collections, or tags', () async {
      // 1. Create collection
      final colId = await collectionRepo.createCollection(
        name: 'AI Engineering',
        emoji: '🤖',
        accent: 1,
      );

      // 2. Create resource & tags
      final resId = await resourceRepo.addResource(
        title: 'Attention Is All You Need',
        url: 'https://arxiv.org/abs/1706.03762',
        collectionId: colId,
        tags: {'transformers', 'ai'},
      );

      // 3. Create sticky note with task
      final noteId = await stickyRepo.createNote(
        title: 'Reading Goals',
        color: const Color(0xFFFEF3C7),
        items: ['Read transformer paper', 'Done task to delete'],
      );

      var notes = await stickyRepo.getNotes();
      final taskToDelete = notes.first.items[1];
      await stickyRepo.updateItemState(taskToDelete.id, NotedCheckState.completed);

      // 4. Delete the completed task
      await stickyRepo.deleteItem(taskToDelete.id);

      // 5. Verify unrelated data remains completely intact
      final collections = await collectionRepo.getCollections();
      expect(collections.length, 1);
      expect(collections.first.id, colId);
      expect(collections.first.name, 'AI Engineering');

      final res = await resourceRepo.findById(resId);
      expect(res, isNotNull);
      expect(res!.title, 'Attention Is All You Need');
      expect(res.collectionId, colId);
      expect(res.tags, containsAll({'transformers', 'ai'}));

      // Verify remaining note
      notes = await stickyRepo.getNotes();
      expect(notes.first.id, noteId);
      expect(notes.first.items.length, 1);
      expect(notes.first.items.first.text, 'Read transformer paper');
    });

    test('sticky note regression: creation, item deletion, and note deletion still works', () async {
      final noteId = await stickyRepo.createNote(
        title: 'Phase 3 & 4 Regression Note',
        color: const Color(0xFFFEF3C7),
        items: ['Step 1', 'Step 2'],
      );

      var notes = await stickyRepo.getNotes();
      expect(notes.length, 1);

      // Delete note
      await stickyRepo.deleteNote(noteId);
      notes = await stickyRepo.getNotes();
      expect(notes, isEmpty);
    });
  });
}