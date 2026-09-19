import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/files.dart';

part 'file_dao.g.dart';

@DriftAccessor(tables: [Files])
class FileDao extends DatabaseAccessor<AppDatabase> with _$FileDaoMixin {
  FileDao(super.db);

  Future<FileEntry?> getFileForResource(String resourceId) {
    return (select(files)..where((f) => f.resourceId.equals(resourceId)))
        .getSingleOrNull();
  }

  Stream<FileEntry?> watchFileForResource(String resourceId) {
    return (select(files)..where((f) => f.resourceId.equals(resourceId)))
        .watchSingleOrNull();
  }

  Future<FileEntry?> getFileById(String fileId) {
    return (select(files)..where((f) => f.id.equals(fileId)))
        .getSingleOrNull();
  }

  Future<int> insertFile(FilesCompanion entry) {
    return into(files).insert(entry);
  }

  Future<bool> updateFile(String id, FilesCompanion entry) {
    return (update(files)..where((f) => f.id.equals(id)))
        .write(entry.copyWith(updatedAt: Value(DateTime.now())))
        .then((count) => count > 0);
  }

  Future<int> deleteFile(String id) {
    return (delete(files)..where((f) => f.id.equals(id))).go();
  }

  Future<int> deleteFilesForResource(String resourceId) {
    return (delete(files)..where((f) => f.resourceId.equals(resourceId))).go();
  }

  Future<List<FileEntry>> getFilesForResourceIds(List<String> resourceIds) {
    if (resourceIds.isEmpty) return Future.value([]);
    return (select(files)..where((f) => f.resourceId.isIn(resourceIds))).get();
  }

  Future<List<FileEntry>> getAllFiles() {
    return select(files).get();
  }

  Future<int> insertRawFile(FileEntry entry) {
    return into(files).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> deleteAllFiles() {
    return delete(files).go();
  }
}
