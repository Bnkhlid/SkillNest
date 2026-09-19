import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/resource_tags.dart';
import '../tables/tags.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, ResourceTags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  static const _uuid = Uuid();

  Future<TagEntry> getOrCreateTag(String rawName) async {
    final clean = rawName.trim().toLowerCase();
    final existing = await (select(tags)..where((t) => t.name.equals(clean))).getSingleOrNull();
    if (existing != null) return existing;

    final id = 'tag_${_uuid.v4()}';
    final entry = TagEntry(id: id, name: clean);
    await into(tags).insert(entry);
    return entry;
  }

  Future<Set<String>> getTagsForResource(String resourceId) async {
    final query = select(resourceTags).join([
      innerJoin(tags, tags.id.equalsExp(resourceTags.tagId)),
    ])..where(resourceTags.resourceId.equals(resourceId));

    final rows = await query.get();
    return rows.map((r) => r.readTable(tags).name).toSet();
  }

  Stream<Map<String, Set<String>>> watchAllResourceTags() {
    final query = select(resourceTags).join([
      innerJoin(tags, tags.id.equalsExp(resourceTags.tagId)),
    ]);

    return query.watch().map((rows) {
      final map = <String, Set<String>>{};
      for (final r in rows) {
        final resId = r.readTable(resourceTags).resourceId;
        final tagName = r.readTable(tags).name;
        map.putIfAbsent(resId, () => <String>{}).add(tagName);
      }
      return map;
    });
  }

  Stream<Set<String>> watchAllTags() {
    return select(tags).watch().map((list) => list.map((t) => t.name).toSet());
  }

  Future<void> setTagsForResource(String resourceId, Set<String> tagNames) async {
    // Remove existing relations
    await (delete(resourceTags)..where((rt) => rt.resourceId.equals(resourceId))).go();

    for (final name in tagNames) {
      final tag = await getOrCreateTag(name);
      await into(resourceTags).insert(
        ResourceTagEntry(resourceId: resourceId, tagId: tag.id),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> addTagToResource(String resourceId, String tagName) async {
    final tag = await getOrCreateTag(tagName);
    await into(resourceTags).insert(
      ResourceTagEntry(resourceId: resourceId, tagId: tag.id),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeTagFromResource(String resourceId, String tagName) async {
    final clean = tagName.trim().toLowerCase();
    final tag = await (select(tags)..where((t) => t.name.equals(clean))).getSingleOrNull();
    if (tag == null) return;

    await (delete(resourceTags)
          ..where((rt) => rt.resourceId.equals(resourceId) & rt.tagId.equals(tag.id)))
        .go();
  }

  Future<List<TagEntry>> getAllTagsRaw() {
    return select(tags).get();
  }

  Future<List<ResourceTagEntry>> getAllResourceTagsRaw() {
    return select(resourceTags).get();
  }

  Future<int> insertRawTag(TagEntry entry) {
    return into(tags).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> insertRawResourceTag(ResourceTagEntry entry) {
    return into(resourceTags).insert(entry, mode: InsertMode.insertOrIgnore);
  }

  Future<int> deleteAllResourceTags() {
    return delete(resourceTags).go();
  }

  Future<int> deleteAllTags() {
    return delete(tags).go();
  }
}
