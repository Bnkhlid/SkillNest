import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'file_storage_service.dart';

class RestoreException implements Exception {
  final String message;
  const RestoreException(this.message);

  @override
  String toString() => 'RestoreException: $message';
}

class RestoreValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int resourceCount;
  final int collectionCount;
  final int tagCount;
  final int resourceTagCount;
  final int stickyNoteCount;
  final int stickyItemCount;
  final int fileCount;
  final int analyticsEventCount;
  final DateTime? createdAt;
  final int backupFormatVersion;
  final int schemaVersion;

  const RestoreValidationResult({
    required this.isValid,
    this.errorMessage,
    this.resourceCount = 0,
    this.collectionCount = 0,
    this.tagCount = 0,
    this.resourceTagCount = 0,
    this.stickyNoteCount = 0,
    this.stickyItemCount = 0,
    this.fileCount = 0,
    this.analyticsEventCount = 0,
    this.createdAt,
    this.backupFormatVersion = 1,
    this.schemaVersion = 4,
  });
}

class RestoreResult {
  final int resourceCount;
  final int collectionCount;
  final int tagCount;
  final int resourceTagCount;
  final int stickyNoteCount;
  final int stickyItemCount;
  final int fileCount;
  final int analyticsEventCount;

  const RestoreResult({
    required this.resourceCount,
    required this.collectionCount,
    required this.tagCount,
    this.resourceTagCount = 0,
    required this.stickyNoteCount,
    required this.stickyItemCount,
    required this.fileCount,
    this.analyticsEventCount = 0,
  });
}

class RestoreService {
  final AppDatabase _db;
  final FileStorageService _fileStorageService;
  final String? _customTempDir;
  static const _uuid = Uuid();

  RestoreService(this._db, this._fileStorageService, [this._customTempDir]);

  Future<Directory> _getTempDirectory() async {
    final custom = _customTempDir;
    if (custom != null) {
      final dir = Directory(custom);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static String calculateSha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Sanitizes a filename to prevent path traversal and unsafe characters.
  static String sanitizeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00]'), '_');
    return clean.isEmpty ? 'file.bin' : clean;
  }

  /// Helper to convert file or path string to File.
  File _resolveFile(dynamic fileOrPath) {
    if (fileOrPath is File) return fileOrPath;
    if (fileOrPath is String) return File(fileOrPath);
    throw ArgumentError(
      'Expected File or String path, got ${fileOrPath.runtimeType}',
    );
  }

  /// Validates a zip archive without modifying the database or live files.
  Future<RestoreValidationResult> validateBackup(dynamic zipFileOrPath) async {
    final zipFile = _resolveFile(zipFileOrPath);
    if (!await zipFile.exists()) {
      return const RestoreValidationResult(
        isValid: false,
        errorMessage: 'Backup file does not exist.',
      );
    }

    try {
      final bytes = await zipFile.readAsBytes();
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        return RestoreValidationResult(
          isValid: false,
          errorMessage: 'Invalid archive format: $e',
        );
      }

      // 1. Path traversal & security checks
      for (final file in archive.files) {
        final rawName = file.name;
        if (rawName.contains('\x00')) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Security violation: Archive contains null bytes in path.',
          );
        }

        final normalized = rawName.replaceAll('\\', '/');
        if (normalized.contains('../') ||
            normalized.contains('/..') ||
            normalized == '..' ||
            normalized.contains('..\\') ||
            normalized.startsWith('/') ||
            normalized.startsWith('\\')) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Security violation: Archive contains illegal relative or absolute path.',
          );
        }

        if (RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Security violation: Archive contains drive letter path.',
          );
        }

        if (rawName.startsWith(r'\\') || normalized.startsWith('//')) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Security violation: Archive contains UNC network path.',
          );
        }

        // Validate paths under files/
        if (normalized.startsWith('files/')) {
          final parts = normalized.split('/');
          if (parts.length < 3 || parts[1].isEmpty || parts[2].isEmpty) {
            return const RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'Security violation: Malformed file path structure in archive.',
            );
          }
          // Validate file ID format (alphanumeric and underscores/hyphens)
          if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(parts[1])) {
            return const RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'Security violation: Invalid file ID format in archive.',
            );
          }
        }
      }

      // 2. Locate required root files
      final manifestFile = archive.findFile('manifest.json');
      final databaseFile = archive.findFile('database.json');

      if (manifestFile == null) {
        return const RestoreValidationResult(
          isValid: false,
          errorMessage: 'Invalid backup: manifest.json is missing.',
        );
      }

      if (databaseFile == null) {
        return const RestoreValidationResult(
          isValid: false,
          errorMessage: 'Invalid backup: database.json is missing.',
        );
      }

      // 3. Parse manifest
      Map<String, dynamic> manifest;
      try {
        final manifestStr = utf8.decode(manifestFile.content as List<int>);
        manifest = jsonDecode(manifestStr) as Map<String, dynamic>;
      } catch (e) {
        return RestoreValidationResult(
          isValid: false,
          errorMessage: 'Invalid backup: manifest.json is corrupted ($e).',
        );
      }

      final backupFormatVersion = manifest['backupFormatVersion'] as int? ?? 1;
      if (backupFormatVersion > 1) {
        return RestoreValidationResult(
          isValid: false,
          errorMessage:
              'Unsupported backup format version ($backupFormatVersion). Please update SkillNest.',
        );
      }

      final schemaVersion = manifest['schemaVersion'] as int? ?? 3;
      if (schemaVersion > _db.schemaVersion) {
        return RestoreValidationResult(
          isValid: false,
          errorMessage:
              'Backup database schema ($schemaVersion) is newer than current app version (${_db.schemaVersion}).',
        );
      }

      // 4. Parse database.json
      Map<String, dynamic> dbData;
      try {
        final dbContent = databaseFile.content as List<int>;
        final dbStr = utf8.decode(dbContent);
        dbData = jsonDecode(dbStr) as Map<String, dynamic>;

        // Verify database.json checksum if provided
        final checksums =
            (manifest['checksums'] as Map<String, dynamic>?) ?? {};
        if (checksums.containsKey('database.json')) {
          final expectedSha = checksums['database.json'] as String;
          final actualSha = calculateSha256(dbContent);
          if (expectedSha != actualSha) {
            return const RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'Database checksum mismatch: database.json may be corrupted.',
            );
          }
        }
      } catch (e) {
        return RestoreValidationResult(
          isValid: false,
          errorMessage: 'Invalid backup: database.json is corrupted ($e).',
        );
      }

      // Helper for snake_case / camelCase dual support
      List<dynamic> getList(String snake, String camel) {
        return (dbData[snake] as List<dynamic>?) ??
            (dbData[camel] as List<dynamic>?) ??
            [];
      }

      // 5. Entity Schema & Primary Key Validation
      final collections = (dbData['collections'] as List<dynamic>?) ?? [];
      final tags = (dbData['tags'] as List<dynamic>?) ?? [];
      final resources = (dbData['resources'] as List<dynamic>?) ?? [];
      final resourceTags = getList('resource_tags', 'resourceTags');
      final stickyNotes = getList('sticky_notes', 'stickyNotes');
      final stickyItems = getList('sticky_items', 'stickyItems');
      final files = (dbData['files'] as List<dynamic>?) ?? [];
      final analyticsEvents = getList('analytics_events', 'analyticsEvents');

      final collectionIds = <String>{};
      for (final c in collections) {
        if (c is! Map<String, dynamic> ||
            c['id'] is! String ||
            (c['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: collection entry has invalid structure.',
          );
        }
        final id = c['id'] as String;
        if (collectionIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: duplicate collection ID found ($id).',
          );
        }
        collectionIds.add(id);
      }

      final tagIds = <String>{};
      for (final t in tags) {
        if (t is! Map<String, dynamic> ||
            t['id'] is! String ||
            (t['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage: 'Integrity error: tag entry has invalid structure.',
          );
        }
        final id = t['id'] as String;
        if (tagIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage: 'Integrity error: duplicate tag ID found ($id).',
          );
        }
        tagIds.add(id);
      }

      final resourceIds = <String>{};
      for (final r in resources) {
        if (r is! Map<String, dynamic> ||
            r['id'] is! String ||
            (r['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: resource entry has invalid structure.',
          );
        }
        final id = r['id'] as String;
        if (resourceIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage: 'Integrity error: duplicate resource ID found ($id).',
          );
        }
        resourceIds.add(id);
      }

      final stickyNoteIds = <String>{};
      for (final sn in stickyNotes) {
        if (sn is! Map<String, dynamic> ||
            sn['id'] is! String ||
            (sn['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: sticky note entry has invalid structure.',
          );
        }
        final id = sn['id'] as String;
        if (stickyNoteIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: duplicate sticky note ID found ($id).',
          );
        }
        stickyNoteIds.add(id);
      }

      final stickyItemIds = <String>{};
      for (final si in stickyItems) {
        if (si is! Map<String, dynamic> ||
            si['id'] is! String ||
            (si['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: sticky item entry has invalid structure.',
          );
        }
        final id = si['id'] as String;
        if (stickyItemIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: duplicate sticky item ID found ($id).',
          );
        }
        stickyItemIds.add(id);
      }

      final fileIds = <String>{};
      for (final f in files) {
        if (f is! Map<String, dynamic> ||
            f['id'] is! String ||
            (f['id'] as String).isEmpty) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage: 'Integrity error: file entry has invalid structure.',
          );
        }
        final id = f['id'] as String;
        if (fileIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage: 'Integrity error: duplicate file ID found ($id).',
          );
        }
        fileIds.add(id);
      }

      final analyticsEventIds = <String>{};
      for (final ae in analyticsEvents) {
        if (ae is! Map<String, dynamic> ||
            ae['id'] is! String ||
            (ae['id'] as String).isEmpty ||
            ae['eventType'] is! String ||
            ae['occurredAt'] == null) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: analytics event entry has invalid structure.',
          );
        }
        final id = ae['id'] as String;
        if (analyticsEventIds.contains(id)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: duplicate analytics event ID found ($id).',
          );
        }
        analyticsEventIds.add(id);
      }

      // 6. Foreign Key Relationships Validation
      for (final c in collections) {
        final cMap = c as Map<String, dynamic>;
        final parentId = cMap['parentId'] as String?;
        if (parentId != null && parentId.isNotEmpty) {
          if (parentId == cMap['id']) {
            return RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'Integrity error: collection (${cMap['id']}) references itself as parent.',
            );
          }
          if (!collectionIds.contains(parentId)) {
            return RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'Integrity error: collection (${cMap['id']}) references nonexistent parent collection ($parentId).',
            );
          }
        }
      }

      for (final r in resources) {
        final rMap = r as Map<String, dynamic>;
        final colId = rMap['collectionId'] as String?;
        if (colId != null &&
            colId.isNotEmpty &&
            !collectionIds.contains(colId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: resource (${rMap['id']}) references nonexistent collection ($colId).',
          );
        }
      }

      for (final rt in resourceTags) {
        if (rt is! Map<String, dynamic>) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: resource_tag entry is not a valid map.',
          );
        }
        final resId = rt['resourceId'] as String?;
        final tagId = rt['tagId'] as String?;
        if (resId == null || !resourceIds.contains(resId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: resource_tag references nonexistent resource ($resId).',
          );
        }
        if (tagId == null || !tagIds.contains(tagId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: resource_tag references nonexistent tag ($tagId).',
          );
        }
      }

      for (final si in stickyItems) {
        final siMap = si as Map<String, dynamic>;
        final noteId = siMap['noteId'] as String?;
        if (noteId == null || !stickyNoteIds.contains(noteId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: sticky_item references nonexistent sticky_note ($noteId).',
          );
        }
      }

      for (final ae in analyticsEvents) {
        final aeMap = ae as Map<String, dynamic>;
        final resId = aeMap['resourceId'] as String?;
        if (resId != null && resId.isNotEmpty && !resourceIds.contains(resId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: analytics_event references nonexistent resource ($resId).',
          );
        }
      }

      // 7. Attached Files Validation & Checksums
      final checksums = (manifest['checksums'] as Map<String, dynamic>?) ?? {};

      for (final f in files) {
        final fMap = f as Map<String, dynamic>;
        final fileId = fMap['id'] as String?;
        final resId = fMap['resourceId'] as String?;
        final rawFileName = fMap['fileName'] as String?;

        if (fileId == null || resId == null || rawFileName == null) {
          return const RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: file record is missing required fields.',
          );
        }

        if (!resourceIds.contains(resId)) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage:
                'Integrity error: file references nonexistent resource ($resId).',
          );
        }

        final fileName = sanitizeFileName(rawFileName);
        final expectedRelPath = 'files/$fileId/$fileName';
        var archiveFile = archive.findFile(expectedRelPath);

        // Also check raw filename if sanitized differs
        if (archiveFile == null && fileName != rawFileName) {
          archiveFile = archive.findFile('files/$fileId/$rawFileName');
        }

        if (archiveFile == null) {
          return RestoreValidationResult(
            isValid: false,
            errorMessage: 'Missing attached file in archive: $expectedRelPath',
          );
        }

        final fileBytes = archiveFile.content as List<int>;
        final actualSha = calculateSha256(fileBytes);

        if (checksums.containsKey(expectedRelPath)) {
          final expectedSha = checksums[expectedRelPath] as String;
          if (expectedSha != actualSha) {
            return RestoreValidationResult(
              isValid: false,
              errorMessage:
                  'File checksum mismatch for $fileName. Backup may be corrupted.',
            );
          }
        }
      }

      DateTime? createdAt;
      if (manifest['createdAt'] != null) {
        createdAt = DateTime.tryParse(manifest['createdAt'].toString());
      }

      return RestoreValidationResult(
        isValid: true,
        resourceCount: resources.length,
        collectionCount: collections.length,
        tagCount: tags.length,
        resourceTagCount: resourceTags.length,
        stickyNoteCount: stickyNotes.length,
        stickyItemCount: stickyItems.length,
        fileCount: files.length,
        analyticsEventCount: analyticsEvents.length,
        createdAt: createdAt,
        backupFormatVersion: backupFormatVersion,
        schemaVersion: schemaVersion,
      );
    } catch (e) {
      return RestoreValidationResult(
        isValid: false,
        errorMessage: 'Failed to read backup archive: $e',
      );
    }
  }

  /// Staged restore pipeline: validates, creates safety snapshot, extracts to staging,
  /// executes atomic DB restore, commits physical files, rebuilds FTS5, and cleans staging.
  /// On any failure, automatically rolls back live DB and files to previous snapshot state.
  Future<RestoreResult> restoreBackup(
    dynamic zipFileOrPath, {
    void Function(String status, double progress)? onProgress,
    void Function(String status)? onSimpleProgress,
  }) async {
    void report(String status, double progress) {
      onProgress?.call(status, progress);
      onSimpleProgress?.call(status);
    }

    report('Preparing...', 0.05);
    report('Reading backup...', 0.10);
    report('Validating manifest...', 0.15);
    report('Validating database...', 0.20);
    report('Validating files...', 0.25);
    report('Checking integrity...', 0.30);

    final validation = await validateBackup(zipFileOrPath);
    if (!validation.isValid) {
      throw RestoreException(validation.errorMessage ?? 'Validation failed.');
    }

    final zipFile = _resolveFile(zipFileOrPath);
    final tempDir = await _getTempDirectory();
    final stagingDir = Directory(
      p.join(tempDir.path, 'skillnest_restore_staging_${_uuid.v4()}'),
    );
    final safetySnapshotDir = Directory(
      p.join(tempDir.path, 'skillnest_restore_safety_snapshot_${_uuid.v4()}'),
    );

    if (!await stagingDir.exists()) await stagingDir.create(recursive: true);
    if (!await safetySnapshotDir.exists()) {
      await safetySnapshotDir.create(recursive: true);
    }

    // SAFETY SNAPSHOT of live state before destructive changes
    List<CollectionEntry>? snapshotCollections;
    List<TagEntry>? snapshotTags;
    List<ResourceEntry>? snapshotResources;
    List<ResourceTagEntry>? snapshotResourceTags;
    List<StickyNoteEntry>? snapshotStickyNotes;
    List<StickyItemEntry>? snapshotStickyItems;
    List<FileEntry>? snapshotFiles;
    List<AnalyticsEventEntry>? snapshotAnalyticsEvents;
    bool dbRestored = false;

    try {
      // 1. Capture Live DB Snapshot
      snapshotCollections = await _db.collectionDao.getAllCollectionsRaw();
      snapshotTags = await _db.tagDao.getAllTagsRaw();
      snapshotResources = await _db.resourceDao.getAllResources();
      snapshotResourceTags = await _db.tagDao.getAllResourceTagsRaw();
      snapshotStickyNotes = await _db.stickyNoteDao.getAllNotesRaw();
      snapshotStickyItems = await _db.stickyNoteDao.getAllItemsRaw();
      snapshotFiles = await _db.fileDao.getAllFiles();
      snapshotAnalyticsEvents = await _db.analyticsEventDao.getAllEventsRaw();

      // 2. Capture Live Physical Files Snapshot
      final storageDir = await _fileStorageService.getStorageDirectory();
      if (await storageDir.exists()) {
        final snapFilesDir = Directory(p.join(safetySnapshotDir.path, 'files'));
        await snapFilesDir.create(recursive: true);
        await for (final entity in storageDir.list(recursive: true)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: storageDir.path);
            final copyTo = File(p.join(snapFilesDir.path, rel));
            await copyTo.parent.create(recursive: true);
            await entity.copy(copyTo.path);
          }
        }
      }

      // 3. Extract Archive to Staging Directory
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive.files) {
        final filename = file.name.replaceAll('\\', '/');
        if (file.isFile) {
          final outFile = File(p.join(stagingDir.path, filename));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 4. Read database.json from Staging
      final dbJsonFile = File(p.join(stagingDir.path, 'database.json'));
      final dbData =
          jsonDecode(await dbJsonFile.readAsString()) as Map<String, dynamic>;

      List<dynamic> getList(String snake, String camel) {
        return (dbData[snake] as List<dynamic>?) ??
            (dbData[camel] as List<dynamic>?) ??
            [];
      }

      // Convert collections
      final rawCollections = (dbData['collections'] as List<dynamic>?) ?? [];
      final collectionsEntries = rawCollections.map((c) {
        final m = c as Map<String, dynamic>;
        return CollectionEntry(
          id: m['id'] as String,
          name: m['name'] as String,
          emoji: m['emoji'] as String? ?? '📚',
          accent: m['accent'] as int? ?? 0,
          parentId: m['parentId'] as String?,
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt: m['updatedAt'] != null
              ? DateTime.tryParse(m['updatedAt'].toString())
              : null,
          deletedAt: m['deletedAt'] != null
              ? DateTime.tryParse(m['deletedAt'].toString())
              : null,
        );
      }).toList();

      // Convert tags
      final rawTags = (dbData['tags'] as List<dynamic>?) ?? [];
      final tagsEntries = rawTags.map((t) {
        final m = t as Map<String, dynamic>;
        return TagEntry(id: m['id'] as String, name: m['name'] as String);
      }).toList();

      // Convert resources
      final rawResources = (dbData['resources'] as List<dynamic>?) ?? [];
      final resourcesEntries = rawResources.map((r) {
        final m = r as Map<String, dynamic>;
        return ResourceEntry(
          id: m['id'] as String,
          collectionId: m['collectionId'] as String?,
          title: m['title'] as String? ?? '',
          url: m['url'] as String? ?? '',
          normalizedUrl: m['normalizedUrl'] as String? ?? '',
          resourceType: m['resourceType'] as String? ?? 'article',
          source: m['source'] as String? ?? '',
          thumbnailUrl: m['thumbnailUrl'] as String?,
          description: m['description'] as String?,
          noteTitle: m['noteTitle'] as String? ?? '',
          notes: m['notes'] as String? ?? '',
          status: m['status'] as String? ?? 'unread',
          isFavorite: m['isFavorite'] as bool? ?? false,
          lastOpenedAt: m['lastOpenedAt'] != null
              ? DateTime.tryParse(m['lastOpenedAt'].toString())
              : null,
          completedAt: m['completedAt'] != null
              ? DateTime.tryParse(m['completedAt'].toString())
              : null,
          openCount: m['openCount'] as int? ?? 0,
          minutes: m['minutes'] as int? ?? 6,
          fetching: m['fetching'] as bool? ?? false,
          accent: m['accent'] as int? ?? 0,
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt: m['updatedAt'] != null
              ? DateTime.tryParse(m['updatedAt'].toString())
              : null,
          deletedAt: m['deletedAt'] != null
              ? DateTime.tryParse(m['deletedAt'].toString())
              : null,
        );
      }).toList();

      // Convert resource_tags
      final rawResourceTags = getList('resource_tags', 'resourceTags');
      final resourceTagsEntries = rawResourceTags.map((rt) {
        final m = rt as Map<String, dynamic>;
        return ResourceTagEntry(
          resourceId: m['resourceId'] as String,
          tagId: m['tagId'] as String,
        );
      }).toList();

      // Convert sticky_notes
      final rawStickyNotes = getList('sticky_notes', 'stickyNotes');
      final stickyNotesEntries = rawStickyNotes.map((sn) {
        final m = sn as Map<String, dynamic>;
        return StickyNoteEntry(
          id: m['id'] as String,
          title: m['title'] as String? ?? '',
          colorValue: m['colorValue'] as int? ?? 0xFFFDF6E2,
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt: m['updatedAt'] != null
              ? DateTime.tryParse(m['updatedAt'].toString())
              : null,
        );
      }).toList();

      // Convert sticky_items
      final rawStickyItems = getList('sticky_items', 'stickyItems');
      final stickyItemsEntries = rawStickyItems.map((si) {
        final m = si as Map<String, dynamic>;
        return StickyItemEntry(
          id: m['id'] as String,
          noteId: m['noteId'] as String,
          textContent: m['textContent'] as String? ?? '',
          state: m['state'] as String? ?? 'unchecked',
          isBullet: m['isBullet'] as bool? ?? false,
          position: m['position'] as int? ?? 0,
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
        );
      }).toList();

      // Convert files
      final rawFiles = (dbData['files'] as List<dynamic>?) ?? [];
      final filesEntries = <FileEntry>[];
      for (final f in rawFiles) {
        final m = f as Map<String, dynamic>;
        final fileId = m['id'] as String;
        final rawFileName = m['fileName'] as String;
        final fileName = sanitizeFileName(rawFileName);
        final targetLocalPath = p.join(storageDir.path, fileId, fileName);

        filesEntries.add(
          FileEntry(
            id: fileId,
            resourceId: m['resourceId'] as String,
            localPath: targetLocalPath,
            fileName: fileName,
            mimeType: m['mimeType'] as String?,
            fileSize: m['fileSize'] as int? ?? 0,
            createdAt:
                DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
                DateTime.now(),
            updatedAt: m['updatedAt'] != null
                ? DateTime.tryParse(m['updatedAt'].toString())
                : null,
          ),
        );
      }

      // Convert analytics_events
      final rawAnalyticsEvents = getList('analytics_events', 'analyticsEvents');
      final analyticsEventsEntries = rawAnalyticsEvents.map((ae) {
        final m = ae as Map<String, dynamic>;
        return AnalyticsEventEntry(
          id: m['id'] as String,
          resourceId: m['resourceId'] as String?,
          eventType: m['eventType'] as String,
          occurredAt:
              DateTime.tryParse(m['occurredAt']?.toString() ?? '') ??
              DateTime.now(),
          metadataJson: m['metadataJson'] as String?,
          durationSeconds: m['durationSeconds'] as int?,
          progressPercent: (m['progressPercent'] as num?)?.toDouble(),
          source: m['source'] as String?,
        );
      }).toList();

      // 5. Atomic SQLite Database Restoration
      report('Restoring database...', 0.50);
      await _db.clearAndRestoreData(
        collectionsData: collectionsEntries,
        resourcesData: resourcesEntries,
        tagsData: tagsEntries,
        resourceTagsData: resourceTagsEntries,
        stickyNotesData: stickyNotesEntries,
        stickyItemsData: stickyItemsEntries,
        filesData: filesEntries,
        analyticsEventsData: analyticsEventsEntries,
      );
      dbRestored = true;

      // 6. Commit Physical Files
      report('Restoring files...', 0.70);
      for (var i = 0; i < filesEntries.length; i++) {
        final entry = filesEntries[i];
        var stagedFile = File(
          p.join(stagingDir.path, 'files', entry.id, entry.fileName),
        );
        if (!await stagedFile.exists()) {
          // Check raw files in staging
          final rawMatch =
              (rawFiles[i] as Map<String, dynamic>)['fileName'] as String?;
          if (rawMatch != null) {
            final altFile = File(
              p.join(stagingDir.path, 'files', entry.id, rawMatch),
            );
            if (await altFile.exists()) stagedFile = altFile;
          }
        }

        if (await stagedFile.exists()) {
          final destFile = File(entry.localPath);
          await destFile.parent.create(recursive: true);
          await stagedFile.copy(destFile.path);
        }
      }

      // 7. Rebuild FTS5 Search Index
      report('Rebuilding search index...', 0.85);
      await _db.searchDao.rebuildIndex();

      report('Reloading library...', 0.95);
      report('Restore complete', 1.0);

      return RestoreResult(
        resourceCount: resourcesEntries.length,
        collectionCount: collectionsEntries.length,
        tagCount: tagsEntries.length,
        resourceTagCount: resourceTagsEntries.length,
        stickyNoteCount: stickyNotesEntries.length,
        stickyItemCount: stickyItemsEntries.length,
        fileCount: filesEntries.length,
        analyticsEventCount: analyticsEventsEntries.length,
      );
    } catch (e) {
      // ROLLBACK LIVE DATABASE & FILES ON FAILURE
      if (dbRestored && snapshotCollections != null) {
        try {
          await _db.clearAndRestoreData(
            collectionsData: snapshotCollections,
            resourcesData: snapshotResources ?? [],
            tagsData: snapshotTags ?? [],
            resourceTagsData: snapshotResourceTags ?? [],
            stickyNotesData: snapshotStickyNotes ?? [],
            stickyItemsData: snapshotStickyItems ?? [],
            filesData: snapshotFiles ?? [],
            analyticsEventsData: snapshotAnalyticsEvents ?? [],
          );
          await _db.searchDao.rebuildIndex();
        } catch (_) {}

        // Restore files from snapshot
        try {
          final storageDir = await _fileStorageService.getStorageDirectory();
          final snapFilesDir = Directory(
            p.join(safetySnapshotDir.path, 'files'),
          );
          if (await snapFilesDir.exists()) {
            await for (final entity in snapFilesDir.list(recursive: true)) {
              if (entity is File) {
                final rel = p.relative(entity.path, from: snapFilesDir.path);
                final destFile = File(p.join(storageDir.path, rel));
                await destFile.parent.create(recursive: true);
                await entity.copy(destFile.path);
              }
            }
          }
        } catch (_) {}
      }

      throw RestoreException('Restore failed: $e');
    } finally {
      // Clean up temporary staging and safety snapshot directories
      if (await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
      if (await safetySnapshotDir.exists()) {
        try {
          await safetySnapshotDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
