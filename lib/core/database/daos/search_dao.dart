import 'package:drift/drift.dart';

import '../../../models.dart';
import '../app_database.dart';
import '../tables/collections.dart';
import '../tables/files.dart';
import '../tables/resource_tags.dart';
import '../tables/resources.dart';
import '../tables/tags.dart';

part 'search_dao.g.dart';

@DriftAccessor(tables: [Resources, Collections, Tags, ResourceTags, Files])
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.db);

  static const String ftsTableName = 'resource_fts';

  /// Creates the FTS5 virtual table if it doesn't already exist.
  Future<void> createFtsTable() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTableName USING fts5(
        resource_id UNINDEXED,
        title,
        description,
        notes,
        tags,
        collection,
        source,
        tokenize='unicode61'
      );
    ''');
  }

  /// Synchronizes a single resource's data into the FTS index.
  Future<void> syncResource(String resourceId) async {
    await createFtsTable();
    // 1. Fetch resource
    final resource = await (select(
      resources,
    )..where((r) => r.id.equals(resourceId))).getSingleOrNull();
    if (resource == null) {
      await deleteFromIndex(resourceId);
      return;
    }

    // 2. Fetch collection name
    String collectionName = '';
    if (resource.collectionId != null) {
      final col = await (select(
        collections,
      )..where((c) => c.id.equals(resource.collectionId!))).getSingleOrNull();
      if (col != null) {
        collectionName = col.name;
      }
    }

    // 3. Fetch tags
    final tagQuery = select(resourceTags).join([
      innerJoin(tags, tags.id.equalsExp(resourceTags.tagId)),
    ])..where(resourceTags.resourceId.equals(resourceId));
    final tagRows = await tagQuery.get();
    final tagNames = tagRows.map((r) => r.readTable(tags).name).join(' ');

    // 4. Fetch attached file name if any
    final fileEntry = await (select(
      files,
    )..where((f) => f.resourceId.equals(resourceId))).getSingleOrNull();
    final fileName = fileEntry?.fileName ?? '';
    final searchDescription = [
      resource.source,
      if (resource.description != null && resource.description!.isNotEmpty)
        resource.description!,
      if (fileName.isNotEmpty) fileName,
    ].join(' ');

    // 5. Delete old index entry & Insert updated entry
    await deleteFromIndex(resourceId);
    await customStatement(
      '''
      INSERT INTO $ftsTableName(resource_id, title, description, notes, tags, collection, source)
      VALUES (?, ?, ?, ?, ?, ?, ?);
    ''',
      [
        resourceId,
        resource.title,
        searchDescription,
        [
          resource.noteTitle,
          resource.notes,
        ].where((text) => text.isNotEmpty).join(' '),
        tagNames,
        collectionName,
        resource.source,
      ],
    );
  }

  /// Synchronizes all resources in a collection when the collection name changes.
  Future<void> syncCollectionResources(String collectionId) async {
    final list = await (select(
      resources,
    )..where((r) => r.collectionId.equals(collectionId))).get();
    for (final r in list) {
      await syncResource(r.id);
    }
  }

  /// Removes an entry from the FTS index.
  Future<void> deleteFromIndex(String resourceId) async {
    await createFtsTable();
    await customStatement('DELETE FROM $ftsTableName WHERE resource_id = ?;', [
      resourceId,
    ]);
  }

  /// Completely rebuilds the FTS index from existing database records.
  Future<void> rebuildIndex() async {
    await createFtsTable();
    await customStatement('DELETE FROM $ftsTableName;');
    final allResources = await select(resources).get();
    for (final r in allResources) {
      await syncResource(r.id);
    }
  }

  /// Performs FTS5 + SQL filtered search returning matching ResourceEntry objects.
  Future<List<ResourceEntry>> searchResources({
    required SearchFilters filters,
    SortOrder sort = SortOrder.newest,
    int limit = 50,
  }) async {
    await createFtsTable();
    final sanitizedQuery = sanitizeFtsQuery(filters.query);
    final isFts = sanitizedQuery.isNotEmpty;

    final whereClauses = <String>['r.deleted_at IS NULL'];
    final variables = <Variable>[];

    if (isFts) {
      whereClauses.add('$ftsTableName MATCH ?');
      variables.add(Variable.withString(sanitizedQuery));
    }

    if (filters.status != null) {
      whereClauses.add('r.status = ?');
      variables.add(Variable.withString(filters.status!.name));
    }

    if (filters.kind != null) {
      whereClauses.add('r.resource_type = ?');
      variables.add(Variable.withString(filters.kind!.name));
    }

    if (filters.collectionId != null) {
      whereClauses.add('r.collection_id = ?');
      variables.add(Variable.withString(filters.collectionId!));
    }

    if (filters.favoritesOnly) {
      whereClauses.add('r.is_favorite = 1');
    }

    if (filters.tag != null && filters.tag!.trim().isNotEmpty) {
      whereClauses.add('''
        EXISTS (
          SELECT 1 FROM resource_tags rt
          JOIN tags t ON t.id = rt.tag_id
          WHERE rt.resource_id = r.id AND t.name = ?
        )
      ''');
      variables.add(Variable.withString(filters.tag!.trim().toLowerCase()));
    }

    String orderByClause;
    switch (sort) {
      case SortOrder.newest:
        orderByClause = isFts
            ? 'ORDER BY bm25($ftsTableName) ASC, r.created_at DESC, r.rowid DESC'
            : 'ORDER BY r.created_at DESC, r.rowid DESC';
      case SortOrder.oldest:
        orderByClause = 'ORDER BY r.created_at ASC, r.rowid ASC';
      case SortOrder.titleAZ:
        orderByClause = 'ORDER BY LOWER(r.title) ASC';
      case SortOrder.recentlyOpened:
        orderByClause =
            'ORDER BY COALESCE(r.last_opened_at, 0) DESC, r.created_at DESC, r.rowid DESC';
    }

    final fromClause = isFts
        ? 'FROM $ftsTableName fts JOIN resources r ON r.id = fts.resource_id'
        : 'FROM resources r';

    final sql =
        '''
      SELECT r.* $fromClause
      WHERE ${whereClauses.join(' AND ')}
      $orderByClause
      LIMIT $limit;
    ''';

    final rows = await customSelect(sql, variables: variables).get();
    return rows.map((row) => resources.map(row.data)).toList();
  }

  /// Sanitizes raw user search input into valid FTS5 MATCH query.
  static String sanitizeFtsQuery(String raw) {
    var query = raw.trim();
    if (query.isEmpty) return '';

    // Remove quotes and special FTS punctuation: * ^ : { } ( ) " ' + -
    query = query.replaceAll(RegExp(r'''[*\^:{}()"'+-]'''), ' ');

    final tokens = query
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return '';

    // Format each token as prefix search: "token"*
    return tokens.map((t) => '"$t"*').join(' ');
  }
}
