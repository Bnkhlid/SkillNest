import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SavedFileInfo {
  final String fileId;
  final String localPath;
  final String fileName;
  final String mimeType;
  final int fileSize;

  const SavedFileInfo({
    required this.fileId,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });
}

class FileStorageService {
  final String? _customBaseDir;
  static const _uuid = Uuid();

  FileStorageService([this._customBaseDir]);

  /// Returns the base directory for storing files: `<app_doc_dir>/skillnest/files`
  Future<Directory> getStorageDirectory() async {
    final customDir = _customBaseDir;
    if (customDir != null) {
      final dir = Directory(p.join(customDir, 'skillnest', 'files'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocDir.path, 'skillnest', 'files'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies an external or temp file to private app storage under its own file ID directory.
  Future<SavedFileInfo> copyFileToPrivateStorage({
    required String sourcePath,
    required String fileName,
    String? forcedFileId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    final fileId = forcedFileId ?? 'file_${_uuid.v4()}';
    final storageDir = await getStorageDirectory();
    final fileSubDir = Directory(p.join(storageDir.path, fileId));
    if (!await fileSubDir.exists()) {
      await fileSubDir.create(recursive: true);
    }

    final sanitizedName = _sanitizeFileName(fileName.isNotEmpty ? fileName : p.basename(sourcePath));
    final targetPath = p.join(fileSubDir.path, sanitizedName);
    final targetFile = await sourceFile.copy(targetPath);

    final size = await targetFile.length();
    final mime = detectMimeType(sanitizedName);

    return SavedFileInfo(
      fileId: fileId,
      localPath: targetPath,
      fileName: sanitizedName,
      mimeType: mime,
      fileSize: size,
    );
  }

  /// Deletes the physical file and its enclosing fileId folder.
  Future<bool> deletePhysicalFile(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
      final parent = file.parent;
      if (await parent.exists()) {
        try {
          await parent.delete(recursive: true);
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a file physically exists on disk.
  Future<bool> fileExists(String localPath) async {
    try {
      return await File(localPath).exists();
    } catch (_) {
      return false;
    }
  }

  /// Sanitizes file name by removing characters incompatible with filesystems.
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Infers MIME type from file extension with fallback.
  static String detectMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.txt':
        return 'text/plain';
      case '.md':
        return 'text/markdown';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.epub':
        return 'application/epub+zip';
      case '.zip':
        return 'application/zip';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
