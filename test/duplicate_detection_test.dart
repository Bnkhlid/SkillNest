import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/database/app_database.dart';
import 'package:learning_vault/features/resources/data/resource_repository.dart';

void main() {
  late AppDatabase db;
  late ResourceRepository resourceRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    resourceRepo = ResourceRepository(db.resourceDao, db.tagDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Duplicate Detection with Canonical URLs', () {
    test('detects duplicate URLs even with differing query params or casing', () async {
      await resourceRepo.addResource(
        url: 'https://medium.com/better-programming/clean-architecture-in-flutter?utm_source=feed&ref=newsletter',
        title: 'Clean Architecture in Flutter',
      );

      // Search with raw clean URL
      final duplicate1 = await resourceRepo.findByUrl('https://medium.com/better-programming/clean-architecture-in-flutter');
      expect(duplicate1, isNotNull);
      expect(duplicate1!.title, 'Clean Architecture in Flutter');

      // Search with different UTM query params and uppercase scheme
      final duplicate2 = await resourceRepo.findByUrl('HTTPS://MEDIUM.COM/better-programming/clean-architecture-in-flutter?fbclid=987654');
      expect(duplicate2, isNotNull);
      expect(duplicate2!.id, duplicate1.id);
    });

    test('returns null for unique non-duplicate URLs', () async {
      await resourceRepo.addResource(
        url: 'https://example.com/first-article',
        title: 'First Article',
      );

      final unique = await resourceRepo.findByUrl('https://example.com/second-article');
      expect(unique, isNull);
    });
  });
}
