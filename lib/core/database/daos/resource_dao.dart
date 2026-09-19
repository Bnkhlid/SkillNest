import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/collections.dart';
import '../tables/resources.dart';

part 'resource_dao.g.dart';

@DriftAccessor(tables: [Resources, Collections])
class ResourceDao extends DatabaseAccessor<AppDatabase>
    with _$ResourceDaoMixin {
  ResourceDao(super.db);

  Stream<List<ResourceEntry>> watchActiveResources() {
    return (select(resources)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch();
  }

  Future<List<ResourceEntry>> getActiveResources() {
    return (select(resources)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Stream<List<ResourceEntry>> watchTrashResources() {
    return (select(resources)
          ..where((r) => r.deletedAt.isNotNull())
          ..orderBy([(r) => OrderingTerm.desc(r.deletedAt)]))
        .watch();
  }

  Future<List<ResourceEntry>> getTrashResources() {
    return (select(resources)
          ..where((r) => r.deletedAt.isNotNull())
          ..orderBy([(r) => OrderingTerm.desc(r.deletedAt)]))
        .get();
  }

  Stream<List<ResourceEntry>> watchContinueLearning({int limit = 10}) {
    return (select(resources)
          ..where((r) => r.deletedAt.isNull() & r.status.equals('inProgress'))
          ..orderBy([
            (r) => OrderingTerm.desc(r.lastOpenedAt),
            (r) => OrderingTerm.desc(r.updatedAt),
            (r) => OrderingTerm.desc(r.createdAt),
          ])
          ..limit(limit))
        .watch();
  }

  Stream<List<ResourceEntry>> watchRecentSaves({int limit = 10}) {
    return (select(resources)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
          ..limit(limit))
        .watch();
  }

  Stream<List<ResourceEntry>> watchFavorites() {
    return (select(resources)
          ..where((r) => r.deletedAt.isNull() & r.isFavorite.equals(true))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch();
  }

  Stream<List<ResourceEntry>> watchByCollection(String collectionId) {
    return (select(resources)
          ..where(
            (r) => r.deletedAt.isNull() & r.collectionId.equals(collectionId),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch();
  }

  Future<ResourceEntry?> findById(String id) {
    return (select(resources)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  Future<ResourceEntry?> findByNormalizedUrl(String normalizedUrl) {
    return (select(resources)..where(
          (r) => r.normalizedUrl.equals(normalizedUrl) & r.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<int> insertResource(ResourcesCompanion companion) {
    return into(resources).insert(companion);
  }

  Future<bool> updateResource(String id, ResourcesCompanion companion) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())))
        .then((count) => count > 0);
  }

  Future<bool> softDelete(String id) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<bool> restore(String id) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          const ResourcesCompanion(
            deletedAt: Value(null),
          ).copyWith(updatedAt: Value(DateTime.now())),
        )
        .then((count) => count > 0);
  }

  Future<int> permanentDelete(String id) {
    return (delete(resources)..where((r) => r.id.equals(id))).go();
  }

  Future<int> emptyTrash() {
    return (delete(resources)..where((r) => r.deletedAt.isNotNull())).go();
  }

  Future<bool> toggleFavorite(String id, bool isFavorite) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            isFavorite: Value(isFavorite),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<bool> setStatus(String id, String status) {
    final isCompleted = status == 'completed';
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            status: Value(status),
            completedAt: isCompleted
                ? Value(DateTime.now())
                : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<bool> updateNotes(String id, String notes, {String? noteTitle}) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            notes: Value(notes),
            noteTitle: noteTitle == null
                ? const Value.absent()
                : Value(noteTitle),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<bool> moveToCollection(String id, String? collectionId) {
    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            collectionId: Value(collectionId),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<bool> registerOpen(String id) async {
    final current = await findById(id);
    if (current == null) return false;

    final newCount = current.openCount + 1;
    final newStatus = (current.status == 'unread')
        ? 'inProgress'
        : current.status;

    return (update(resources)..where((r) => r.id.equals(id)))
        .write(
          ResourcesCompanion(
            openCount: Value(newCount),
            lastOpenedAt: Value(DateTime.now()),
            status: Value(newStatus),
            updatedAt: Value(DateTime.now()),
          ),
        )
        .then((count) => count > 0);
  }

  Future<List<ResourceEntry>> getAllResources() {
    return (select(
      resources,
    )..orderBy([(r) => OrderingTerm.asc(r.createdAt)])).get();
  }

  Future<int> insertRawResource(ResourceEntry entry) {
    return into(resources).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> deleteAllResources() {
    return delete(resources).go();
  }
}
