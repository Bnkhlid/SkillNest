import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/collection_dao.dart';
import '../../../models.dart';

class CollectionRepository {
  final CollectionDao _collectionDao;
  static const _uuid = Uuid();

  CollectionRepository(this._collectionDao);

  CollectionModel _mapToModel(CollectionEntry entry) {
    return CollectionModel(
      id: entry.id,
      name: entry.name,
      emoji: entry.emoji,
      accent: entry.accent,
      createdAt: entry.createdAt,
    );
  }

  Stream<List<CollectionModel>> watchCollections() {
    return _collectionDao.watchAll().map(
      (entries) => entries.map(_mapToModel).toList(),
    );
  }

  Future<List<CollectionModel>> getCollections() async {
    final entries = await _collectionDao.getAll();
    return entries.map(_mapToModel).toList();
  }

  Future<CollectionModel?> getCollectionById(String id) async {
    final entry = await _collectionDao.findById(id);
    return entry != null ? _mapToModel(entry) : null;
  }

  Future<String> createCollection({
    required String name,
    String emoji = '📚',
    int accent = 0,
  }) async {
    final id = 'col_${_uuid.v4()}';
    await _collectionDao.insertCollection(
      CollectionsCompanion(
        id: Value(id),
        name: Value(name),
        emoji: Value(emoji),
        accent: Value(accent),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  Future<bool> updateCollection({
    required String id,
    String? name,
    String? emoji,
    int? accent,
  }) {
    return _collectionDao.updateCollection(
      id,
      name: name,
      emoji: emoji,
      accent: accent,
    );
  }

  Future<int> deleteCollection(String id) {
    return _collectionDao.deleteCollection(id);
  }
}
