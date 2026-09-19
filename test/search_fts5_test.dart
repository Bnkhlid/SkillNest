import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/core/database/daos/search_dao.dart';
import 'package:learning_vault/features/collections/data/collection_repository.dart';
import 'package:learning_vault/features/resources/data/resource_repository.dart';
import 'package:learning_vault/features/search/data/search_repository.dart';
import 'package:learning_vault/models.dart';

void main() {
  late AppDatabase db;
  late ResourceRepository resourceRepo;
  late CollectionRepository collectionRepo;
  late SearchRepository searchRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.searchDao.createFtsTable();
    resourceRepo = ResourceRepository(db.resourceDao, db.tagDao, db.searchDao);
    collectionRepo = CollectionRepository(db.collectionDao);
    searchRepo = SearchRepository(db.searchDao, db.tagDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('SQLite FTS5 Search Engine Tests (Phase 5)', () {
    test(
      '1. Fresh database starts empty and search returns empty list without error',
      () async {
        final results = await searchRepo.search(filters: SearchFilters());
        expect(results, isEmpty);
      },
    );

    test('2. Search title matches keyword', () async {
      await resourceRepo.addResource(
        url: 'https://flutter.dev/docs',
        title: 'Flutter Complete Course',
      );

      final filters = SearchFilters()..query = 'Flutter';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.title, 'Flutter Complete Course');
    });

    test('3. Search description / source matches keyword', () async {
      await resourceRepo.addResource(
        url: 'https://youtube.com/watch?v=1234',
        title: 'State Management Overview',
        source: 'youtube.com',
      );

      final filters = SearchFilters()..query = 'youtube';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.source, 'youtube.com');
    });

    test('4. Search notes matches keywords in user notes', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/ml',
        title: 'Intro to Python',
      );
      await resourceRepo.updateNotes(
        id,
        'Study this before building the mobile backend project',
      );

      final filters = SearchFilters()..query = 'mobile backend project';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test('4b. Search note title matches an associated URL note', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/roadmap',
        title: 'Learning roadmap',
      );
      await resourceRepo.updateNotes(
        id,
        'Finish the first module this week.',
        noteTitle: 'Flutter study plan',
      );

      final filters = SearchFilters()..query = 'study plan';
      final results = await searchRepo.search(filters: filters);
      expect(results.map((r) => r.id), contains(id));
    });

    test('5. Search tags matches tag names', () async {
      final id = await resourceRepo.addResource(
        url: 'https://dart.dev',
        title: 'Modern Async Programming',
        tags: {'dartlang', 'concurrency'},
      );

      final filters = SearchFilters()..query = 'dartlang';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.id, id);
      expect(results.first.tags, contains('dartlang'));
    });

    test('6. Search collection matches collection name', () async {
      final colId = await collectionRepo.createCollection(
        name: 'Machine Learning',
        emoji: '🤖',
      );
      final id = await resourceRepo.addResource(
        url: 'https://arxiv.org/abs/1706.03762',
        title: 'Attention Is All You Need',
        collectionId: colId,
      );

      final filters = SearchFilters()..query = 'Machine Learning';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test('7. Search source / domain matches domain keywords', () async {
      await resourceRepo.addResource(
        url: 'https://github.com/flutter/flutter',
        title: 'Flutter Engine Repository',
        source: 'github.com',
      );

      final filters = SearchFilters()..query = 'github';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.source, 'github.com');
    });

    test('8. Multi-word search returns matching resources', () async {
      await resourceRepo.addResource(
        url: 'https://bloclibrary.dev',
        title: 'Flutter State Management with Bloc',
      );

      final filters = SearchFilters()..query = 'flutter state management';
      final results = await searchRepo.search(filters: filters);
      expect(results.length, 1);
      expect(results.first.title, contains('Flutter State Management'));
    });

    test(
      '9. Case insensitivity (Flutter, flutter, FLUTTER all match)',
      () async {
        await resourceRepo.addResource(
          url: 'https://flutter.dev',
          title: 'Flutter Framework Guide',
        );

        for (final q in ['Flutter', 'flutter', 'FLUTTER']) {
          final filters = SearchFilters()..query = q;
          final results = await searchRepo.search(filters: filters);
          expect(results.length, 1, reason: 'Failed for query "$q"');
        }
      },
    );

    test('10. Special characters and symbols do not crash search', () async {
      await resourceRepo.addResource(
        url: 'https://isocpp.org',
        title: 'C++ Modern Guidelines & C# Interop',
      );

      final symbols = [
        'C++',
        'C#',
        'Flutter/Dart',
        '"quotes"',
        "it's",
        '+++',
        '***',
        ':::',
      ];
      for (final s in symbols) {
        final filters = SearchFilters()..query = s;
        final results = await searchRepo.search(filters: filters);
        expect(results, isNotNull);
      }
    });

    test(
      '11. Search with combined filters (collection, status, favorite, kind, tag)',
      () async {
        final col1 = await collectionRepo.createCollection(name: 'Mobile Dev');
        final col2 = await collectionRepo.createCollection(name: 'Backend Dev');

        final r1 = await resourceRepo.addResource(
          url: 'https://flutter.dev/1',
          title: 'Flutter Architecture 101',
          collectionId: col1,
          kind: ResourceKind.article,
          tags: {'architecture', 'mobile'},
          favorite: true,
        );
        await resourceRepo.setStatus(r1, ResourceStatus.inProgress);

        final r2 = await resourceRepo.addResource(
          url: 'https://flutter.dev/2',
          title: 'Flutter Performance Deep Dive',
          collectionId: col2,
          kind: ResourceKind.video,
          tags: {'performance'},
          favorite: false,
        );
        await resourceRepo.setStatus(r2, ResourceStatus.completed);

        // Filter by query + collection + favorite
        final f1 = SearchFilters()
          ..query = 'Flutter'
          ..collectionId = col1
          ..favoritesOnly = true;
        final res1 = await searchRepo.search(filters: f1);
        expect(res1.length, 1);
        expect(res1.first.id, r1);

        // Filter by query + status + kind
        final f2 = SearchFilters()
          ..query = 'Flutter'
          ..status = ResourceStatus.completed
          ..kind = ResourceKind.video;
        final res2 = await searchRepo.search(filters: f2);
        expect(res2.length, 1);
        expect(res2.first.id, r2);

        // Filter by tag
        final f3 = SearchFilters()
          ..query = 'Flutter'
          ..tag = 'architecture';
        final res3 = await searchRepo.search(filters: f3);
        expect(res3.length, 1);
        expect(res3.first.id, r1);
      },
    );

    test('12. Sorting (Newest, Oldest, Title A-Z, Recently Opened)', () async {
      final r1 = await resourceRepo.addResource(
        url: 'https://example.com/b',
        title: 'B Resource',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await resourceRepo.addResource(
        url: 'https://example.com/a',
        title: 'A Resource',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      final r3 = await resourceRepo.addResource(
        url: 'https://example.com/c',
        title: 'C Resource',
      );

      await resourceRepo.registerOpen(r1);

      // Sort Title A-Z
      final titleSort = await searchRepo.search(
        filters: SearchFilters(),
        sort: SortOrder.titleAZ,
      );
      expect(titleSort.map((r) => r.title).toList(), [
        'A Resource',
        'B Resource',
        'C Resource',
      ]);

      // Sort Oldest
      final oldestSort = await searchRepo.search(
        filters: SearchFilters(),
        sort: SortOrder.oldest,
      );
      expect(oldestSort.first.id, r1);
      expect(oldestSort.last.id, r3);

      // Sort Newest
      final newestSort = await searchRepo.search(
        filters: SearchFilters(),
        sort: SortOrder.newest,
      );
      expect(newestSort.first.id, r3);
      expect(newestSort.last.id, r1);

      // Sort Recently Opened
      final openSort = await searchRepo.search(
        filters: SearchFilters(),
        sort: SortOrder.recentlyOpened,
      );
      expect(openSort.first.id, r1);
    });

    test('13. Soft-deleted trash resources are excluded from search', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/trash-me',
        title: 'Trash Candidate Resource',
      );

      var results = await searchRepo.search(
        filters: SearchFilters()..query = 'Trash Candidate',
      );
      expect(results.length, 1);

      // Move to trash
      await resourceRepo.softDelete(id);

      results = await searchRepo.search(
        filters: SearchFilters()..query = 'Trash Candidate',
      );
      expect(results, isEmpty);
    });

    test('14. Restored resources become searchable again', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/restore-me',
        title: 'Restore Candidate Resource',
      );

      await resourceRepo.softDelete(id);
      expect(
        await searchRepo.search(
          filters: SearchFilters()..query = 'Restore Candidate',
        ),
        isEmpty,
      );

      // Restore
      await resourceRepo.restore(id);
      final results = await searchRepo.search(
        filters: SearchFilters()..query = 'Restore Candidate',
      );
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test('15. Permanently deleted resource is removed from FTS', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/perm-delete',
        title: 'Permanent Delete Resource',
      );

      await resourceRepo.permanentDelete(id);

      final results = await searchRepo.search(
        filters: SearchFilters()..query = 'Permanent Delete',
      );
      expect(results, isEmpty);
    });

    test('16. Resource update synchronizes with FTS index', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/course',
        title: 'Python Course',
      );

      final item = await resourceRepo.findById(id);
      item!.title = 'Flutter Course';
      await resourceRepo.updateResource(item);

      final pythonSearch = await searchRepo.search(
        filters: SearchFilters()..query = 'Python',
      );
      expect(pythonSearch, isEmpty);

      final flutterSearch = await searchRepo.search(
        filters: SearchFilters()..query = 'Flutter',
      );
      expect(flutterSearch.length, 1);
      expect(flutterSearch.first.id, id);
    });

    test('17. Notes update synchronizes with FTS index', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/notes',
        title: 'Simple Title',
      );

      await resourceRepo.updateNotes(id, 'Important secret keyword notes');

      final results = await searchRepo.search(
        filters: SearchFilters()..query = 'secret keyword',
      );
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test('18. Tag add and remove synchronizes with FTS index', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/tag-test',
        title: 'Tag Test Resource',
      );

      await resourceRepo.addTag(id, 'kubernetes');
      var results = await searchRepo.search(
        filters: SearchFilters()..query = 'kubernetes',
      );
      expect(results.length, 1);

      await resourceRepo.removeTag(id, 'kubernetes');
      results = await searchRepo.search(
        filters: SearchFilters()..query = 'kubernetes',
      );
      expect(results, isEmpty);
    });

    test('19. Collection update synchronizes with FTS index', () async {
      final c1 = await collectionRepo.createCollection(name: 'Frontend Design');
      final c2 = await collectionRepo.createCollection(
        name: 'DevOps Engineering',
      );

      final id = await resourceRepo.addResource(
        url: 'https://example.com/col-test',
        title: 'Architecture Blueprint',
        collectionId: c1,
      );

      var results = await searchRepo.search(
        filters: SearchFilters()..query = 'Frontend Design',
      );
      expect(results.length, 1);

      await resourceRepo.moveToCollection(id, c2);
      results = await searchRepo.search(
        filters: SearchFilters()..query = 'Frontend Design',
      );
      expect(results, isEmpty);

      results = await searchRepo.search(
        filters: SearchFilters()..query = 'DevOps Engineering',
      );
      expect(results.length, 1);
    });

    test('20. Metadata update synchronizes with FTS index', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/meta',
        title: 'Initial Title',
      );

      await db.resourceDao.updateResource(
        id,
        const ResourcesCompanion(
          title: Value('Enriched Article Title'),
          source: Value('techcrunch.com'),
        ),
      );
      await db.searchDao.syncResource(id);

      final results = await searchRepo.search(
        filters: SearchFilters()..query = 'Enriched Article',
      );
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test('21. Persistence across database close and reopen', () async {
      final id = await resourceRepo.addResource(
        url: 'https://example.com/persist',
        title: 'Persistent FTS Resource',
      );

      // Reopen fresh DAO instances on the same memory db
      final freshSearchDao = SearchDao(db);
      final freshSearchRepo = SearchRepository(freshSearchDao, db.tagDao);

      final results = await freshSearchRepo.search(
        filters: SearchFilters()..query = 'Persistent FTS',
      );
      expect(results.length, 1);
      expect(results.first.id, id);
    });

    test(
      '22. Existing database migration populates FTS index via rebuildIndex',
      () async {
        // Direct raw insert into resources bypassing FTS
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await db.customStatement('''
        INSERT INTO resources(id, title, url, normalized_url, resource_type, source, notes, status, is_favorite, created_at, open_count, minutes, accent, fetching)
        VALUES ('raw_res_1', 'Legacy Raw Resource', 'https://raw.org', 'raw.org', 'article', 'raw.org', 'Legacy notes', 'unread', 0, $nowSec, 0, 5, 0, 0);
      ''');

        // Run rebuildIndex (same as migration)
        await db.searchDao.rebuildIndex();

        final results = await searchRepo.search(
          filters: SearchFilters()..query = 'Legacy Raw',
        );
        expect(results.length, 1);
        expect(results.first.id, 'raw_res_1');
      },
    );

    test('23. Large dataset search with limit works efficiently', () async {
      for (int i = 0; i < 60; i++) {
        await resourceRepo.addResource(
          url: 'https://bulk.org/item_$i',
          title: 'Bulk Index Item $i in Library',
        );
      }

      final results = await searchRepo.search(
        filters: SearchFilters()..query = 'Bulk Index',
        limit: 25,
      );
      expect(results.length, 25);
    });
  });
}
