import 'package:flutter/material.dart';

enum ResourceStatus { unread, inProgress, completed }

enum ResourceKind { article, video, pdf, note, page, course }

extension ResourceKindX on ResourceKind {
  String get label => switch (this) {
    ResourceKind.article => 'Article',
    ResourceKind.video => 'Video',
    ResourceKind.pdf => 'PDF',
    ResourceKind.note => 'Note',
    ResourceKind.page => 'Web page',
    ResourceKind.course => 'Course',
  };

  IconData get icon => switch (this) {
    ResourceKind.article => Icons.article_outlined,
    ResourceKind.video => Icons.play_circle_outline,
    ResourceKind.pdf => Icons.picture_as_pdf_outlined,
    ResourceKind.note => Icons.sticky_note_2_outlined,
    ResourceKind.page => Icons.language,
    ResourceKind.course => Icons.school_outlined,
  };
}

extension ResourceStatusX on ResourceStatus {
  String get label => switch (this) {
    ResourceStatus.unread => 'Unread',
    ResourceStatus.inProgress => 'In progress',
    ResourceStatus.completed => 'Completed',
  };
}

class ResourceItem {
  final String id;
  String title;
  String source; // domain / origin, e.g. "medium.com"
  String url;
  ResourceKind kind;
  ResourceStatus status;
  bool favorite;
  String? collectionId;
  Set<String> tags;
  DateTime addedAt;
  DateTime? lastOpenedAt;
  int openCount;
  int minutes; // estimated reading/watch time
  String noteTitle;
  String note;
  bool fetching; // metadata still resolving in background
  int accent; // thumbnail accent index
  FileItem? localFile; // attached local file metadata

  ResourceItem({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.kind,
    this.status = ResourceStatus.unread,
    this.favorite = false,
    this.collectionId,
    Set<String>? tags,
    DateTime? addedAt,
    this.lastOpenedAt,
    this.openCount = 0,
    this.minutes = 6,
    this.noteTitle = '',
    this.note = '',
    this.fetching = false,
    this.accent = 0,
    this.localFile,
  }) : tags = tags ?? {},
       addedAt = addedAt ?? DateTime.now();

  bool get neverOpened => openCount == 0;
  bool get reopened => openCount > 1;
  String get openLabel => switch (openCount) {
    0 => 'Not opened yet',
    1 => 'Opened once',
    _ => 'Opened $openCount times',
  };

  /// Notes have no external duration. Estimate their reading time from the
  /// text so a newly-created note never misleadingly shows a fixed 6 minutes.
  int get estimatedMinutes {
    if (kind != ResourceKind.note) return minutes;
    final words = note.trim().isEmpty
        ? 0
        : note.trim().split(RegExp(r'\s+')).length;
    return (words / 180).ceil().clamp(1, 60);
  }

  String get displayNoteTitle =>
      noteTitle.trim().isEmpty ? 'Untitled Note' : noteTitle.trim();
}

class FileItem {
  final String id;
  final String resourceId;
  final String localPath;
  final String fileName;
  final String? mimeType;
  final int fileSize;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FileItem({
    required this.id,
    required this.resourceId,
    required this.localPath,
    required this.fileName,
    this.mimeType,
    this.fileSize = 0,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get humanSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get fileExtension {
    final dotIdx = fileName.lastIndexOf('.');
    return dotIdx >= 0 ? fileName.substring(dotIdx + 1).toLowerCase() : '';
  }
}

class CollectionModel {
  final String id;
  String name;
  String emoji;
  int accent; // 0..5 palette index
  DateTime createdAt;

  CollectionModel({
    required this.id,
    required this.name,
    this.emoji = '📚',
    this.accent = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TrashEntry {
  final ResourceItem item;
  final DateTime deletedAt;

  static const int retentionDays = 30;

  TrashEntry({required this.item, required this.deletedAt});

  int get daysLeft =>
      retentionDays - DateTime.now().difference(deletedAt).inDays;
}

class VaultNotification {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final String? resourceId;
  bool read;

  VaultNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    this.resourceId,
    this.read = false,
  });
}

class SearchFilters {
  String query = '';
  ResourceStatus? status;
  ResourceKind? kind;
  String? collectionId;
  String? tag;
  bool favoritesOnly = false;

  bool get isActive =>
      status != null ||
      kind != null ||
      collectionId != null ||
      tag != null ||
      favoritesOnly;

  int get activeCount =>
      (status != null ? 1 : 0) +
      (kind != null ? 1 : 0) +
      (collectionId != null ? 1 : 0) +
      (tag != null ? 1 : 0) +
      (favoritesOnly ? 1 : 0);

  void reset() {
    status = null;
    kind = null;
    collectionId = null;
    tag = null;
    favoritesOnly = false;
  }
}

enum SortOrder { newest, oldest, titleAZ, recentlyOpened }
