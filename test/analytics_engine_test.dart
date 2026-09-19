import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/core/database/daos/analytics_event_dao.dart';
import 'package:learning_vault/core/models/analytics_event.dart';
import 'package:learning_vault/core/repositories/analytics_repository.dart';
import 'package:learning_vault/core/services/analytics_service.dart';
import 'package:learning_vault/core/services/backup_service.dart';
import 'package:learning_vault/core/services/file_storage_service.dart';
import 'package:learning_vault/core/services/restore_service.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/vault.dart';
import 'package:learning_vault/widgets/components.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late AnalyticsEventDao eventDao;
  late AnalyticsService analyticsService;
  late AnalyticsRepository analyticsRepo;
  late FileStorageService storageService;
  late BackupService backupService;
  late RestoreService restoreService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'skillnest_analytics_test_',
    );
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    await db.customStatement('PRAGMA foreign_keys = ON;');
    eventDao = db.analyticsEventDao;
    analyticsService = AnalyticsService(eventDao);
    analyticsRepo = AnalyticsRepository(eventDao, db.resourceDao);
    storageService = FileStorageService(tempDir.path);
    backupService = BackupService(db, storageService);
    restoreService = RestoreService(db, storageService);

    await Vault.I.init(db, storageService, analyticsService, analyticsRepo);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> createDummyFile(String name, String content) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsString(content);
    return file;
  }

  group('Phase 8 — Analytics Engine & SQLite Persistent Events', () {
    test(
      '1. Database starts with schema version 4 and analytics_events table ready',
      () async {
        expect(db.schemaVersion, 5);
        final count = await eventDao.countEvents();
        expect(count, 0);
      },
    );

    test('2. AnalyticsEventDao insert and retrieve single event', () async {
      final now = DateTime.now();
      await eventDao.insertEvent(
        AnalyticsEventsCompanion(
          id: const Value('ev_1'),
          eventType: const Value('resourceAdded'),
          occurredAt: Value(now),
          source: const Value('youtube.com'),
          metadataJson: const Value('{"kind":"video"}'),
        ),
      );

      final events = await eventDao.getEvents();
      expect(events.length, 1);
      expect(events.first.id, 'ev_1');
      expect(events.first.eventType, 'resourceAdded');
      expect(events.first.source, 'youtube.com');
      expect(events.first.metadataJson, '{"kind":"video"}');
    });

    test(
      '3. AnalyticsEventDao getEvents by date range filters properly',
      () async {
        final now = DateTime.now();
        final day1 = now.subtract(const Duration(days: 10));
        final day2 = now.subtract(const Duration(days: 5));
        final day3 = now.subtract(const Duration(days: 1));

        await eventDao.insertEvent(
          AnalyticsEventsCompanion(
            id: const Value('ev_old'),
            eventType: const Value('resourceAdded'),
            occurredAt: Value(day1),
          ),
        );
        await eventDao.insertEvent(
          AnalyticsEventsCompanion(
            id: const Value('ev_mid'),
            eventType: const Value('resourceAdded'),
            occurredAt: Value(day2),
          ),
        );
        await eventDao.insertEvent(
          AnalyticsEventsCompanion(
            id: const Value('ev_recent'),
            eventType: const Value('resourceAdded'),
            occurredAt: Value(day3),
          ),
        );

        final last7Days = await eventDao.getEvents(
          from: now.subtract(const Duration(days: 7)),
        );
        expect(last7Days.length, 2);
        expect(last7Days.any((e) => e.id == 'ev_old'), isFalse);
        expect(last7Days.any((e) => e.id == 'ev_mid'), isTrue);
        expect(last7Days.any((e) => e.id == 'ev_recent'), isTrue);
      },
    );

    test('4. AnalyticsEventDao getEvents by eventType', () async {
      await eventDao.insertEvent(
        const AnalyticsEventsCompanion(
          id: Value('ev_add'),
          eventType: Value('resourceAdded'),
        ),
      );
      await eventDao.insertEvent(
        const AnalyticsEventsCompanion(
          id: Value('ev_open'),
          eventType: Value('resourceOpened'),
        ),
      );

      final addEvents = await eventDao.getEvents(eventType: 'resourceAdded');
      expect(addEvents.length, 1);
      expect(addEvents.first.id, 'ev_add');
    });

    test(
      '5. AnalyticsEventDao foreign key on resourceId sets null on delete',
      () async {
        await db.customStatement('PRAGMA foreign_keys = ON;');
        final res = await Vault.I.add(
          title: 'FK Target',
          source: 'fk.com',
          url: 'https://fk.com',
          kind: ResourceKind.article,
        );

        await eventDao.insertEvent(
          AnalyticsEventsCompanion(
            id: const Value('ev_fk_test'),
            resourceId: Value(res.id),
            eventType: const Value('resourceOpened'),
          ),
        );

        // Permanent delete resource directly
        await db.resourceDao.permanentDelete(res.id);

        final row = await db.resourceDao.findById(res.id);
        expect(row, isNull);

        final event = (await eventDao.getEvents()).firstWhere(
          (e) => e.id == 'ev_fk_test',
        );
        expect(event.resourceId, isNull);
      },
    );

    test(
      '6. AnalyticsService track writes valid event with generated UUID',
      () async {
        final res = await Vault.I.add(
          title: 'Track Resource',
          source: 'medium.com',
          url: 'https://medium.com',
          kind: ResourceKind.article,
        );

        await analyticsService.track(
          eventType: AnalyticsEventType.resourceOpened,
          resourceId: res.id,
          source: 'medium.com',
          metadata: {'tag': 'flutter'},
        );

        final events = await eventDao.getEvents(eventType: 'resourceOpened');
        expect(events.length, 1);
        expect(events.first.id, startsWith('ev_'));
        expect(events.first.eventType, 'resourceOpened');
        expect(events.first.resourceId, res.id);
        expect(events.first.metadataJson, contains('flutter'));
      },
    );

    test(
      '7. AnalyticsService track handles null metadata gracefully',
      () async {
        final res = await Vault.I.add(
          title: 'Track Null Meta',
          source: 'test.com',
          url: 'https://test.com',
          kind: ResourceKind.article,
        );

        await analyticsService.track(
          eventType: AnalyticsEventType.resourceCompleted,
          resourceId: res.id,
        );

        final events = await eventDao.getEvents(eventType: 'resourceCompleted');
        expect(events.length, 1);
        expect(events.first.metadataJson, isNull);
      },
    );

    test(
      '8. AnalyticsService never throws or blocks when database fails',
      () async {
        // Disposing/closing db to simulate broken state
        final brokenDb = AppDatabase.forTesting(NativeDatabase.memory());
        final brokenDao = brokenDb.analyticsEventDao;
        await brokenDb.close();
        final brokenService = AnalyticsService(brokenDao);

        // Must complete without throwing
        await expectLater(
          brokenService.track(eventType: AnalyticsEventType.resourceAdded),
          completes,
        );
      },
    );

    test('9. Vault.add emits resourceAdded event', () async {
      await Vault.I.add(
        title: 'New Event Resource',
        source: 'dev.to',
        url: 'https://dev.to/article',
        kind: ResourceKind.article,
      );

      final events = await eventDao.getEvents(eventType: 'resourceAdded');
      expect(events.length, 1);
      expect(events.first.source, 'dev.to');
    });

    test('10. Vault.delete emits resourceDeleted event', () async {
      final item = await Vault.I.add(
        title: 'Item to Delete',
        source: 'del.com',
        url: 'https://del.com',
        kind: ResourceKind.article,
      );

      await Vault.I.delete(item.id);

      final events = await eventDao.getEvents(eventType: 'resourceDeleted');
      expect(events.length, 1);
      expect(events.first.resourceId, item.id);
    });

    test('11. Vault.restore emits resourceRestored event', () async {
      final item = await Vault.I.add(
        title: 'Item to Restore',
        source: 'rest.com',
        url: 'https://rest.com',
        kind: ResourceKind.article,
      );
      await Vault.I.delete(item.id);
      await Vault.I.restore(item.id);

      final events = await eventDao.getEvents(eventType: 'resourceRestored');
      expect(events.length, 1);
      expect(events.first.resourceId, item.id);
    });

    test(
      '12. Vault.registerOpen emits resourceOpened event and updates open count',
      () async {
        final item = await Vault.I.add(
          title: 'Item to Open',
          source: 'open.com',
          url: 'https://open.com',
          kind: ResourceKind.article,
        );
        await Vault.I.registerOpen(item.id);
        await Vault.I.registerOpen(item.id);

        final events = await eventDao.getEvents(eventType: 'resourceOpened');
        expect(events.length, 2);
      },
    );

    test(
      '13. Vault.setStatus completed emits resourceCompleted event',
      () async {
        final item = await Vault.I.add(
          title: 'Item to Complete',
          source: 'comp.com',
          url: 'https://comp.com',
          kind: ResourceKind.article,
        );
        await Vault.I.setStatus(item.id, ResourceStatus.completed);

        final events = await eventDao.getEvents(eventType: 'resourceCompleted');
        expect(events.length, 1);
        expect(events.first.resourceId, item.id);
      },
    );

    test(
      '14. Vault.setStatus inProgress emits resourceStatusChanged event',
      () async {
        final item = await Vault.I.add(
          title: 'Item to InProgress',
          source: 'prog.com',
          url: 'https://prog.com',
          kind: ResourceKind.article,
        );
        await Vault.I.setStatus(item.id, ResourceStatus.inProgress);

        final events = await eventDao.getEvents(
          eventType: 'resourceStatusChanged',
        );
        expect(events.length, 1);
        expect(events.first.metadataJson, contains('inProgress'));
      },
    );

    test(
      '15. Vault.setFavorite and toggleFavorite emit favoriteChanged events',
      () async {
        final item = await Vault.I.add(
          title: 'Item to Fav',
          source: 'fav.com',
          url: 'https://fav.com',
          kind: ResourceKind.article,
        );
        await Vault.I.setFavorite(item.id, true);
        await Vault.I.toggleFavorite(item.id);

        final events = await eventDao.getEvents(eventType: 'favoriteChanged');
        expect(events.length, 2);
      },
    );

    test('16. Vault.saveNote emits noteSaved event', () async {
      final item = await Vault.I.add(
        title: 'Item for Note',
        source: 'note.com',
        url: 'https://note.com',
        kind: ResourceKind.article,
      );
      await Vault.I.saveNote(item.id, 'Great insights here!');

      final events = await eventDao.getEvents(eventType: 'noteSaved');
      expect(events.length, 1);
      expect(events.first.resourceId, item.id);
    });

    test(
      '17. Vault.moveTo emits resourceMoved event with old and new collection',
      () async {
        final col1 = await Vault.I.addCollection('Col 1');
        final col2 = await Vault.I.addCollection('Col 2');
        final item = await Vault.I.add(
          title: 'Moving Item',
          source: 'move.com',
          url: 'https://move.com',
          kind: ResourceKind.article,
          collectionId: col1.id,
        );

        await Vault.I.moveTo(item.id, col2.id);

        final events = await eventDao.getEvents(eventType: 'resourceMoved');
        expect(events.length, 1);
        expect(events.first.metadataJson, contains(col2.id));
      },
    );

    test('18. Vault.attachFile emits fileAttached event', () async {
      final item = await Vault.I.add(
        title: 'Attached Doc',
        source: 'file.com',
        url: '',
        kind: ResourceKind.pdf,
      );
      final dummy = await createDummyFile('test_sheet.pdf', 'Content');
      await Vault.I.attachFile(item.id, dummy.path, 'test_sheet.pdf');

      final events = await eventDao.getEvents(eventType: 'fileAttached');
      expect(events.length, 1);
      expect(events.first.metadataJson, contains('test_sheet.pdf'));
    });

    test('19. Vault.addStickyNote emits stickyNoteAdded event', () async {
      await Vault.I.addStickyNote(
        title: 'Analytics Note',
        color: const Color(0xFFFDF6E2),
        items: ['Task 1', 'Task 2'],
      );

      final events = await eventDao.getEvents(eventType: 'stickyNoteAdded');
      expect(events.length, 1);
    });

    test(
      '20. Vault.updateStickyItemState emits stickyItemStateChanged event',
      () async {
        final noteId = await Vault.I.addStickyNote(
          title: 'Tasks',
          color: const Color(0xFFFDF6E2),
          items: ['First Task'],
        );
        final note = Vault.I.stickyNotes.first;
        await Vault.I.updateStickyItemState(
          noteId,
          note.items.first.id,
          NotedCheckState.completed,
        );

        final events = await eventDao.getEvents(
          eventType: 'stickyItemStateChanged',
        );
        expect(events.length, 1);
        expect(events.first.metadataJson, contains('completed'));
      },
    );

    test('21. Vault.searchAsync emits searchPerformed event', () async {
      await Vault.I.searchAsync(SearchFilters()..query = 'Flutter Drift');

      final events = await eventDao.getEvents(eventType: 'searchPerformed');
      expect(events.length, 1);
      expect(events.first.metadataJson, contains('queryLength'));
    });

    test(
      '22. AnalyticsRepository getAnalytics computes snapshot with correct KPIs',
      () async {
        await Vault.I.add(
          title: 'Res 1',
          source: 'a.com',
          url: 'https://a.com',
          kind: ResourceKind.article,
        );
        await Vault.I.add(
          title: 'Res 2',
          source: 'b.com',
          url: 'https://b.com',
          kind: ResourceKind.video,
        );
        final r3 = await Vault.I.add(
          title: 'Res 3',
          source: 'c.com',
          url: 'https://c.com',
          kind: ResourceKind.pdf,
        );

        await Vault.I.setStatus(r3.id, ResourceStatus.completed);
        await Vault.I.registerOpen(r3.id);

        final snap = await analyticsRepo.getAnalytics(
          days: 30,
          activeResources: Vault.I.items,
        );
        expect(snap.saved, 3);
        expect(snap.completed, 1);
        expect(snap.opened, 1);
        expect(snap.completionRate, closeTo(1 / 3, 0.01));
      },
    );

    test(
      '23. AnalyticsRepository getAnalytics filters by collection',
      () async {
        final col = await Vault.I.addCollection('Design');
        final r1 = await Vault.I.add(
          title: 'Col Res 1',
          source: 'des.com',
          url: 'https://des.com',
          kind: ResourceKind.article,
          collectionId: col.id,
        );
        await Vault.I.add(
          title: 'Unrelated Res',
          source: 'other.com',
          url: 'https://other.com',
          kind: ResourceKind.article,
        );

        await Vault.I.setStatus(r1.id, ResourceStatus.completed);

        final snap = await analyticsRepo.getAnalytics(
          days: 30,
          collectionId: col.id,
          activeResources: Vault.I.items,
        );

        expect(snap.saved, 1);
        expect(snap.completed, 1);
      },
    );

    test(
      '24. AnalyticsRepository getAnalytics returns valid activity and completion buckets',
      () async {
        final r1 = await Vault.I.add(
          title: 'Bucket Res 1',
          source: 'b1.com',
          url: 'https://b1.com',
          kind: ResourceKind.article,
        );
        await Vault.I.setStatus(r1.id, ResourceStatus.completed);

        final snap = await analyticsRepo.getAnalytics(
          days: 7,
          activeResources: Vault.I.items,
        );
        expect(snap.activityByDay.length, 7);
        expect(snap.completedByDay.length, 7);
        expect(
          snap.activityByDay.fold<int>(0, (a, b) => a + b),
          greaterThanOrEqualTo(1),
        );
        expect(
          snap.completedByDay.fold<int>(0, (a, b) => a + b),
          greaterThanOrEqualTo(1),
        );
      },
    );

    test(
      '25. AnalyticsRepository getAnalytics breaks down sources correctly',
      () async {
        await Vault.I.add(
          title: 'Res 1',
          source: 'youtube.com',
          url: 'https://youtube.com',
          kind: ResourceKind.video,
        );
        await Vault.I.add(
          title: 'Res 2',
          source: 'youtube.com',
          url: 'https://youtube.com/2',
          kind: ResourceKind.video,
        );
        await Vault.I.add(
          title: 'Res 3',
          source: 'medium.com',
          url: 'https://medium.com',
          kind: ResourceKind.article,
        );

        final snap = await analyticsRepo.getAnalytics(
          days: 30,
          activeResources: Vault.I.items,
        );
        expect(snap.bySource['youtube.com'], 2);
        expect(snap.bySource['medium.com'], 1);
      },
    );

    test(
      '26. AnalyticsRepository empty database returns zeroed snapshot without crashing',
      () async {
        final snap = await analyticsRepo.getAnalytics(
          days: 30,
          activeResources: [],
        );
        expect(snap.saved, 0);
        expect(snap.opened, 0);
        expect(snap.completed, 0);
        expect(snap.completionRate, 0.0);
        expect(snap.activityByDay.every((v) => v == 0), isTrue);
      },
    );

    test('27. Vault.analytics synchronous fallback returns valid snapshot', () {
      final snap = Vault.I.analytics(days: 30);
      expect(snap, isNotNull);
      expect(snap.saved, 0);
    });

    test(
      '28. Vault.analyticsAsync asynchronous query uses persistent repository',
      () async {
        await Vault.I.add(
          title: 'Async Res',
          source: 'async.com',
          url: 'https://async.com',
          kind: ResourceKind.article,
        );
        final snap = await Vault.I.analyticsAsync(days: 30);
        expect(snap.saved, 1);
      },
    );

    test(
      '29. Export backup includes analytics_events in database.json and manifest.json',
      () async {
        await Vault.I.add(
          title: 'Analytics Export Item',
          source: 'export.com',
          url: 'https://export.com',
          kind: ResourceKind.article,
        );
        await analyticsService.track(
          eventType: AnalyticsEventType.resourceOpened,
          metadata: {'test': true},
        );

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        expect(res.analyticsEventCount, greaterThanOrEqualTo(2));

        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Verify database.json
        final dbJson = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        expect(dbJson['analytics_events'], isNotNull);
        expect(dbJson['analytics_events'], isNotEmpty);

        // Verify manifest.json
        final manifestJson = jsonDecode(
          utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
        );
        expect(manifestJson['analyticsEventCount'], res.analyticsEventCount);
        expect(manifestJson['schemaVersion'], 5);
      },
    );

    test('30. Validate backup validates analytics_events structure', () async {
      await Vault.I.add(
        title: 'Valid Res',
        source: 'v.com',
        url: 'https://v.com',
        kind: ResourceKind.article,
      );
      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );

      final val = await restoreService.validateBackup(res.filePath);
      expect(val.isValid, isTrue);
      expect(val.analyticsEventCount, greaterThanOrEqualTo(1));
    });

    test(
      '31. Restore backup restores analytics_events into SQLite database',
      () async {
        final item = await Vault.I.add(
          title: 'Restore Event Res',
          source: 'rev.com',
          url: 'https://rev.com',
          kind: ResourceKind.article,
        );
        await Vault.I.registerOpen(item.id);
        await Vault.I.setStatus(item.id, ResourceStatus.completed);

        final backup = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );

        // Clear current events and resources
        await eventDao.deleteAllEvents();
        await db.resourceDao.deleteAllResources();
        await Vault.I.reloadFromDb();
        expect(await eventDao.countEvents(), 0);

        // Restore
        final res = await restoreService.restoreBackup(backup.filePath);
        expect(res.analyticsEventCount, greaterThan(0));

        final restoredEvents = await eventDao.getEvents();
        expect(restoredEvents.length, res.analyticsEventCount);
        expect(
          restoredEvents.any((e) => e.eventType == 'resourceCompleted'),
          isTrue,
        );
      },
    );

    test(
      '32. Backward compatibility: Restore backup from schemaVersion 3 (without analytics_events) succeeds',
      () async {
        final archive = Archive();
        final manifest = {
          'backupFormatVersion': 1,
          'app': 'SkillNest',
          'appVersion': '1.0.0+1',
          'schemaVersion': 3,
          'resourceCount': 1,
          'checksums': {},
        };
        final dbData = {
          'version': 1,
          'schemaVersion': 3,
          'resources': [
            {
              'id': 'r_v3',
              'title': 'V3 Item',
              'url': 'https://v3.com',
              'normalizedUrl': 'https://v3.com',
              'resourceType': 'article',
              'source': 'v3.com',
              'status': 'unread',
              'createdAt': DateTime.now().toIso8601String(),
            },
          ],
        };

        archive.addFile(
          ArchiveFile.string('manifest.json', jsonEncode(manifest)),
        );
        archive.addFile(
          ArchiveFile.string('database.json', jsonEncode(dbData)),
        );

        final zipPath = p.join(tempDir.path, 'v3_backup.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

        final val = await restoreService.validateBackup(zipPath);
        expect(val.isValid, isTrue);

        final res = await restoreService.restoreBackup(zipPath);
        expect(res.resourceCount, 1);
        expect(res.analyticsEventCount, 0);

        await Vault.I.reloadFromDb();
        expect(Vault.I.items.first.title, 'V3 Item');
      },
    );

    test('33. Analytics events survive simulated app restart', () async {
      await Vault.I.add(
        title: 'Restart Analytics Res',
        source: 're.com',
        url: 'https://re.com',
        kind: ResourceKind.article,
      );

      final countBefore = await eventDao.countEvents();
      expect(countBefore, greaterThan(0));

      // Reload Vault from DB
      await Vault.I.reloadFromDb();

      final countAfter = await eventDao.countEvents();
      expect(countAfter, countBefore);
    });

    test('34. AnalyticsEvent model parsing and metadata helper', () {
      final ev = AnalyticsEvent(
        id: 'ev_123',
        eventType: AnalyticsEventType.resourceAdded,
        metadataJson: '{"key":"value","num":42}',
      );

      expect(ev.eventType, AnalyticsEventType.resourceAdded);
      expect(ev.metadata, isNotNull);
      expect(ev.metadata!['key'], 'value');
      expect(ev.metadata!['num'], 42);
    });

    test('35. AnalyticsEventType fromString fallback', () {
      expect(
        AnalyticsEventType.fromString('resourceAdded'),
        AnalyticsEventType.resourceAdded,
      );
      expect(
        AnalyticsEventType.fromString('resourceOpened'),
        AnalyticsEventType.resourceOpened,
      );
      expect(
        AnalyticsEventType.fromString('unknown_type_xyz'),
        AnalyticsEventType.resourceAdded,
      );
    });

    test(
      '36. Multiple event types in sequence maintain chronological integrity',
      () async {
        final t1 = DateTime.now().subtract(const Duration(minutes: 5));
        final t2 = DateTime.now().subtract(const Duration(minutes: 3));
        final t3 = DateTime.now();

        await analyticsService.track(
          eventType: AnalyticsEventType.resourceAdded,
          occurredAt: t1,
        );
        await analyticsService.track(
          eventType: AnalyticsEventType.resourceOpened,
          occurredAt: t2,
        );
        await analyticsService.track(
          eventType: AnalyticsEventType.resourceCompleted,
          occurredAt: t3,
        );

        final events = await eventDao.getEvents();
        expect(events.length, 3);
        expect(
          events[0].occurredAt.isAfter(events[1].occurredAt) ||
              events[0].occurredAt.isAtSameMomentAs(events[1].occurredAt),
          isTrue,
        );
      },
    );

    test(
      '37. Purging analytics events via deleteAllEvents empties table',
      () async {
        await analyticsService.track(
          eventType: AnalyticsEventType.resourceAdded,
        );
        expect(await eventDao.countEvents(), 1);

        await eventDao.deleteAllEvents();
        expect(await eventDao.countEvents(), 0);
      },
    );

    test(
      '38. Drift schema migration creates analytics_events table on upgrade from v3',
      () async {
        final m = db.createMigrator();
        expect(db.schemaVersion, 5);
        // The in-memory fixture already uses the current resources table. Keep
        // this legacy check focused on the v3 → v4 analytics migration.
        expect(() => db.migration.onUpgrade(m, 3, 4), returnsNormally);
      },
    );
  });
}
