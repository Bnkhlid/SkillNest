import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/collections/data/collection_repository.dart';
import '../../features/notes/data/sticky_note_repository.dart';
import '../../features/resources/data/file_repository.dart';
import '../../features/resources/data/resource_repository.dart';
import '../../features/search/data/search_repository.dart';
import '../../models.dart';
import '../database/app_database.dart';
import '../database/daos/collection_dao.dart';
import '../database/daos/file_dao.dart';
import '../database/daos/resource_dao.dart';
import '../database/daos/search_dao.dart';
import '../database/daos/sticky_note_dao.dart';
import '../database/daos/tag_dao.dart';
import '../database/daos/analytics_event_dao.dart';
import '../repositories/analytics_repository.dart';
import '../services/analytics_service.dart';
import '../services/backup_service.dart';
import '../services/file_storage_service.dart';
import '../services/notification_service.dart';
import '../services/restore_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final collectionDaoProvider = Provider<CollectionDao>((ref) {
  return ref.watch(databaseProvider).collectionDao;
});

final resourceDaoProvider = Provider<ResourceDao>((ref) {
  return ref.watch(databaseProvider).resourceDao;
});

final tagDaoProvider = Provider<TagDao>((ref) {
  return ref.watch(databaseProvider).tagDao;
});

final fileDaoProvider = Provider<FileDao>((ref) {
  return ref.watch(databaseProvider).fileDao;
});

final stickyNoteDaoProvider = Provider<StickyNoteDao>((ref) {
  return ref.watch(databaseProvider).stickyNoteDao;
});

final searchDaoProvider = Provider<SearchDao>((ref) {
  return ref.watch(databaseProvider).searchDao;
});

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepository(
    ref.watch(fileDaoProvider),
    ref.watch(fileStorageServiceProvider),
    ref.watch(searchDaoProvider),
  );
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(ref.watch(collectionDaoProvider));
});

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(
    ref.watch(resourceDaoProvider),
    ref.watch(tagDaoProvider),
    ref.watch(searchDaoProvider),
    ref.watch(fileDaoProvider),
    ref.watch(fileStorageServiceProvider),
  );
});

final stickyNoteRepositoryProvider = Provider<StickyNoteRepository>((ref) {
  return StickyNoteRepository(ref.watch(stickyNoteDaoProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    ref.watch(searchDaoProvider),
    ref.watch(tagDaoProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(fileStorageServiceProvider),
  );
});

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(
    ref.watch(databaseProvider),
    ref.watch(fileStorageServiceProvider),
  );
});

final analyticsEventDaoProvider = Provider<AnalyticsEventDao>((ref) {
  return ref.watch(databaseProvider).analyticsEventDao;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(analyticsEventDaoProvider));
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    ref.watch(analyticsEventDaoProvider),
    ref.watch(resourceDaoProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

// Stream Providers for reactive UI
final allResourcesProvider = StreamProvider<List<ResourceItem>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchAll();
});

final recentSavesProvider = StreamProvider<List<ResourceItem>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchRecent();
});

final continueLearningProvider = StreamProvider<List<ResourceItem>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchContinueLearning();
});

final favoritesProvider = StreamProvider<List<ResourceItem>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchFavorites();
});

final collectionsProvider = StreamProvider<List<CollectionModel>>((ref) {
  return ref.watch(collectionRepositoryProvider).watchCollections();
});

final trashProvider = StreamProvider<List<TrashEntry>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchTrash();
});

final allTagsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchAllTags();
});

final stickyNotesProvider = StreamProvider<List<StickyNoteModel>>((ref) {
  return ref.watch(stickyNoteRepositoryProvider).watchNotes();
});

final collectionResourcesProvider =
    StreamProvider.family<List<ResourceItem>, String>((ref, collectionId) {
  return ref.watch(resourceRepositoryProvider).watchByCollection(collectionId);
});

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<ResourceItem>, ({SearchFilters filters, SortOrder sort})>((ref, args) {
  return ref.watch(searchRepositoryProvider).search(
        filters: args.filters,
        sort: args.sort,
      );
});

