import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/collections.dart';

part 'collection_dao.g.dart';

@DriftAccessor(tables: [Collections])
class CollectionDao extends DatabaseAccessor<AppDatabase> with _$CollectionDaoMixin {
  CollectionDao(super.db);

  Stream<List<CollectionEntry>> watchAll() {
    return (select(collections)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .watch();
  }

  Future<List<CollectionEntry>> getAll() {
    return (select(collections)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();
  }

  Future<CollectionEntry?> findById(String id) {
    return (select(collections)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCollection(CollectionsCompanion companion) {
    return into(collections).insert(companion);
  }

  Future<bool> updateCollection(String id, {String? name, String? emoji, int? accent}) {
    return (update(collections)..where((c) => c.id.equals(id))).write(
      CollectionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        emoji: emoji != null ? Value(emoji) : const Value.absent(),
        accent: accent != null ? Value(accent) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    ).then((count) => count > 0);
  }

  Future<int> deleteCollection(String id) {
    return (delete(collections)..where((c) => c.id.equals(id))).go();
  }

  Future<List<CollectionEntry>> getAllCollectionsRaw() {
    return (select(collections)..orderBy([(c) => OrderingTerm.asc(c.createdAt)])).get();
  }

  Future<int> insertRawCollection(CollectionEntry entry) {
    return into(collections).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> deleteAllCollections() {
    return delete(collections).go();
  }
}
