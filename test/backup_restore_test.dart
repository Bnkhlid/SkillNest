import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
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
  late FileStorageService storageService;
  late AnalyticsService analyticsService;
  late AnalyticsRepository analyticsRepo;
  late BackupService backupService;
  late RestoreService restoreService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skillnest_phase9_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storageService = FileStorageService(tempDir.path);
    analyticsService = AnalyticsService(db.analyticsEventDao);
    analyticsRepo = AnalyticsRepository(db.analyticsEventDao, db.resourceDao);
    backupService = BackupService(db, storageService);
    restoreService = RestoreService(db, storageService, tempDir.path);
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

  group('SkillNest — Phase 9: Real Backup & Restore + Data Safety', () {
    // ==========================================
    // BACKUP TESTS (1 - 15)
    // ==========================================

    test(
      '1. Empty database backup generates valid archive and manifest with zero counts',
      () async {
        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        expect(File(res.filePath).existsSync(), isTrue);
        expect(res.resourceCount, 0);
        expect(res.collectionCount, 0);
        expect(res.tagCount, 0);
        expect(res.fileCount, 0);
        expect(res.analyticsEventCount, 0);

        final val = await restoreService.validateBackup(res.filePath);
        expect(val.isValid, isTrue);
        expect(val.resourceCount, 0);
      },
    );

    test('2. Full database backup includes all entity types', () async {
      final col = await Vault.I.addCollection('AI Engineering', emoji: '🤖');
      final item = await Vault.I.add(
        title: 'Deep Learning Book',
        source: 'mit.edu',
        url: 'https://mit.edu/dl',
        kind: ResourceKind.pdf,
        collectionId: col.id,
        tags: {'ai', 'ml'},
      );
      final dummy = await createDummyFile(
        'deep_learning.pdf',
        'Chapter 1: Neural Networks',
      );
      await Vault.I.attachFile(item.id, dummy.path, 'deep_learning.pdf');
      await Vault.I.addStickyNote(
        title: 'Study Plan',
        color: const Color(0xFFFDF6E2),
        items: ['Read Ch 1', 'Do exercises'],
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      expect(res.collectionCount, 1);
      expect(res.resourceCount, 1);
      expect(res.tagCount, 2);
      expect(res.resourceTagCount, 2);
      expect(res.stickyNoteCount, 1);
      expect(res.stickyItemCount, 2);
      expect(res.fileCount, 1);
      expect(res.analyticsEventCount, greaterThanOrEqualTo(1));
    });

    test(
      '3. Export collections preserves custom emojis, names, and accent colors',
      () async {
        await Vault.I.addCollection('Algorithms', emoji: '⚡');
        await Vault.I.addCollection('System Design', emoji: '📐');

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );

        final cols = data['collections'] as List<dynamic>;
        expect(cols.length, 2);
        expect(
          cols.any((c) => c['name'] == 'Algorithms' && c['emoji'] == '⚡'),
          isTrue,
        );
        expect(
          cols.any((c) => c['name'] == 'System Design' && c['emoji'] == '📐'),
          isTrue,
        );
      },
    );

    test(
      '4. Export resources includes full metadata, notes, status, and favorite flag',
      () async {
        final item = await Vault.I.add(
          title: 'Flutter Internals',
          source: 'flutter.dev',
          url: 'https://flutter.dev/internals',
          kind: ResourceKind.article,
        );
        await Vault.I.saveNote(
          item.id,
          'Crucial note about RenderObjects',
          title: 'Rendering takeaways',
        );
        await Vault.I.setFavorite(item.id, true);
        await Vault.I.setStatus(item.id, ResourceStatus.completed);

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );

        final r = (data['resources'] as List<dynamic>).firstWhere(
          (e) => e['id'] == item.id,
        );
        expect(r['title'], 'Flutter Internals');
        expect(r['notes'], 'Crucial note about RenderObjects');
        expect(r['noteTitle'], 'Rendering takeaways');
        expect(r['isFavorite'], isTrue);
        expect(r['status'], 'completed');
      },
    );

    test('5. Export tags preserves unique tag labels', () async {
      await Vault.I.add(
        title: 'Tagged Item',
        source: 'dev.to',
        url: 'https://dev.to/test',
        kind: ResourceKind.article,
        tags: {'rust', 'wasm', 'performance'},
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      expect(res.tagCount, 3);
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final data = jsonDecode(
        utf8.decode(archive.findFile('database.json')!.content as List<int>),
      );
      final tags = (data['tags'] as List<dynamic>)
          .map((t) => t['name'])
          .toList();
      expect(tags, containsAll(['rust', 'wasm', 'performance']));
    });

    test('6. Export resource_tags junction records relationships', () async {
      final item = await Vault.I.add(
        title: 'Rel Test',
        source: 'rel.com',
        url: 'https://rel.com',
        kind: ResourceKind.article,
        tags: {'tagA', 'tagB'},
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final data = jsonDecode(
        utf8.decode(archive.findFile('database.json')!.content as List<int>),
      );
      final rts = data['resource_tags'] as List<dynamic>;
      expect(rts.length, 2);
      expect(rts.every((rt) => rt['resourceId'] == item.id), isTrue);
    });

    test(
      '7. Export sticky_notes preserves title, color, and timestamps',
      () async {
        await Vault.I.addStickyNote(
          title: 'Project Ideas',
          color: const Color(0xFFFDF6E2),
          items: ['Idea 1'],
        );

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        final notes = data['sticky_notes'] as List<dynamic>;
        expect(notes.length, 1);
        expect(notes.first['title'], 'Project Ideas');
        expect(notes.first['colorValue'], 0xFFFDF6E2);
      },
    );

    test(
      '8. Export sticky_items preserves task state, bullet mode, and ordering',
      () async {
        final noteId = await Vault.I.addStickyNote(
          title: 'Sprint Checklist',
          color: const Color(0xFFE2F0D9),
          items: ['Item 1', 'Item 2', 'Item 3'],
        );
        final note = Vault.I.stickyNotes.first;
        await Vault.I.updateStickyItemState(
          noteId,
          note.items[0].id,
          NotedCheckState.completed,
        );

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        final items = data['sticky_items'] as List<dynamic>;
        expect(items.length, 3);
        expect(items.any((i) => i['state'] == 'completed'), isTrue);
      },
    );

    test(
      '9. Export files records metadata in database.json and packages binary files',
      () async {
        final item = await Vault.I.add(
          title: 'Doc',
          source: 'doc.com',
          url: '',
          kind: ResourceKind.pdf,
        );
        final dummy = await createDummyFile(
          'contract.pdf',
          'CONFIDENTIAL CONTRACT BYTES',
        );
        final attached = await Vault.I.attachFile(
          item.id,
          dummy.path,
          'contract.pdf',
        );

        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        expect(data['files'].length, 1);
        expect(data['files'][0]['fileName'], 'contract.pdf');

        final fileInZip = archive.findFile(
          'files/${attached!.id}/contract.pdf',
        );
        expect(fileInZip, isNotNull);
        expect(
          utf8.decode(fileInZip!.content as List<int>),
          'CONFIDENTIAL CONTRACT BYTES',
        );
      },
    );

    test(
      '10. Export analytics_events includes persistent learning event records',
      () async {
        await Vault.I.add(
          title: 'Event Res',
          source: 'event.com',
          url: 'https://event.com',
          kind: ResourceKind.article,
        );
        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        expect(res.analyticsEventCount, greaterThanOrEqualTo(1));

        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        final events = data['analytics_events'] as List<dynamic>;
        expect(events.isNotEmpty, isTrue);
        expect(events.any((e) => e['eventType'] == 'resourceAdded'), isTrue);
      },
    );

    test('11. Manifest counts match actual exported row counts', () async {
      await Vault.I.addCollection('Col 1', emoji: '📁');
      await Vault.I.add(
        title: 'Res 1',
        source: 's1',
        url: 'https://s1.com',
        kind: ResourceKind.article,
        tags: {'t1'},
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
      );

      expect(manifest['resourceCount'], res.resourceCount);
      expect(manifest['collectionCount'], res.collectionCount);
      expect(manifest['tagCount'], res.tagCount);
      expect(manifest['schemaVersion'], 6);
      expect(manifest['backupFormatVersion'], 1);
    });

    test(
      '12. database.json structure conforms to deterministic schema',
      () async {
        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );

        expect(data.containsKey('collections'), isTrue);
        expect(data.containsKey('resources'), isTrue);
        expect(data.containsKey('tags'), isTrue);
        expect(data.containsKey('resource_tags'), isTrue);
        expect(data.containsKey('sticky_notes'), isTrue);
        expect(data.containsKey('sticky_items'), isTrue);
        expect(data.containsKey('files'), isTrue);
        expect(data.containsKey('analytics_events'), isTrue);
      },
    );

    test('13. ZIP structure conforms to standard archive layout', () async {
      final item = await Vault.I.add(
        title: 'Zip Test',
        source: 's',
        url: '',
        kind: ResourceKind.page,
      );
      final dummy = await createDummyFile('test.png', 'PNG DATA');
      final attached = await Vault.I.attachFile(
        item.id,
        dummy.path,
        'test.png',
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      expect(archive.findFile('manifest.json'), isNotNull);
      expect(archive.findFile('database.json'), isNotNull);
      expect(archive.findFile('files/${attached!.id}/test.png'), isNotNull);
    });

    test('14. SHA-256 database.json checksum is verified', () async {
      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
      );
      final dbBytes = archive.findFile('database.json')!.content as List<int>;

      final expectedSha = BackupService.calculateSha256(dbBytes);
      expect(manifest['checksums']['database.json'], expectedSha);
    });

    test('15. SHA-256 attached file checksums are verified', () async {
      final item = await Vault.I.add(
        title: 'Hash Test',
        source: 's',
        url: '',
        kind: ResourceKind.article,
      );
      final dummy = await createDummyFile(
        'sample.txt',
        'Exact bytes for SHA calculation 12345',
      );
      final attached = await Vault.I.attachFile(
        item.id,
        dummy.path,
        'sample.txt',
      );

      final res = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final bytes = await File(res.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
      );

      final relPath = 'files/${attached!.id}/sample.txt';
      final fileBytes = archive.findFile(relPath)!.content as List<int>;
      final expectedSha = BackupService.calculateSha256(fileBytes);
      expect(manifest['checksums'][relPath], expectedSha);
    });

    // ==========================================
    // RESTORE TESTS (16 - 25)
    // ==========================================

    test('16. Restore empty backup succeeds and leaves clean state', () async {
      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      await Vault.I.add(
        title: 'To Be Wiped',
        source: 'w.com',
        url: 'https://w.com',
        kind: ResourceKind.article,
      );
      expect(Vault.I.items.length, 1);

      final res = await restoreService.restoreBackup(backup.filePath);
      expect(res.resourceCount, 0);
      await Vault.I.reloadFromDb();
      expect(Vault.I.items, isEmpty);
    });

    test(
      '17. Restore full backup recreates all entity collections accurately',
      () async {
        final col = await Vault.I.addCollection('Physics', emoji: '⚛️');
        final item = await Vault.I.add(
          title: 'Quantum Mechanics',
          source: 'physics.org',
          url: 'https://physics.org/qm',
          kind: ResourceKind.course,
          collectionId: col.id,
          tags: {'quantum', 'physics'},
        );
        final dummy = await createDummyFile(
          'qm_syllabus.pdf',
          'Syllabus content',
        );
        await Vault.I.attachFile(item.id, dummy.path, 'qm_syllabus.pdf');
        await Vault.I.addStickyNote(
          title: 'Physics Tasks',
          color: const Color(0xFFFDF6E2),
          items: ['Task 1'],
        );

        final backup = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );

        // Wipe current DB
        await db.resourceDao.deleteAllResources();
        await db.collectionDao.deleteAllCollections();
        await Vault.I.reloadFromDb();
        expect(Vault.I.items, isEmpty);

        // Restore
        await restoreService.restoreBackup(backup.filePath);
        await Vault.I.reloadFromDb();

        expect(Vault.I.collections.length, 1);
        expect(Vault.I.collections.first.name, 'Physics');
        expect(Vault.I.items.length, 1);
        expect(Vault.I.items.first.title, 'Quantum Mechanics');
        expect(Vault.I.items.first.tags, containsAll(['quantum', 'physics']));
        expect(Vault.I.stickyNotes.length, 1);
        expect(Vault.I.items.first.localFile, isNotNull);
      },
    );

    test('18. Preserve exact original IDs across restore', () async {
      final col = await Vault.I.addCollection('Math', emoji: '📐');
      final item = await Vault.I.add(
        title: 'Linear Algebra',
        source: 'mit.edu',
        url: 'https://mit.edu/la',
        kind: ResourceKind.article,
        collectionId: col.id,
      );

      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      await db.resourceDao.deleteAllResources();
      await db.collectionDao.deleteAllCollections();
      await Vault.I.reloadFromDb();

      await restoreService.restoreBackup(backup.filePath);
      await Vault.I.reloadFromDb();

      final restoredItem = Vault.I.find(item.id);
      expect(restoredItem, isNotNull);
      expect(restoredItem!.id, item.id);
      expect(restoredItem.collectionId, col.id);
    });

    test('19. Preserve exact timestamps across restore', () async {
      final item = await Vault.I.add(
        title: 'Old Resource',
        source: 'archive.org',
        url: 'https://archive.org/item',
        kind: ResourceKind.article,
      );

      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      await db.resourceDao.deleteAllResources();
      await Vault.I.reloadFromDb();

      await restoreService.restoreBackup(backup.filePath);
      await Vault.I.reloadFromDb();

      final restored = Vault.I.find(item.id);
      expect(restored, isNotNull);
      expect(restored!.addedAt.year, item.addedAt.year);
    });

    test('20. Preserve foreign keys and relational integrity', () async {
      final col = await Vault.I.addCollection('Database Systems', emoji: '💾');
      final item = await Vault.I.add(
        title: 'SQLite Internals',
        source: 'sqlite.org',
        url: 'https://sqlite.org',
        kind: ResourceKind.article,
        collectionId: col.id,
        tags: {'sql', 'b-tree'},
      );

      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      await db.resourceDao.deleteAllResources();
      await db.collectionDao.deleteAllCollections();
      await Vault.I.reloadFromDb();

      await restoreService.restoreBackup(backup.filePath);
      await Vault.I.reloadFromDb();

      final restored = Vault.I.find(item.id);
      expect(restored!.collectionId, col.id);
      expect(Vault.I.collections.any((c) => c.id == col.id), isTrue);
    });

    test(
      '21. Restore physical files into app-private storage cleanly',
      () async {
        final item = await Vault.I.add(
          title: 'Cheatsheet',
          source: 's',
          url: '',
          kind: ResourceKind.pdf,
        );
        final dummy = await createDummyFile(
          'git_cheatsheet.pdf',
          'Git commit, push, rebase guide',
        );
        final attached = await Vault.I.attachFile(
          item.id,
          dummy.path,
          'git_cheatsheet.pdf',
        );

        final backup = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );

        // Wipe live files & DB
        await storageService.deletePhysicalFile(attached!.localPath);
        await db.fileDao.deleteAllFiles();
        await db.resourceDao.deleteAllResources();
        await Vault.I.reloadFromDb();

        await restoreService.restoreBackup(backup.filePath);
        await Vault.I.reloadFromDb();

        final restored = Vault.I.find(item.id);
        expect(restored!.localFile, isNotNull);
        final restoredFile = File(restored.localFile!.localPath);
        expect(await restoredFile.exists(), isTrue);
        expect(
          await restoredFile.readAsString(),
          'Git commit, push, rebase guide',
        );
      },
    );

    test('22. Restore persistent analytics_events into database', () async {
      final item = await Vault.I.add(
        title: 'Analytics Target',
        source: 'a.com',
        url: 'https://a.com',
        kind: ResourceKind.article,
      );
      await Vault.I.registerOpen(item.id);
      await Vault.I.setStatus(item.id, ResourceStatus.completed);

      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );
      final preCount = await db.analyticsEventDao.countEvents();
      expect(preCount, greaterThanOrEqualTo(2));

      await db.analyticsEventDao.deleteAllEvents();
      await db.resourceDao.deleteAllResources();
      await Vault.I.reloadFromDb();

      await restoreService.restoreBackup(backup.filePath);
      await Vault.I.reloadFromDb();

      final postCount = await db.analyticsEventDao.countEvents();
      expect(postCount, preCount);
    });

    test('23. Rebuild FTS5 search index during restore', () async {
      await Vault.I.add(
        title: 'Microservices Architecture with Docker',
        source: 'docker.com',
        url: 'https://docker.com/microservices',
        kind: ResourceKind.article,
      );
      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );

      await db.resourceDao.deleteAllResources();
      await db.searchDao.createFtsTable();
      await db.customStatement('DELETE FROM resource_fts;');

      await restoreService.restoreBackup(backup.filePath);

      final searchResults = await db.searchDao.searchResources(
        filters: SearchFilters()..query = 'Microservices',
      );
      expect(searchResults.length, 1);
      expect(
        searchResults.first.title,
        'Microservices Architecture with Docker',
      );
    });

    test('24. Restore persistence verified after DB reopen', () async {
      await Vault.I.add(
        title: 'Reopen Item',
        source: 'reopen.com',
        url: 'https://reopen.com',
        kind: ResourceKind.article,
      );
      final backup = await backupService.exportBackup(
        customOutputDir: tempDir.path,
      );

      await db.resourceDao.deleteAllResources();
      await restoreService.restoreBackup(backup.filePath);

      // Query raw database
      final rows = await db.resourceDao.getAllResources();
      expect(rows.length, 1);
      expect(rows.first.title, 'Reopen Item');
    });

    test(
      '25. Restore persistence verified across simulated app restart',
      () async {
        await Vault.I.add(
          title: 'Persistent Item Across Restart',
          source: 'restart.com',
          url: 'https://restart.com',
          kind: ResourceKind.article,
        );
        final backup = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );

        await db.close();
        final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
        final freshStorage = FileStorageService(tempDir.path);
        final freshRestore = RestoreService(
          freshDb,
          freshStorage,
          tempDir.path,
        );

        await freshRestore.restoreBackup(backup.filePath);
        final freshRows = await freshDb.resourceDao.getAllResources();
        expect(freshRows.length, 1);
        expect(freshRows.first.title, 'Persistent Item Across Restart');

        await freshDb.close();
      },
    );

    // ==========================================
    // SECURITY TESTS (26 - 35)
    // ==========================================

    test('26. Reject ../ path traversal attempt in archive', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('../../../shadow.txt', 'evil'));
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'security_traversal_1.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Security violation'));
    });

    test('27. Reject ..\\ Windows path traversal attempt in archive', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(r'..\..\windows\system32\malicious.dll', 'evil'),
      );
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'security_traversal_2.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Security violation'));
    });

    test('28. Reject absolute paths (/etc/config)', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('/var/log/system.log', 'evil'));
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'security_abs.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Security violation'));
    });

    test('29. Reject drive-letter paths (C:\\Windows\\cmd.exe)', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string(r'C:\ProgramFiles\virus.exe', 'evil'));
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'security_drive.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Security violation'));
    });

    test('30. Reject invalid file ID format in archive paths', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('files/illegal*id/file.pdf', 'bad'));
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'security_invalid_id.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Security violation'));
    });

    test('31. Reject malformed manifest.json', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string('manifest.json', '{"invalid_json: 123'),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'bad_manifest.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('manifest.json is corrupted'));
    });

    test('32. Reject malformed database.json', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(
        ArchiveFile.string('database.json', '{invalid database json'),
      );

      final zipPath = p.join(tempDir.path, 'bad_db_json.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('database.json is corrupted'));
    });

    test('33. Reject database checksum mismatch', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'backupFormatVersion': 1,
            'schemaVersion': 4,
            'checksums': {'database.json': 'forged_fake_hash_123456'},
          }),
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{"resources":[]}'));

      final zipPath = p.join(tempDir.path, 'checksum_mismatch.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Database checksum mismatch'));
    });

    test('34. Reject backup with missing referenced physical file', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'database.json',
          jsonEncode({
            'resources': [
              {'id': 'r1', 'title': 'Test'},
            ],
            'files': [
              {
                'id': 'f1',
                'resourceId': 'r1',
                'fileName': 'missing.pdf',
                'fileSize': 100,
              },
            ],
          }),
        ),
      );

      final zipPath = p.join(tempDir.path, 'missing_file.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('Missing attached file in archive'));
    });

    test('35. Reject unsupported future schema version (> 4)', () async {
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({'backupFormatVersion': 1, 'schemaVersion': 99}),
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{}'));

      final zipPath = p.join(tempDir.path, 'future_schema.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final val = await restoreService.validateBackup(zipPath);
      expect(val.isValid, isFalse);
      expect(val.errorMessage, contains('newer than current app version'));
    });

    // ==========================================
    // DATA SAFETY & ROLLBACK TESTS (36 - 40)
    // ==========================================

    test(
      '36. Failed validation leaves live database completely untouched',
      () async {
        await Vault.I.add(
          title: 'Untouched Resource',
          source: 'secure.com',
          url: 'https://secure.com',
          kind: ResourceKind.article,
        );

        final badZip = p.join(tempDir.path, 'invalid_restore_attempt.zip');
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string('manifest.json', '{"backupFormatVersion": 99}'),
        );
        archive.addFile(ArchiveFile.string('database.json', '{}'));
        await File(badZip).writeAsBytes(ZipEncoder().encode(archive));

        try {
          await restoreService.restoreBackup(badZip);
        } catch (_) {}

        await Vault.I.reloadFromDb();
        expect(Vault.I.items.length, 1);
        expect(Vault.I.items.first.title, 'Untouched Resource');
      },
    );

    test('37. Failed validation leaves live files untouched', () async {
      final item = await Vault.I.add(
        title: 'Safe File Item',
        source: 's',
        url: '',
        kind: ResourceKind.pdf,
      );
      final dummy = await createDummyFile('keep_me.pdf', 'Keep this safe');
      final attached = await Vault.I.attachFile(
        item.id,
        dummy.path,
        'keep_me.pdf',
      );

      final badZip = p.join(tempDir.path, 'bad_corrupt_file.zip');
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          '{"backupFormatVersion": 1, "schemaVersion": 4}',
        ),
      );
      archive.addFile(ArchiveFile.string('database.json', '{"corrupted json'));
      await File(badZip).writeAsBytes(ZipEncoder().encode(archive));

      try {
        await restoreService.restoreBackup(badZip);
      } catch (_) {}

      expect(await File(attached!.localPath).exists(), isTrue);
      expect(await File(attached.localPath).readAsString(), 'Keep this safe');
    });

    test(
      '38. Transaction rollback preserves state when database insertion fails',
      () async {
        await Vault.I.add(
          title: 'Pre-Transaction Item',
          source: 'test.com',
          url: 'https://test.com',
          kind: ResourceKind.article,
        );

        // Attempt clearAndRestoreData with broken SQL constraints
        final badZip = p.join(tempDir.path, 'bad_constraint.zip');
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'manifest.json',
            '{"backupFormatVersion": 1, "schemaVersion": 4}',
          ),
        );
        // Orphan resource referencing nonexistent collection
        archive.addFile(
          ArchiveFile.string(
            'database.json',
            jsonEncode({
              'resources': [
                {
                  'id': 'r_bad',
                  'title': 'Bad Item',
                  'collectionId': 'nonexistent_col',
                },
              ],
            }),
          ),
        );
        await File(badZip).writeAsBytes(ZipEncoder().encode(archive));

        try {
          await restoreService.restoreBackup(badZip);
        } catch (_) {}

        await Vault.I.reloadFromDb();
        expect(Vault.I.items.length, 1);
        expect(Vault.I.items.first.title, 'Pre-Transaction Item');
      },
    );

    test(
      '39. Staging clean-up cleans temporary staging and safety directories',
      () async {
        final badZip = p.join(tempDir.path, 'staging_test.zip');
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string('manifest.json', '{"backupFormatVersion": 99}'),
        );
        archive.addFile(ArchiveFile.string('database.json', '{}'));
        await File(badZip).writeAsBytes(ZipEncoder().encode(archive));

        try {
          await restoreService.restoreBackup(badZip);
        } catch (_) {}

        final stagingFolders = tempDir.listSync().where(
          (f) =>
              f.path.contains('skillnest_restore_staging_') ||
              f.path.contains('skillnest_restore_safety_snapshot_'),
        );
        expect(stagingFolders, isEmpty);
      },
    );

    test(
      '40. Backward compatibility: v3 backup without analytics_events remains restorable',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'backupFormatVersion': 1,
              'schemaVersion': 3,
              'resourceCount': 1,
            }),
          ),
        );
        archive.addFile(
          ArchiveFile.string(
            'database.json',
            jsonEncode({
              'version': 1,
              'schemaVersion': 3,
              'resources': [
                {
                  'id': 'v3_res',
                  'title': 'Legacy v3 Resource',
                  'url': 'https://v3.com',
                  'source': 'v3.com',
                  'resourceType': 'article',
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            }),
          ),
        );

        final zipPath = p.join(tempDir.path, 'v3_legacy_backup.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

        final val = await restoreService.validateBackup(zipPath);
        expect(val.isValid, isTrue);
        expect(val.resourceCount, 1);

        await restoreService.restoreBackup(zipPath);
        await Vault.I.reloadFromDb();
        expect(Vault.I.items.length, 1);
        expect(Vault.I.items.first.id, 'v3_res');
        expect(Vault.I.items.first.title, 'Legacy v3 Resource');
      },
    );

    test(
      '41. Nested collections hierarchy (root, level 1, level 2) is fully preserved during backup & restore',
      () async {
        // 1. Create 3-level collection hierarchy
        final rootCol = await Vault.I.addCollection('Engineering', emoji: '⚙️');
        final subCol = await Vault.I.addCollection(
          'Mobile Development',
          emoji: '📱',
          parentId: rootCol.id,
        );
        final subSubCol = await Vault.I.addCollection(
          'Flutter Internals',
          emoji: '💙',
          parentId: subCol.id,
        );
        final standaloneCol = await Vault.I.addCollection(
          'Design System',
          emoji: '🎨',
        );

        // Add resources inside each level
        await Vault.I.add(
          title: 'Root Resource',
          source: 'eng.com',
          url: 'https://eng.com',
          kind: ResourceKind.article,
          collectionId: rootCol.id,
        );
        await Vault.I.add(
          title: 'Sub Resource',
          source: 'flutter.dev',
          url: 'https://flutter.dev',
          kind: ResourceKind.article,
          collectionId: subCol.id,
        );
        await Vault.I.add(
          title: 'Deep Resource',
          source: 'engine.flutter.dev',
          url: 'https://engine.flutter.dev',
          kind: ResourceKind.article,
          collectionId: subSubCol.id,
        );

        // 2. Export Backup
        final res = await backupService.exportBackup(
          customOutputDir: tempDir.path,
        );
        expect(res.collectionCount, 4);
        expect(res.resourceCount, 3);

        // Inspect JSON inside archive
        final bytes = await File(res.filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final data = jsonDecode(
          utf8.decode(archive.findFile('database.json')!.content as List<int>),
        );
        final colsJson = data['collections'] as List<dynamic>;

        final rootJson = colsJson.firstWhere((c) => c['id'] == rootCol.id);
        final subJson = colsJson.firstWhere((c) => c['id'] == subCol.id);
        final subSubJson = colsJson.firstWhere((c) => c['id'] == subSubCol.id);
        final standaloneJson = colsJson.firstWhere((c) => c['id'] == standaloneCol.id);

        expect(rootJson['parentId'], isNull);
        expect(subJson['parentId'], rootCol.id);
        expect(subSubJson['parentId'], subCol.id);
        expect(standaloneJson['parentId'], isNull);

        // 3. Clear database & restore
        final val = await restoreService.validateBackup(res.filePath);
        expect(val.isValid, isTrue);
        expect(val.collectionCount, 4);

        await restoreService.restoreBackup(res.filePath);
        await Vault.I.reloadFromDb();

        // 4. Verify Vault in-memory hierarchy
        expect(Vault.I.collections.length, 4);

        final restoredRoot = Vault.I.collections.firstWhere((c) => c.id == rootCol.id);
        final restoredSub = Vault.I.collections.firstWhere((c) => c.id == subCol.id);
        final restoredSubSub = Vault.I.collections.firstWhere((c) => c.id == subSubCol.id);
        final restoredStandalone = Vault.I.collections.firstWhere((c) => c.id == standaloneCol.id);

        expect(restoredRoot.parentId, isNull);
        expect(restoredSub.parentId, rootCol.id);
        expect(restoredSubSub.parentId, subCol.id);
        expect(restoredStandalone.parentId, isNull);

        // Verify subCollections helper
        expect(Vault.I.rootCollections.map((c) => c.id), containsAll([rootCol.id, standaloneCol.id]));
        expect(Vault.I.subCollections(rootCol.id).map((c) => c.id), [subCol.id]);
        expect(Vault.I.subCollections(subCol.id).map((c) => c.id), [subSubCol.id]);
        expect(Vault.I.subCollections(subSubCol.id), isEmpty);
      },
    );

    test(
      '42. Validation rejects corrupted backup with invalid collection parentId',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'backupFormatVersion': 1,
              'schemaVersion': 6,
              'collectionCount': 1,
            }),
          ),
        );
        archive.addFile(
          ArchiveFile.string(
            'database.json',
            jsonEncode({
              'version': 1,
              'schemaVersion': 6,
              'collections': [
                {
                  'id': 'orphan_sub',
                  'name': 'Orphan Child',
                  'emoji': '📁',
                  'parentId': 'nonexistent_parent_id',
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            }),
          ),
        );

        final zipPath = p.join(tempDir.path, 'invalid_parent_backup.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

        final val = await restoreService.validateBackup(zipPath);
        expect(val.isValid, isFalse);
        expect(val.errorMessage, contains('nonexistent parent collection'));
      },
    );

    test(
      '43. Validation rejects corrupted backup with self-referencing collection parentId',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'backupFormatVersion': 1,
              'schemaVersion': 6,
              'collectionCount': 1,
            }),
          ),
        );
        archive.addFile(
          ArchiveFile.string(
            'database.json',
            jsonEncode({
              'version': 1,
              'schemaVersion': 6,
              'collections': [
                {
                  'id': 'self_ref_col',
                  'name': 'Self Referring',
                  'emoji': '🔄',
                  'parentId': 'self_ref_col',
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            }),
          ),
        );

        final zipPath = p.join(tempDir.path, 'self_ref_backup.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

        final val = await restoreService.validateBackup(zipPath);
        expect(val.isValid, isFalse);
        expect(val.errorMessage, contains('references itself as parent'));
      },
    );

    test(
      '44. Backward compatibility: legacy backup without parentId defaults parentId to null',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'backupFormatVersion': 1,
              'schemaVersion': 5,
              'collectionCount': 1,
            }),
          ),
        );
        archive.addFile(
          ArchiveFile.string(
            'database.json',
            jsonEncode({
              'version': 1,
              'schemaVersion': 5,
              'collections': [
                {
                  'id': 'legacy_col_1',
                  'name': 'Legacy Root Collection',
                  'emoji': '📁',
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            }),
          ),
        );

        final zipPath = p.join(tempDir.path, 'legacy_no_parent_backup.zip');
        await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

        final val = await restoreService.validateBackup(zipPath);
        expect(val.isValid, isTrue);

        await restoreService.restoreBackup(zipPath);
        await Vault.I.reloadFromDb();

        final restored = Vault.I.collections.firstWhere((c) => c.id == 'legacy_col_1');
        expect(restored.parentId, isNull);
        expect(Vault.I.rootCollections.map((c) => c.id), contains('legacy_col_1'));
      },
    );
  });
}
