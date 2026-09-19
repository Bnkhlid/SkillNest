import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/file_dao.dart';
import '../../../core/database/daos/search_dao.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../models.dart';

class FileRepository {
  final FileDao _fileDao;
  final FileStorageService _storageService;
  final SearchDao? _searchDao;

  FileRepository(this._fileDao, this._storageService, [this._searchDao]);

  FileItem _mapEntry(FileEntry entry) {
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

  Future<FileItem?> getFileForResource(String resourceId) async {
    final entry = await _fileDao.getFileForResource(resourceId);
    return entry != null ? _mapEntry(entry) : null;
  }

  Stream<FileItem?> watchFileForResource(String resourceId) {
    return _fileDao.watchFileForResource(resourceId).map(
          (entry) => entry != null ? _mapEntry(entry) : null,
        );
  }

  Future<FileItem> saveAndAttachFile({
    required String resourceId,
    required String sourcePath,
    required String fileName,
    String? forcedFileId,
  }) async {
    final savedInfo = await _storageService.copyFileToPrivateStorage(
      sourcePath: sourcePath,
      fileName: fileName,
      forcedFileId: forcedFileId,
    );

    try {
      await _fileDao.insertFile(
        FilesCompanion(
          id: Value(savedInfo.fileId),
          resourceId: Value(resourceId),
          localPath: Value(savedInfo.localPath),
          fileName: Value(savedInfo.fileName),
          mimeType: Value(savedInfo.mimeType),
          fileSize: Value(savedInfo.fileSize),
          createdAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      // Clean up orphaned file on DB error
      await _storageService.deletePhysicalFile(savedInfo.localPath);
      rethrow;
    }

    if (_searchDao != null) {
      await _searchDao.syncResource(resourceId);
    }

    return FileItem(
      id: savedInfo.fileId,
      resourceId: resourceId,
      localPath: savedInfo.localPath,
      fileName: savedInfo.fileName,
      mimeType: savedInfo.mimeType,
      fileSize: savedInfo.fileSize,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> deleteFile(String fileId) async {
    final entry = await _fileDao.getFileById(fileId);
    if (entry == null) return false;

    await _storageService.deletePhysicalFile(entry.localPath);
    final count = await _fileDao.deleteFile(fileId);
    if (_searchDao != null) {
      await _searchDao.syncResource(entry.resourceId);
    }
    return count > 0;
  }

  Future<void> deleteFilesForResource(String resourceId) async {
    final entry = await _fileDao.getFileForResource(resourceId);
    if (entry != null) {
      await _storageService.deletePhysicalFile(entry.localPath);
      await _fileDao.deleteFilesForResource(resourceId);
    }
  }

  Future<bool> fileExistsOnDisk(String localPath) {
    return _storageService.fileExists(localPath);
  }
}
