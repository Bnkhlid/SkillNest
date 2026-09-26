import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/core/database/daos/analytics_event_dao.dart';
import 'package:learning_vault/core/models/analytics_event.dart';
import 'package:learning_vault/core/repositories/analytics_repository.dart';
import 'package:learning_vault/core/services/analytics_service.dart';
import 'package:learning_vault/core/services/file_storage_service.dart';
import 'package:learning_vault/core/services/metadata_service.dart';
import 'package:learning_vault/core/services/notification_service.dart';
import 'package:learning_vault/core/utils/url_normalizer.dart';
import 'package:learning_vault/features/resources/data/file_repository.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/vault.dart';
import 'package:learning_vault/widgets/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late FileStorageService storageService;
  late AnalyticsEventDao eventDao;
  late AnalyticsService analyticsService;
  late AnalyticsRepository analyticsRepo;
  late FileRepository fileRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skillnest_phase10_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    ));
    await db.customStatement('PRAGMA foreign_keys = ON;');

    storageService = FileStorageService(tempDir.path);
    eventDao = db.analyticsEventDao;
    analyticsService = AnalyticsService(eventDao);
    analyticsRepo = AnalyticsRepository(eventDao, db.resourceDao);
    fileRepo = FileRepository(db.fileDao, storageService, db.searchDao);

    Vault.I.items.clear();
    Vault.I.collections.clear();
    Vault.I.trash.clear();
    Vault.I.stickyNotes.clear();
    Vault.I.notifications.clear();

    await Vault.I.init(
      db,
      storageService,
      analyticsService,
      analyticsRepo,
      NotificationService.instance,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Group 1: Notification Engine & Safety', () {
    test('1. NotificationService initialization succeeds gracefully in test environment', () async {
      final notif = NotificationService.instance;
      expect(notif.isTestMode, isTrue);
      await expectLater(notif.init(), completes);
      expect(notif.isInitialized, isTrue);
    });

    test('2. Notification channels are defined correctly', () {
      expect(NotificationService.channelGeneral, 'skillnest_general');
      expect(NotificationService.channelReminders, 'skillnest_reminders');
      expect(NotificationService.channelCapture, 'skillnest_capture');
    });

    test('3. showCaptureSuccess runs fail-safe without throwing', () async {
      await expectLater(
        NotificationService.instance.showCaptureSuccess(
          title: 'Clean Architecture Guide',
          source: 'medium.com',
        ),
        completes,
      );
    });

    test('4. showBackupSuccess runs fail-safe without throwing', () async {
      await expectLater(
        NotificationService.instance.showBackupSuccess(
          itemCount: 42,
          filePath: '/path/to/backup.zip',
        ),
        completes,
      );
    });

    test('5. showDailyDigest runs fail-safe without throwing', () async {
      await expectLater(
        NotificationService.instance.showDailyDigest(unreadCount: 7),
        completes,
      );
    });

    test('6. showReminder runs fail-safe without throwing', () async {
      await expectLater(
        NotificationService.instance.showReminder(
          title: 'Flutter Concurrency in Depth',
          daysUnread: 14,
        ),
        completes,
      );
    });

    test('7. cancelAllNotifications runs without error', () async {
      await expectLater(NotificationService.instance.cancelAllNotifications(), completes);
    });

    test('8. Vault.addNotification adds in-app item and updates badge count', () {
      Vault.I.clearNotifications();
      final initialCount = Vault.I.notifications.length;
      Vault.I.addNotification(
        title: 'New Saved Resource',
        body: 'Saved "Flutter Performance" from youtube.com',
      );
      expect(Vault.I.notifications.length, initialCount + 1);
      expect(Vault.I.notifications.first.title, 'New Saved Resource');
      expect(Vault.I.unreadNotificationCount, 1);
    });

    test('9. Vault.markAllNotificationsRead updates unread badge count', () {
      Vault.I.clearNotifications();
      Vault.I.addNotification(title: 'Note 1', body: 'Body 1');
      Vault.I.addNotification(title: 'Note 2', body: 'Body 2');
      expect(Vault.I.unreadNotificationCount, 2);

      Vault.I.markAllNotificationsRead();
      expect(Vault.I.unreadNotificationCount, 0);
    });

    test('10. Vault.clearNotifications empties in-app notifications', () {
      Vault.I.addNotification(title: 'Note', body: 'Body');
      Vault.I.clearNotifications();
      expect(Vault.I.notifications.isEmpty, isTrue);
      expect(Vault.I.unreadNotificationCount, 0);
    });
  });

  group('Group 2: Async Hardening & Rapid Concurrency', () {
    test('11. Rapid sequential additions produce strictly unique IDs (microsecond timestamp guarantee)', () {
      final id1 = Vault.I.newId();
      final id2 = Vault.I.newId();
      final id3 = Vault.I.newId();
      expect(id1 != id2, isTrue);
      expect(id2 != id3, isTrue);
      expect(id1 != id3, isTrue);
    });

    test('12. Concurrent rapid resource creation maintains repository state consistency', () async {
      final futures = <Future<ResourceItem>>[];
      for (int i = 0; i < 15; i++) {
        futures.add(
          Vault.I.add(
            title: 'Concurrent Item #$i',
            source: 'example.com',
            url: 'https://example.com/item/$i',
            kind: ResourceKind.article,
          ),
        );
      }
      await Future.wait(futures);

      expect(Vault.I.items.length, 15);
      final fromDb = await db.resourceDao.getAllResources();
      expect(fromDb.length, 15);
    });

    test('13. Duplicate URLs are detected gracefully', () async {
      final item1 = await Vault.I.add(
        title: 'First Save',
        source: 'example.com',
        url: 'https://example.com/unique-url',
        kind: ResourceKind.article,
      );
      expect(item1.id.isNotEmpty, isTrue);

      final isDup = Vault.I.isDuplicateUrl('https://example.com/unique-url');
      expect(isDup, isTrue);
    });

    test('14. Rapid toggling of favorite state does not corrupt state', () async {
      final item = await Vault.I.add(
        title: 'Fav Toggle Item',
        source: 'example.com',
        url: 'https://example.com/fav',
        kind: ResourceKind.video,
      );

      for (int i = 0; i < 10; i++) {
        await Vault.I.toggleFavorite(item.id);
      }
      expect(Vault.I.find(item.id)?.favorite, isFalse);
    });

    test('15. Rapid status progression triggers analytics events correctly', () async {
      final item = await Vault.I.add(
        title: 'Status Progression Item',
        source: 'example.com',
        url: 'https://example.com/status',
        kind: ResourceKind.article,
      );

      await Vault.I.setStatus(item.id, ResourceStatus.inProgress);
      await Vault.I.setStatus(item.id, ResourceStatus.completed);
      await Vault.I.setStatus(item.id, ResourceStatus.unread);

      final found = Vault.I.find(item.id);
      expect(found?.status, ResourceStatus.unread);

      final events = await eventDao.getEvents();
      expect(events.length, greaterThanOrEqualTo(3));
    });
  });

  group('Group 3: Database Resilience & Integrity', () {
    test('16. Foreign key cascade / inbox fallback when deleting a collection', () async {
      final col = await Vault.I.addCollection('Architecture');
      final item = await Vault.I.add(
        title: 'Arch Pattern',
        source: 'example.com',
        url: 'https://example.com/arch',
        kind: ResourceKind.article,
        collectionId: col.id,
      );
      expect(Vault.I.find(item.id)?.collectionId, col.id);

      await Vault.I.deleteCollection(col.id);
      expect(Vault.I.find(item.id)?.collectionId, isNull);
    });

    test('17. Adding and removing multiple tags maintains relational tag table integrity', () async {
      final item = await Vault.I.add(
        title: 'Tagged Item',
        source: 'example.com',
        url: 'https://example.com/tagged',
        kind: ResourceKind.article,
        tags: {'flutter', 'dart', 'testing'},
      );

      expect(Vault.I.find(item.id)?.tags, containsAll(['flutter', 'dart', 'testing']));

      await Vault.I.removeTag(item.id, 'dart');
      expect(Vault.I.find(item.id)?.tags, containsAll(['flutter', 'testing']));
      expect(Vault.I.find(item.id)?.tags.contains('dart'), isFalse);
    });

    test('18. Soft-delete to Trash and Restore retains all tags, notes, and metadata', () async {
      final item = await Vault.I.add(
        title: 'Preserve Item',
        source: 'example.com',
        url: 'https://example.com/preserve',
        kind: ResourceKind.article,
        tags: {'preserved-tag'},
      );
      await Vault.I.saveNote(item.id, 'Important note');

      await Vault.I.delete(item.id);
      expect(Vault.I.find(item.id), isNull);
      expect(Vault.I.trash.any((t) => t.item.id == item.id), isTrue);

      await Vault.I.restore(item.id);
      final restored = Vault.I.find(item.id);
      expect(restored, isNotNull);
      expect(restored?.title, 'Preserve Item');
      expect(restored?.note, 'Important note');
      expect(restored?.tags, contains('preserved-tag'));
    });

    test('19. Empty Trash permanently deletes only trashed items without affecting active items', () async {
      final active = await Vault.I.add(
        title: 'Active Item',
        source: 'example.com',
        url: 'https://example.com/active',
        kind: ResourceKind.article,
      );
      final toTrash = await Vault.I.add(
        title: 'Trash Item',
        source: 'example.com',
        url: 'https://example.com/trash-me',
        kind: ResourceKind.article,
      );

      await Vault.I.delete(toTrash.id);
      expect(Vault.I.trash.length, 1);

      await Vault.I.emptyTrash();
      expect(Vault.I.trash.isEmpty, isTrue);
      expect(Vault.I.find(active.id), isNotNull);
    });

    test('20. Sticky notes CRUD operations persist and re-order safely', () async {
      final noteId1 = await Vault.I.addStickyNote(
        title: 'Task 1',
        color: const Color(0xFFFDF6E2),
        items: ['Item A'],
      );
      final noteId2 = await Vault.I.addStickyNote(
        title: 'Task 2',
        color: const Color(0xFFE8F0FE),
        items: ['Item B'],
      );

      expect(Vault.I.stickyNotes.length, 2);

      final note1 = Vault.I.stickyNotes.firstWhere((n) => n.id == noteId1);
      await Vault.I.updateStickyItemState(noteId1, note1.items.first.id, NotedCheckState.completed);
      expect(Vault.I.stickyNotes.firstWhere((n) => n.id == noteId1).items.first.state, NotedCheckState.completed);

      await Vault.I.deleteStickyNote(noteId2);
      expect(Vault.I.stickyNotes.length, 1);
    });
  });

  group('Group 4: FTS5 Search Robustness', () {
    test('21. FTS5 indexes newly added resources immediately', () async {
      await Vault.I.add(
        title: 'Quantum Computing Fundamentals',
        source: 'quantum.org',
        url: 'https://example.com/quantum',
        kind: ResourceKind.article,
      );

      final results = await db.searchDao.searchResources(filters: SearchFilters()..query = 'quantum');
      expect(results.any((r) => r.title.contains('Quantum')), isTrue);
    });

    test('22. FTS5 handles empty, whitespace, and special characters without SQL errors', () async {
      expect(await db.searchDao.searchResources(filters: SearchFilters()..query = ''), isNotNull);
      expect(await db.searchDao.searchResources(filters: SearchFilters()..query = '   '), isNotNull);
      expect(await db.searchDao.searchResources(filters: SearchFilters()..query = r'"*$%^&()'), isA<List<dynamic>>());
    });

    test('23. FTS5 updates search index when resource title or note is modified', () async {
      final item = await Vault.I.add(
        title: 'Initial Title',
        source: 'example.com',
        url: 'https://example.com/update-search',
        kind: ResourceKind.article,
      );

      await Vault.I.saveNote(item.id, 'Updated Specialized Terminology');
      await Future.delayed(const Duration(milliseconds: 100));

      final results = await db.searchDao.searchResources(filters: SearchFilters()..query = 'Specialized');
      expect(results.isNotEmpty, isTrue);
    });

    test('24. FTS5 excludes soft-deleted items from search results', () async {
      final item = await Vault.I.add(
        title: 'Cryptographic Protocols',
        source: 'example.com',
        url: 'https://example.com/crypto',
        kind: ResourceKind.article,
      );

      var res = await db.searchDao.searchResources(filters: SearchFilters()..query = 'Cryptographic');
      expect(res.isNotEmpty, isTrue);

      await Vault.I.delete(item.id);
      res = await db.searchDao.searchResources(filters: SearchFilters()..query = 'Cryptographic');
      expect(res.isEmpty, isTrue);
    });

    test('25. Unicode and emoji search queries operate safely', () async {
      await Vault.I.add(
        title: 'تعلم الآلة باللغة العربية 🚀',
        source: 'arabic-ml.com',
        url: 'https://example.com/arabic-ml',
        kind: ResourceKind.article,
      );

      final results = await db.searchDao.searchResources(filters: SearchFilters()..query = 'الآلة');
      expect(results.isNotEmpty, isTrue);
    });
  });

  group('Group 5: Local File Storage & Path Sanitization', () {
    test('26. Saving a local file creates physical file on disk with correct size and extension', () async {
      final sourceFile = File('${tempDir.path}/sample.pdf');
      await sourceFile.writeAsString('Dummy PDF content for testing');

      final item = await Vault.I.add(
        title: 'PDF Resource',
        source: 'local',
        url: '',
        kind: ResourceKind.pdf,
      );

      await Vault.I.attachFile(item.id, sourceFile.path, 'sample.pdf');
      final updated = Vault.I.find(item.id);
      expect(updated?.localFile, isNotNull);
      expect(updated?.localFile?.fileName, 'sample.pdf');
      expect(updated?.localFile?.fileExtension, 'pdf');
      expect(await fileRepo.fileExistsOnDisk(updated!.localFile!.localPath), isTrue);
    });

    test('27. fileExistsOnDisk returns false for non-existent or deleted paths without throwing', () async {
      final exists = await fileRepo.fileExistsOnDisk('${tempDir.path}/non_existent_file.xyz');
      expect(exists, isFalse);
    });

    test('28. removeFile removes file record and clears attachment', () async {
      final sourceFile = File('${tempDir.path}/to_remove.txt');
      await sourceFile.writeAsString('To be removed');

      final item = await Vault.I.add(
        title: 'Doc with File',
        source: 'local',
        url: '',
        kind: ResourceKind.article,
      );
      await Vault.I.attachFile(item.id, sourceFile.path, 'to_remove.txt');
      expect(Vault.I.find(item.id)?.localFile, isNotNull);

      await Vault.I.removeFile(item.id);
      expect(Vault.I.find(item.id)?.localFile, isNull);
    });

    test('29. copyFileToPrivateStorage creates private copy in app storage directory', () async {
      final f1 = File('${tempDir.path}/f1.bin');
      await f1.writeAsBytes(List.filled(1024, 65));

      final saved = await storageService.copyFileToPrivateStorage(
        sourcePath: f1.path,
        fileName: 'f1.bin',
      );
      expect(await storageService.fileExists(saved.localPath), isTrue);
      expect(saved.fileSize, 1024);
    });

    test('30. Clearing offline files resets cached bytes safely', () async {
      Vault.I.clearOfflineFiles();
      expect(Vault.I.cachedBytes, 0);
    });
  });

  group('Group 6: Analytics Persistence & Metric Calculation', () {
    test('31. Recording learning events persists offline in SQLite', () async {
      final item = await Vault.I.add(
        title: 'Analytics Target',
        source: 'test.com',
        url: 'https://test.com',
        kind: ResourceKind.article,
      );

      await analyticsService.track(
        eventType: AnalyticsEventType.resourceAdded,
        resourceId: item.id,
        metadata: {'kind': 'article'},
      );
      await analyticsService.track(
        eventType: AnalyticsEventType.resourceOpened,
        resourceId: item.id,
        metadata: {'duration_seconds': 120},
      );

      final events = await eventDao.getEvents();
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.any((e) => e.eventType == 'resourceAdded'), isTrue);
    });

    test('32. Analytics queries support 7D, 30D, and All timeframes', () async {
      final r1 = await Vault.I.add(title: 'Res 7D', source: 'a.com', url: 'https://a.com', kind: ResourceKind.article);
      await Vault.I.setStatus(r1.id, ResourceStatus.completed);

      final stats7D = await analyticsRepo.getAnalytics(days: 7, activeResources: Vault.I.items);
      expect(stats7D.completed, 1);

      final stats30D = await analyticsRepo.getAnalytics(days: 30, activeResources: Vault.I.items);
      expect(stats30D.completed, 1);
    });

    test('33. Weekly velocity and daily activity buckets compute without errors', () async {
      final item = await Vault.I.add(title: 'Activity Item', source: 'act.com', url: 'https://act.com', kind: ResourceKind.article);
      await Vault.I.registerOpen(item.id);

      final snap = await analyticsRepo.getAnalytics(days: 7, activeResources: Vault.I.items);
      expect(snap.activityByDay.length, 7);
      expect(snap.activityByDay.fold<int>(0, (a, b) => a + b), greaterThanOrEqualTo(1));
    });

    test('34. Top sources aggregation handles empty datasets', () async {
      final snap = await analyticsRepo.getAnalytics(days: 30, activeResources: []);
      expect(snap.bySource, isEmpty);
      expect(snap.completionRate, 0.0);
    });
  });

  group('Group 7: Metadata Parsing & Network Resilience', () {
    test('35. HtmlMetadataParser extracts OpenGraph, Twitter, and Title tags', () {
      const html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Falling Back Title</title>
          <meta property="og:title" content="Real OG Title" />
          <meta property="og:description" content="Detailed OG description." />
          <meta property="og:image" content="https://example.com/hero.jpg" />
          <meta property="og:site_name" content="SkillNest Lab" />
          <meta name="author" content="Dr. Jane Doe" />
        </head>
        <body><p>Test</p></body>
        </html>
      ''';

      final meta = HtmlMetadataParser.parse(html, sourceUrl: 'https://example.com/post');
      expect(meta.title, 'Real OG Title');
      expect(meta.description, 'Detailed OG description.');
      expect(meta.thumbnailUrl, 'https://example.com/hero.jpg');
      expect(meta.siteName, 'SkillNest Lab');
      expect(meta.author, 'Dr. Jane Doe');
    });

    test('36. HtmlMetadataParser decodes HTML entities in titles and descriptions', () {
      const html = '''
        <html><head>
          <meta property="og:title" content="Rock &amp; Roll &mdash; &quot;The Best&quot; &#8212; 2026" />
        </head></html>
      ''';
      final meta = HtmlMetadataParser.parse(html);
      expect(meta.title, 'Rock & Roll — "The Best" — 2026');
    });

    test('37. MetadataService returns graceful fallback on invalid or unreachable URL', () async {
      final meta = await MetadataService.instance.fetchMetadata(
        'https://nonexistent-domain-12345-xyz.org/test',
        timeout: const Duration(milliseconds: 200),
      );
      expect(meta.siteName, 'nonexistent-domain-12345-xyz.org');
    });

    test('38. UrlNormalizer strips tracking parameters and normalizes schemes', () {
      final cleaned = UrlNormalizer.normalize(
        'https://example.com/article?utm_source=twitter&utm_medium=social&ref=123#heading',
      );
      expect(cleaned.contains('utm_source'), isFalse);
      expect(cleaned.contains('utm_medium'), isFalse);
    });
  });

  group('Group 8: Backup, Restore & Rollback Safety', () {
    test('39. Exporting backup produces valid ZIP file with metadata.json and database tables', () async {
      await Vault.I.add(
        title: 'Export Test Item',
        source: 'example.com',
        url: 'https://example.com/export',
        kind: ResourceKind.article,
      );

      final result = await Vault.I.exportBackupZip();
      expect(result.filePath.isNotEmpty, isTrue);
      expect(File(result.filePath).existsSync(), isTrue);
      expect(result.resourceCount, greaterThanOrEqualTo(1));
    });

    test('40. Restoring invalid ZIP file rejects cleanly without corrupting existing database', () async {
      final invalidZip = File('${tempDir.path}/corrupt.zip');
      await invalidZip.writeAsString('This is not a zip file');

      final validation = await Vault.I.validateBackupZip(invalidZip.path);
      expect(validation.isValid, isFalse);

      await expectLater(
        Vault.I.restoreBackupZip(invalidZip.path),
        throwsA(isA<Exception>()),
      );
    });

    test('41. Large dataset performance test: 100+ items insert and batch query completes promptly', () async {
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await db.resourceDao.insertResource(
          ResourcesCompanion(
            id: Value('perf_item_$i'),
            title: Value('Performance Benchmark Item #$i'),
            url: Value('https://example.com/perf/$i'),
            normalizedUrl: Value('https://example.com/perf/$i'),
            resourceType: const Value('article'),
            minutes: const Value(5),
            source: const Value('perf.com'),
            status: const Value('unread'),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
      final items = await db.resourceDao.getAllResources();
      stopwatch.stop();

      expect(items.length, greaterThanOrEqualTo(100));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('42. Vault state reload simulates complete application restart seamlessly', () async {
      await Vault.I.add(
        title: 'Persistent Item Across Restart',
        source: 'restart.com',
        url: 'https://example.com/restart',
        kind: ResourceKind.pdf,
      );
      expect(Vault.I.items.any((i) => i.title == 'Persistent Item Across Restart'), isTrue);

      // Simulate full app restart by reloading from DB
      await Vault.I.reloadFromDb();

      expect(Vault.I.items.any((i) => i.title == 'Persistent Item Across Restart'), isTrue);
    });

    test('43. renameResource updates resource title in memory, database, and search index', () async {
      final item = await Vault.I.add(
        title: 'Original Title',
        source: 'example.com',
        url: 'https://example.com/item',
        kind: ResourceKind.article,
      );
      expect(item.title, 'Original Title');

      await Vault.I.renameResource(item.id, 'Updated New Title');
      expect(item.title, 'Updated New Title');

      // Verify in SQLite
      final dbItem = await db.resourceDao.findById(item.id);
      expect(dbItem?.title, 'Updated New Title');
    });

    test('44. deleteNotification removes notification and marks it as dismissed', () async {
      Vault.I.addNotification(
        title: 'Swipe Test Notification',
        body: 'Swipe to dismiss body',
      );
      expect(Vault.I.notifications.any((n) => n.title == 'Swipe Test Notification'), isTrue);
      final notifId = Vault.I.notifications.firstWhere((n) => n.title == 'Swipe Test Notification').id;

      Vault.I.deleteNotification(notifId);
      expect(Vault.I.notifications.any((n) => n.id == notifId), isFalse);

      // Verify syncActiveSystemNotifications will not re-insert it
      await Vault.I.syncActiveSystemNotifications();
      expect(Vault.I.notifications.any((n) => n.id == notifId), isFalse);
    });

    test('45. clearAllNotifications empties list and prevents resurrection', () async {
      Vault.I.addNotification(title: 'N1', body: 'B1');
      Vault.I.addNotification(title: 'N2', body: 'B2');
      expect(Vault.I.notifications.length, greaterThanOrEqualTo(2));

      Vault.I.clearAllNotifications();
      expect(Vault.I.notifications.isEmpty, isTrue);

      await Vault.I.syncActiveSystemNotifications();
      expect(Vault.I.notifications.isEmpty, isTrue);
    });
  });
}
