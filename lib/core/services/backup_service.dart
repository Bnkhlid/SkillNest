import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'file_storage_service.dart';

class BackupResult {
  final String filePath;
  final int byteSize;
  final int resourceCount;
  final int collectionCount;
  final int tagCount;
  final int resourceTagCount;
  final int stickyNoteCount;
  final int stickyItemCount;
  final int fileCount;
  final int analyticsEventCount;
  final DateTime createdAt;

  const BackupResult({
    required this.filePath,
    required this.byteSize,
    required this.resourceCount,
    required this.collectionCount,
    required this.tagCount,
    this.resourceTagCount = 0,
    required this.stickyNoteCount,
    required this.stickyItemCount,
    required this.fileCount,
    this.analyticsEventCount = 0,
    required this.createdAt,
  });
}

class BackupService {
  final AppDatabase _db;
  final FileStorageService _fileStorageService;

  BackupService(this._db, this._fileStorageService);

  /// Computes the SHA-256 checksum for given bytes.
  static String calculateSha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Sanitizes a filename to prevent path traversal and unsafe characters.
  static String sanitizeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00]'), '_');
    return clean.isEmpty ? 'file.bin' : clean;
  }

  /// Helper to create a backup file with simple progress string callback.
  Future<File> createBackup({
    String? outputPath,
    void Function(String status)? onProgress,
  }) async {
    final result = await exportBackup(
      customOutputDir: outputPath != null ? p.dirname(outputPath) : null,
      customFileName: outputPath != null ? p.basename(outputPath) : null,
      onProgress: onProgress != null ? (status, _) => onProgress(status) : null,
    );
    return File(result.filePath);
  }

  /// Exports all data and physical files to a .zip archive.
  Future<BackupResult> exportBackup({
    String? customOutputDir,
    String? customFileName,
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('Preparing...', 0.05);

    final now = DateTime.now();

    // 1. Fetch database records
    onProgress?.call('Exporting database...', 0.20);
    final collections = await _db.collectionDao.getAllCollectionsRaw();
    final tags = await _db.tagDao.getAllTagsRaw();
    final resources = await _db.resourceDao.getAllResources();
    final resourceTags = await _db.tagDao.getAllResourceTagsRaw();
    final stickyNotes = await _db.stickyNoteDao.getAllNotesRaw();
    final stickyItems = await _db.stickyNoteDao.getAllItemsRaw();
    final files = await _db.fileDao.getAllFiles();
    final analyticsEvents = await _db.analyticsEventDao.getAllEventsRaw();

    // Deterministic sorting
    collections.sort((a, b) => a.id.compareTo(b.id));
    tags.sort((a, b) => a.id.compareTo(b.id));
    resources.sort((a, b) => a.id.compareTo(b.id));
    resourceTags.sort(
      (a, b) =>
          '${a.resourceId}_${a.tagId}'.compareTo('${b.resourceId}_${b.tagId}'),
    );
    stickyNotes.sort((a, b) => a.id.compareTo(b.id));
    stickyItems.sort((a, b) => a.id.compareTo(b.id));
    files.sort((a, b) => a.id.compareTo(b.id));
    analyticsEvents.sort((a, b) => a.id.compareTo(b.id));

    // 2. Build database.json
    final serializedResourceTags = resourceTags
        .map((rt) => {'resourceId': rt.resourceId, 'tagId': rt.tagId})
        .toList();

    final serializedStickyNotes = stickyNotes
        .map(
          (sn) => {
            'id': sn.id,
            'title': sn.title,
            'colorValue': sn.colorValue,
            'createdAt': sn.createdAt.toIso8601String(),
            'updatedAt': sn.updatedAt?.toIso8601String(),
          },
        )
        .toList();

    final serializedStickyItems = stickyItems
        .map(
          (si) => {
            'id': si.id,
            'noteId': si.noteId,
            'textContent': si.textContent,
            'state': si.state,
            'isBullet': si.isBullet,
            'position': si.position,
            'createdAt': si.createdAt.toIso8601String(),
          },
        )
        .toList();

    final serializedAnalyticsEvents = analyticsEvents
        .map(
          (ae) => {
            'id': ae.id,
            'resourceId': ae.resourceId,
            'eventType': ae.eventType,
            'occurredAt': ae.occurredAt.toIso8601String(),
            'metadataJson': ae.metadataJson,
            'durationSeconds': ae.durationSeconds,
            'progressPercent': ae.progressPercent,
            'source': ae.source,
          },
        )
        .toList();

    final databaseMap = {
      'version': 1,
      'schemaVersion': _db.schemaVersion,
      'collections': collections
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'emoji': c.emoji,
              'accent': c.accent,
              'parentId': c.parentId,
              'createdAt': c.createdAt.toIso8601String(),
              'updatedAt': c.updatedAt?.toIso8601String(),
              'deletedAt': c.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'tags': tags.map((t) => {'id': t.id, 'name': t.name}).toList(),
      'resources': resources
          .map(
            (r) => {
              'id': r.id,
              'collectionId': r.collectionId,
              'title': r.title,
              'url': r.url,
              'normalizedUrl': r.normalizedUrl,
              'resourceType': r.resourceType,
              'source': r.source,
              'thumbnailUrl': r.thumbnailUrl,
              'description': r.description,
              'noteTitle': r.noteTitle,
              'notes': r.notes,
              'status': r.status,
              'isFavorite': r.isFavorite,
              'lastOpenedAt': r.lastOpenedAt?.toIso8601String(),
              'completedAt': r.completedAt?.toIso8601String(),
              'openCount': r.openCount,
              'minutes': r.minutes,
              'fetching': r.fetching,
              'accent': r.accent,
              'createdAt': r.createdAt.toIso8601String(),
              'updatedAt': r.updatedAt?.toIso8601String(),
              'deletedAt': r.deletedAt?.toIso8601String(),
            },
          )
          .toList(),
      'resource_tags': serializedResourceTags,
      'resourceTags': serializedResourceTags,
      'sticky_notes': serializedStickyNotes,
      'stickyNotes': serializedStickyNotes,
      'sticky_items': serializedStickyItems,
      'stickyItems': serializedStickyItems,
      'files': files
          .map(
            (f) => {
              'id': f.id,
              'resourceId': f.resourceId,
              'localPath': f.localPath,
              'fileName': sanitizeFileName(f.fileName),
              'mimeType': f.mimeType,
              'fileSize': f.fileSize,
              'createdAt': f.createdAt.toIso8601String(),
              'updatedAt': f.updatedAt?.toIso8601String(),
            },
          )
          .toList(),
      'analytics_events': serializedAnalyticsEvents,
      'analyticsEvents': serializedAnalyticsEvents,
    };

    final databaseJsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(databaseMap);
    final databaseBytes = utf8.encode(databaseJsonString);

    onProgress?.call('Calculating checksums...', 0.40);
    final databaseChecksum = calculateSha256(databaseBytes);

    final checksums = <String, String>{'database.json': databaseChecksum};

    // 3. Build Archive
    final archive = Archive();
    archive.addFile(ArchiveFile.string('database.json', databaseJsonString));

    // 4. Attach physical files
    onProgress?.call('Copying files...', 0.50);
    final storageDir = await _fileStorageService.getStorageDirectory();

    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final sanitizedName = sanitizeFileName(f.fileName);
      File? physicalFile;

      if (await File(f.localPath).exists()) {
        physicalFile = File(f.localPath);
      } else {
        final fallbackPath = p.join(storageDir.path, f.id, f.fileName);
        if (await File(fallbackPath).exists()) {
          physicalFile = File(fallbackPath);
        }
      }

      if (physicalFile != null && await physicalFile.exists()) {
        final bytes = await physicalFile.readAsBytes();
        final relPath = 'files/${f.id}/$sanitizedName';
        final fileSha = calculateSha256(bytes);
        checksums[relPath] = fileSha;
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }

      final fileProgress =
          0.50 + ((i + 1) / (files.isEmpty ? 1 : files.length)) * 0.25;
      onProgress?.call(
        'Copying files (${i + 1}/${files.length})...',
        fileProgress,
      );
    }

    // 5. Generate manifest.json
    final manifestMap = {
      'backupFormatVersion': 1,
      'app': 'SkillNest',
      'appVersion': '1.0.0+1',
      'schemaVersion': _db.schemaVersion,
      'createdAt': now.toIso8601String(),
      'resourceCount': resources.length,
      'collectionCount': collections.length,
      'tagCount': tags.length,
      'resourceTagCount': resourceTags.length,
      'stickyNoteCount': stickyNotes.length,
      'stickyItemCount': stickyItems.length,
      'fileCount': files.length,
      'analyticsEventCount': analyticsEvents.length,
      'checksums': checksums,
    };

    final manifestJsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(manifestMap);
    archive.addFile(ArchiveFile.string('manifest.json', manifestJsonString));

    // 6. Encode ZIP
    onProgress?.call('Creating archive...', 0.90);
    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive);

    // 7. Write to output file
    Directory outDir;
    if (customOutputDir != null) {
      outDir = Directory(customOutputDir);
    } else {
      try {
        outDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        outDir = Directory.systemTemp;
      }
    }
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = customFileName ?? 'skillnest_backup_$formattedDate.zip';
    final targetPath = p.join(outDir.path, fileName);
    final outputFile = File(targetPath);
    await outputFile.writeAsBytes(encodedZip);

    onProgress?.call('Backup complete', 1.0);

    return BackupResult(
      filePath: targetPath,
      byteSize: encodedZip.length,
      resourceCount: resources.length,
      collectionCount: collections.length,
      tagCount: tags.length,
      resourceTagCount: resourceTags.length,
      stickyNoteCount: stickyNotes.length,
      stickyItemCount: stickyItems.length,
      fileCount: files.length,
      analyticsEventCount: analyticsEvents.length,
      createdAt: now,
    );
  }
}
