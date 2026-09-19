import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/file_dao.dart';
import '../../../core/database/daos/resource_dao.dart';
import '../../../core/database/daos/search_dao.dart';
import '../../../core/database/daos/tag_dao.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/utils/url_normalizer.dart';
import '../../../models.dart';

class ResourceRepository {
  final ResourceDao _resourceDao;
  final TagDao _tagDao;
  final SearchDao? _searchDao;
  final FileDao? _fileDao;
  final FileStorageService? _storageService;
  static const _uuid = Uuid();

  ResourceRepository(
    this._resourceDao,
    this._tagDao, [
    this._searchDao,
    this._fileDao,
    this._storageService,
  ]);

  ResourceItem _mapToModel(
    ResourceEntry entry, [
    Set<String>? tags,
    FileItem? file,
  ]) {
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
      noteTitle: entry.noteTitle,
      note: entry.notes,
      fetching: entry.fetching,
      accent: entry.accent,
      localFile: file,
    );
  }

  Future<FileItem?> _getFileForResource(String resourceId) async {
    if (_fileDao == null) return null;
    final entry = await _fileDao.getFileForResource(resourceId);
    if (entry == null) return null;
    return FileItem(
      id: entry.id,
      resourceId: entry.resourceId,
      localPath: entry.localPath,
      fileName: entry.fileName,
      mimeType: entry.mimeType,
      fileSize: entry.fileSize,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  Stream<List<ResourceItem>> watchAll() {
    return _resourceDao.watchActiveResources().asyncMap((entries) async {
      final items = <ResourceItem>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        final file = await _getFileForResource(entry.id);
        items.add(_mapToModel(entry, tags, file));
      }
      return items;
    });
  }

  Stream<List<ResourceItem>> watchRecent({int limit = 10}) {
    return _resourceDao.watchRecentSaves(limit: limit).asyncMap((
      entries,
    ) async {
      final items = <ResourceItem>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        final file = await _getFileForResource(entry.id);
        items.add(_mapToModel(entry, tags, file));
      }
      return items;
    });
  }

  Stream<List<ResourceItem>> watchContinueLearning({int limit = 10}) {
    return _resourceDao.watchContinueLearning(limit: limit).asyncMap((
      entries,
    ) async {
      final items = <ResourceItem>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        items.add(_mapToModel(entry, tags));
      }
      return items;
    });
  }

  Stream<List<ResourceItem>> watchFavorites() {
    return _resourceDao.watchFavorites().asyncMap((entries) async {
      final items = <ResourceItem>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        items.add(_mapToModel(entry, tags));
      }
      return items;
    });
  }

  Stream<List<ResourceItem>> watchByCollection(String collectionId) {
    return _resourceDao.watchByCollection(collectionId).asyncMap((
      entries,
    ) async {
      final items = <ResourceItem>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        items.add(_mapToModel(entry, tags));
      }
      return items;
    });
  }

  Stream<List<TrashEntry>> watchTrash() {
    return _resourceDao.watchTrashResources().asyncMap((entries) async {
      final items = <TrashEntry>[];
      for (final entry in entries) {
        final tags = await _tagDao.getTagsForResource(entry.id);
        items.add(
          TrashEntry(
            item: _mapToModel(entry, tags),
            deletedAt: entry.deletedAt ?? DateTime.now(),
          ),
        );
      }
      return items;
    });
  }

  Stream<Set<String>> watchAllTags() {
    return _tagDao.watchAllTags();
  }

  Future<ResourceItem?> findById(String id) async {
    final entry = await _resourceDao.findById(id);
    if (entry == null) return null;
    final tags = await _tagDao.getTagsForResource(id);
    final file = await _getFileForResource(id);
    return _mapToModel(entry, tags, file);
  }

  Future<ResourceItem?> findByUrl(String url) async {
    final normalized = UrlNormalizer.normalize(url);
    final entry = await _resourceDao.findByNormalizedUrl(normalized);
    if (entry == null) return null;
    final tags = await _tagDao.getTagsForResource(entry.id);
    final file = await _getFileForResource(entry.id);
    return _mapToModel(entry, tags, file);
  }

  Future<String> addResource({
    required String url,
    String? title,
    String? source,
    ResourceKind kind = ResourceKind.article,
    String? collectionId,
    Set<String>? tags,
    String? note,
    int minutes = 6,
    int accent = 0,
    bool favorite = false,
  }) async {
    final id = 'res_${_uuid.v4()}';
    final normalized = UrlNormalizer.normalize(url);
    final domain = (source != null && source.isNotEmpty)
        ? source
        : UrlNormalizer.extractDomain(url);
    final displayTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : (domain.isNotEmpty ? domain : 'Untitled Resource');

    await _resourceDao.insertResource(
      ResourcesCompanion(
        id: Value(id),
        title: Value(displayTitle),
        url: Value(url.trim()),
        normalizedUrl: Value(normalized),
        resourceType: Value(kind.name),
        source: Value(domain),
        collectionId: Value(collectionId),
        notes: Value(note ?? ''),
        minutes: Value(minutes),
        accent: Value(accent),
        isFavorite: Value(favorite),
        status: const Value('unread'),
        createdAt: Value(DateTime.now()),
      ),
    );

    if (tags != null && tags.isNotEmpty) {
      await _tagDao.setTagsForResource(id, tags);
    }

    if (_searchDao != null) {
      await _searchDao.syncResource(id);
    }

    return id;
  }

  Future<bool> updateResource(ResourceItem item) async {
    final normalized = UrlNormalizer.normalize(item.url);
    final updated = await _resourceDao.updateResource(
      item.id,
      ResourcesCompanion(
        title: Value(item.title),
        url: Value(item.url),
        normalizedUrl: Value(normalized),
        resourceType: Value(item.kind.name),
        source: Value(item.source),
        collectionId: Value(item.collectionId),
        notes: Value(item.note),
        status: Value(item.status.name),
        isFavorite: Value(item.favorite),
        minutes: Value(item.minutes),
        accent: Value(item.accent),
      ),
    );

    await _tagDao.setTagsForResource(item.id, item.tags);
    if (_searchDao != null) {
      await _searchDao.syncResource(item.id);
    }
    return updated;
  }

  Future<bool> softDelete(String id) {
    return _resourceDao.softDelete(id);
  }

  Future<bool> restore(String id) {
    return _resourceDao.restore(id);
  }

  Future<int> permanentDelete(String id) async {
    if (_fileDao != null && _storageService != null) {
      final fileEntry = await _fileDao.getFileForResource(id);
      if (fileEntry != null) {
        await _storageService.deletePhysicalFile(fileEntry.localPath);
        await _fileDao.deleteFilesForResource(id);
      }
    }

    final count = await _resourceDao.permanentDelete(id);
    if (_searchDao != null) {
      await _searchDao.deleteFromIndex(id);
    }
    return count;
  }

  Future<int> emptyTrash() async {
    if (_fileDao != null && _storageService != null) {
      final trashList = await _resourceDao.getTrashResources();
      for (final r in trashList) {
        final fileEntry = await _fileDao.getFileForResource(r.id);
        if (fileEntry != null) {
          await _storageService.deletePhysicalFile(fileEntry.localPath);
          await _fileDao.deleteFilesForResource(r.id);
        }
      }
    }

    final count = await _resourceDao.emptyTrash();
    if (_searchDao != null) {
      await _searchDao.rebuildIndex();
    }
    return count;
  }

  Future<bool> toggleFavorite(String id, bool isFavorite) {
    return _resourceDao.toggleFavorite(id, isFavorite);
  }

  Future<bool> setStatus(String id, ResourceStatus status) {
    return _resourceDao.setStatus(id, status.name);
  }

  Future<bool> updateNotes(String id, String notes, {String? noteTitle}) async {
    final res = await _resourceDao.updateNotes(id, notes, noteTitle: noteTitle);
    if (_searchDao != null) {
      await _searchDao.syncResource(id);
    }
    return res;
  }

  Future<bool> moveToCollection(String id, String? collectionId) async {
    final res = await _resourceDao.moveToCollection(id, collectionId);
    if (_searchDao != null) {
      await _searchDao.syncResource(id);
    }
    return res;
  }

  Future<bool> registerOpen(String id) {
    return _resourceDao.registerOpen(id);
  }

  Future<void> addTag(String resourceId, String tag) async {
    await _tagDao.addTagToResource(resourceId, tag);
    if (_searchDao != null) {
      await _searchDao.syncResource(resourceId);
    }
  }

  Future<void> removeTag(String resourceId, String tag) async {
    await _tagDao.removeTagFromResource(resourceId, tag);
    if (_searchDao != null) {
      await _searchDao.syncResource(resourceId);
    }
  }
}
