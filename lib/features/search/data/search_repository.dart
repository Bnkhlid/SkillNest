import '../../../core/database/app_database.dart';
import '../../../core/database/daos/search_dao.dart';
import '../../../core/database/daos/tag_dao.dart';
import '../../../models.dart';

class SearchRepository {
  final SearchDao _searchDao;
  final TagDao _tagDao;

  SearchRepository(this._searchDao, this._tagDao);

  ResourceItem _mapToModel(ResourceEntry entry, [Set<String>? tags]) {
    final kind = ResourceKind.values.firstWhere(
      (k) => k.name == entry.resourceType,
      orElse: () => ResourceKind.article,
    );
    final status = ResourceStatus.values.firstWhere(
      (s) => s.name == entry.status,
      orElse: () => ResourceStatus.unread,
    );

    return ResourceItem(
      id: entry.id,
      title: entry.title,
      source: entry.source,
      url: entry.url,
      kind: kind,
      status: status,
      favorite: entry.isFavorite,
      collectionId: entry.collectionId,
      tags: tags ?? {},
      addedAt: entry.createdAt,
      lastOpenedAt: entry.lastOpenedAt,
      openCount: entry.openCount,
      minutes: entry.minutes,
      note: entry.notes,
      fetching: entry.fetching,
      accent: entry.accent,
    );
  }

  /// Searches resources in SQLite using FTS5 match and relational filters.
  Future<List<ResourceItem>> search({
    required SearchFilters filters,
    SortOrder sort = SortOrder.newest,
    int limit = 50,
  }) async {
    final entries = await _searchDao.searchResources(
      filters: filters,
      sort: sort,
      limit: limit,
    );

    final items = <ResourceItem>[];
    for (final entry in entries) {
      final tags = await _tagDao.getTagsForResource(entry.id);
      items.add(_mapToModel(entry, tags));
    }
    return items;
  }

  /// Synchronizes a resource with the FTS5 search index.
  Future<void> syncResource(String resourceId) {
    return _searchDao.syncResource(resourceId);
  }

  /// Synchronizes all resources in a collection.
  Future<void> syncCollectionResources(String collectionId) {
    return _searchDao.syncCollectionResources(collectionId);
  }

  /// Removes an entry from the FTS5 search index.
  Future<void> deleteFromIndex(String resourceId) {
    return _searchDao.deleteFromIndex(resourceId);
  }

  /// Rebuilds the FTS5 search index completely.
  Future<void> rebuildIndex() {
    return _searchDao.rebuildIndex();
  }
}
