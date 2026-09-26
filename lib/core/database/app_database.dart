import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/analytics_event_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/file_dao.dart';
import 'daos/resource_dao.dart';
import 'daos/search_dao.dart';
import 'daos/sticky_note_dao.dart';
import 'daos/tag_dao.dart';
import 'tables/analytics_events.dart';
import 'tables/collections.dart';
import 'tables/files.dart';
import 'tables/resource_tags.dart';
import 'tables/resources.dart';
import 'tables/sticky_items.dart';
import 'tables/sticky_notes.dart';
import 'tables/tags.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Collections,
    Resources,
    Tags,
    ResourceTags,
    StickyNotes,
    StickyItems,
    Files,
    AnalyticsEvents,
  ],
  daos: [
    ResourceDao,
    CollectionDao,
    TagDao,
    StickyNoteDao,
    SearchDao,
    FileDao,
    AnalyticsEventDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await searchDao.createFtsTable();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await searchDao.createFtsTable();
        await searchDao.rebuildIndex();
      }
      if (from < 3) {
        await m.createTable(files);
      }
      if (from < 4) {
        await m.createTable(analyticsEvents);
      }
      if (from < 5 && to >= 5) {
        await m.addColumn(resources, resources.noteTitle);
        // Existing indexed records need the new note-title text too.
        await searchDao.rebuildIndex();
      }
      if (from < 6 && to >= 6) {
        await m.addColumn(collections, collections.parentId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'skillnest_vault',
      native: const DriftNativeOptions(shareAcrossIsolates: true),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// Atomically wipes all relational data and inserts the restored dataset.
  Future<void> clearAndRestoreData({
    required List<CollectionEntry> collectionsData,
    required List<ResourceEntry> resourcesData,
    required List<TagEntry> tagsData,
    required List<ResourceTagEntry> resourceTagsData,
    required List<StickyNoteEntry> stickyNotesData,
    required List<StickyItemEntry> stickyItemsData,
    required List<FileEntry> filesData,
    List<AnalyticsEventEntry> analyticsEventsData = const [],
  }) async {
    await transaction(() async {
      // 1. Delete in reverse dependency order
      await delete(analyticsEvents).go();
      await delete(files).go();
      await delete(stickyItems).go();
      await delete(stickyNotes).go();
      await delete(resourceTags).go();
      await delete(resources).go();
      await delete(tags).go();
      await delete(collections).go();

      // 2. Insert restored entries in dependency order
      for (final c in collectionsData) {
        await into(collections).insert(c, mode: InsertMode.insertOrReplace);
      }
      for (final t in tagsData) {
        await into(tags).insert(t, mode: InsertMode.insertOrReplace);
      }
      for (final r in resourcesData) {
        await into(resources).insert(r, mode: InsertMode.insertOrReplace);
      }
      for (final rt in resourceTagsData) {
        await into(resourceTags).insert(rt, mode: InsertMode.insertOrIgnore);
      }
      for (final sn in stickyNotesData) {
        await into(stickyNotes).insert(sn, mode: InsertMode.insertOrReplace);
      }
      for (final si in stickyItemsData) {
        await into(stickyItems).insert(si, mode: InsertMode.insertOrReplace);
      }
      for (final f in filesData) {
        await into(files).insert(f, mode: InsertMode.insertOrReplace);
      }
      for (final ae in analyticsEventsData) {
        await into(
          analyticsEvents,
        ).insert(ae, mode: InsertMode.insertOrReplace);
      }
    });
  }
}
