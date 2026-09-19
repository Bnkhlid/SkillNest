import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/core/services/file_storage_service.dart';
import 'package:learning_vault/features/resources/data/file_repository.dart';
import 'package:learning_vault/features/resources/data/resource_repository.dart';
import 'package:learning_vault/features/search/data/search_repository.dart';
import 'package:learning_vault/models.dart';
import 'package:learning_vault/vault.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late FileStorageService storageService;
  late FileRepository fileRepo;
  late ResourceRepository resourceRepo;
  late SearchRepository searchRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skillnest_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storageService = FileStorageService(tempDir.path);
    fileRepo = FileRepository(db.fileDao, storageService, db.searchDao);
    resourceRepo = ResourceRepository(
      db.resourceDao,
      db.tagDao,
      db.searchDao,
      db.fileDao,
      storageService,
    );
    searchRepo = SearchRepository(db.searchDao, db.tagDao);
    await Vault.I.init(db, storageService);
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

  group('Local Files & File Resources Tests (Phase 6)', () {
    test('1. Fresh database starts with schema version 4 and files table accessible', () async {
      expect(db.schemaVersion, 5);
      final files = await db.fileDao.getAllFiles();
      expect(files, isEmpty);
    });

    test('2. FileStorageService copies file into private storage with metadata', () async {
      final dummy = await createDummyFile('test_doc.pdf', 'PDF dummy content 12345');
      final saved = await storageService.copyFileToPrivateStorage(
        sourcePath: dummy.path,
        fileName: 'test_doc.pdf',
      );

      expect(saved.fileId, startsWith('file_'));
      expect(saved.fileName, 'test_doc.pdf');
      expect(saved.mimeType, 'application/pdf');
      expect(saved.fileSize, greaterThan(0));
      expect(await File(saved.localPath).exists(), isTrue);
    });

    test('3. Attach local file to Resource persists in SQLite and associates properly', () async {
      final resId = await resourceRepo.addResource(
        url: '',
        title: 'Flutter Guide PDF',
        kind: ResourceKind.pdf,
        source: 'local file',
      );

      final dummy = await createDummyFile('flutter_guide.pdf', 'Guide content');
      final fileItem = await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'flutter_guide.pdf',
      );

      expect(fileItem.resourceId, resId);
      expect(fileItem.fileName, 'flutter_guide.pdf');
      expect(fileItem.mimeType, 'application/pdf');
      expect(fileItem.humanSize, contains('B'));

      final retrievedResource = await resourceRepo.findById(resId);
      expect(retrievedResource, isNotNull);
      expect(retrievedResource!.localFile, isNotNull);
      expect(retrievedResource.localFile!.id, fileItem.id);
      expect(retrievedResource.localFile!.fileName, 'flutter_guide.pdf');
    });

    test('4. Database failure during attach cleans up copied physical file', () async {
      final resId = await resourceRepo.addResource(url: '', title: 'Test Res');
      final dummy = await createDummyFile('orphan_test.txt', 'some text');
      
      // First insert to take the ID
      await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'orphan_test.txt',
        forcedFileId: 'duplicate_id_123',
      );

      // Second insert with the SAME forcedFileId (guaranteed UNIQUE constraint violation in SQLite)
      Object? caughtError;
      try {
        await fileRepo.saveAndAttachFile(
          resourceId: resId,
          sourcePath: dummy.path,
          fileName: 'orphan_test_2.txt',
          forcedFileId: 'duplicate_id_123',
        );
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isNotNull);
      // Verify no orphan file remains on disk
      final storageDir = await storageService.getStorageDirectory();
      final orphanFile = File(p.join(storageDir.path, 'duplicate_id_123', 'orphan_test_2.txt'));
      expect(await orphanFile.exists(), isFalse);
    });

    test('5. Resource with local file persists across simulated restart', () async {
      final resId = await resourceRepo.addResource(
        url: '',
        title: 'Offline Machine Learning Notes',
        kind: ResourceKind.article,
      );
      final dummy = await createDummyFile('ml_notes.md', '# Machine Learning');
      await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'ml_notes.md',
      );

      // Simulate app restart / reloadFromDb
      await Vault.I.reloadFromDb();
      final vaultItem = Vault.I.find(resId);
      expect(vaultItem, isNotNull);
      expect(vaultItem!.localFile, isNotNull);
      expect(vaultItem.localFile!.fileName, 'ml_notes.md');
      expect(await File(vaultItem.localFile!.localPath).exists(), isTrue);
    });

    test('6. Soft-deleting resource retains physical file and DB attachment', () async {
      final item = await Vault.I.add(
        url: '',
        title: 'Trash Candidate Doc',
        source: 'local file',
        kind: ResourceKind.pdf,
      );
      final dummy = await createDummyFile('trash_doc.pdf', 'Content');
      final fileItem = await Vault.I.attachFile(item.id, dummy.path, 'trash_doc.pdf');

      // Move to trash
      await Vault.I.delete(item.id);

      // Verify file is still in DB and on disk
      final dbFile = await db.fileDao.getFileForResource(item.id);
      expect(dbFile, isNotNull);
      expect(await File(fileItem!.localPath).exists(), isTrue);

      // Verify in Vault trash
      final trashEntry = Vault.I.trash.firstWhere((t) => t.item.id == item.id);
      expect(trashEntry.item.localFile, isNotNull);
      expect(trashEntry.item.localFile!.fileName, 'trash_doc.pdf');
    });

    test('7. Restoring resource preserves local file accessibility', () async {
      final item = await Vault.I.add(
        url: '',
        title: 'Restorable Doc',
        source: 'local file',
        kind: ResourceKind.pdf,
      );
      final dummy = await createDummyFile('restore_doc.pdf', 'Content');
      final fileItem = await Vault.I.attachFile(item.id, dummy.path, 'restore_doc.pdf');

      await Vault.I.delete(item.id);
      await Vault.I.restore(item.id);

      final restoredItem = Vault.I.find(item.id);
      expect(restoredItem, isNotNull);
      expect(restoredItem!.localFile, isNotNull);
      expect(restoredItem.localFile!.fileName, 'restore_doc.pdf');
      expect(await File(fileItem!.localPath).exists(), isTrue);
    });

    test('8. Permanent delete safely purges physical file and DB record', () async {
      final item = await Vault.I.add(
        url: '',
        title: 'Permanent Delete Doc',
        source: 'local file',
        kind: ResourceKind.pdf,
      );
      final dummy = await createDummyFile('perm_doc.pdf', 'Content to be purged');
      final fileItem = await Vault.I.attachFile(item.id, dummy.path, 'perm_doc.pdf');

      expect(await File(fileItem!.localPath).exists(), isTrue);

      await Vault.I.delete(item.id);
      await Vault.I.deletePermanent(item.id);

      // Verify DB record is gone
      final dbFile = await db.fileDao.getFileForResource(item.id);
      expect(dbFile, isNull);

      // Verify physical file is gone
      expect(await File(fileItem.localPath).exists(), isFalse);
    });

    test('9. Empty trash deletes physical files for all purged resources', () async {
      final item1 = await Vault.I.add(url: '', title: 'Trash 1', source: 'local file', kind: ResourceKind.pdf);
      final item2 = await Vault.I.add(url: '', title: 'Trash 2', source: 'local file', kind: ResourceKind.pdf);

      final d1 = await createDummyFile('t1.pdf', 'Content 1');
      final d2 = await createDummyFile('t2.pdf', 'Content 2');

      final f1 = await Vault.I.attachFile(item1.id, d1.path, 't1.pdf');
      final f2 = await Vault.I.attachFile(item2.id, d2.path, 't2.pdf');

      await Vault.I.delete(item1.id);
      await Vault.I.delete(item2.id);

      expect(await File(f1!.localPath).exists(), isTrue);
      expect(await File(f2!.localPath).exists(), isTrue);

      await Vault.I.emptyTrash();

      expect(await File(f1.localPath).exists(), isFalse);
      expect(await File(f2.localPath).exists(), isFalse);
      expect(await db.fileDao.getFileForResource(item1.id), isNull);
      expect(await db.fileDao.getFileForResource(item2.id), isNull);
    });

    test('10. Missing physical file handled gracefully without crashing', () async {
      final resId = await resourceRepo.addResource(url: '', title: 'Missing File Test');
      final dummy = await createDummyFile('will_delete.pdf', 'Temporary');
      final fileItem = await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'will_delete.pdf',
      );

      // Physically delete file from disk to simulate external deletion/corruption
      await File(fileItem.localPath).delete();

      // Check file existence abstraction
      final exists = await fileRepo.fileExistsOnDisk(fileItem.localPath);
      expect(exists, isFalse);

      // Verify repository and vault do not crash when loading or finding item
      final item = await resourceRepo.findById(resId);
      expect(item, isNotNull);
      expect(item!.localFile, isNotNull);
    });

    test('11. Attached file name is indexed and searchable via FTS5', () async {
      final resId = await resourceRepo.addResource(
        url: '',
        title: 'Deep Architecture Overview',
        source: 'local file',
      );
      final dummy = await createDummyFile('kubernetes_internals_handbook.pdf', 'K8s');
      await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'kubernetes_internals_handbook.pdf',
      );

      final searchResults = await searchRepo.search(
        filters: SearchFilters()..query = 'kubernetes handbook',
      );

      expect(searchResults.length, 1);
      expect(searchResults.first.id, resId);
    });

    test('12. Offline file creation and retrieval works completely offline', () async {
      Vault.I.setOffline(true);

      final resId = await resourceRepo.addResource(
        url: '',
        title: 'Offline Design System Spec',
        source: 'local file',
      );
      final dummy = await createDummyFile('design_tokens.json', '{"color": "yellow"}');
      final fileItem = await fileRepo.saveAndAttachFile(
        resourceId: resId,
        sourcePath: dummy.path,
        fileName: 'design_tokens.json',
      );

      expect(fileItem.fileName, 'design_tokens.json');
      expect(await File(fileItem.localPath).exists(), isTrue);

      final item = await resourceRepo.findById(resId);
      expect(item, isNotNull);
      expect(item!.localFile!.fileName, 'design_tokens.json');
    });
  });
}
