import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/database/app_database.dart';
import 'core/database/daos/collection_dao.dart';
import 'core/database/daos/file_dao.dart';
import 'core/database/daos/resource_dao.dart';
import 'core/database/daos/search_dao.dart';
import 'core/database/daos/sticky_note_dao.dart';
import 'core/database/daos/tag_dao.dart';
import 'core/database/daos/analytics_event_dao.dart';
import 'core/repositories/analytics_repository.dart';
import 'core/services/analytics_service.dart';
import 'core/services/backup_service.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/firebase_usage_analytics.dart';
import 'core/services/metadata_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/restore_service.dart';
import 'core/utils/url_normalizer.dart';
import 'features/notes/data/sticky_note_repository.dart';
import 'features/resources/data/file_repository.dart';
import 'features/search/data/search_repository.dart';
import 'models.dart';
import 'widgets/components.dart';

/// App data store backed by Drift (SQLite) database.
/// Manages reactive in-memory state while immediately persisting to SQLite.
class Vault extends ChangeNotifier {
  Vault._();

  static final Vault I = Vault._();
  factory Vault.instance() => I;

  AppDatabase? _db;
  CollectionDao? _collectionDao;
  ResourceDao? _resourceDao;
  TagDao? _tagDao;
  FileDao? _fileDao;
  StickyNoteDao? _stickyNoteDao;
  StickyNoteRepository? _stickyNoteRepo;
  SearchDao? _searchDao;
  SearchRepository? _searchRepo;
  FileStorageService? _fileStorageService;
  FileRepository? _fileRepo;
  AnalyticsEventDao? _analyticsEventDao;
  AnalyticsService? _analyticsService;
  AnalyticsRepository? _analyticsRepo;
  NotificationService? _notificationService;
  BackupService? _backupService;
  RestoreService? _restoreService;

  FileRepository? get fileRepo => _fileRepo;
  AnalyticsService? get analyticsService => _analyticsService;
  AnalyticsRepository? get analyticsRepo => _analyticsRepo;
  NotificationService? get notificationService => _notificationService;
  BackupService? get backupService => _backupService;
  RestoreService? get restoreService => _restoreService;

  // ------------------------------------------------------------------ state
  final List<ResourceItem> items = [];
  final List<CollectionModel> collections = [];
  final List<TrashEntry> trash = [];
  final List<StickyNoteModel> stickyNotes = [];
  final List<VaultNotification> notifications = [];
  final List<String> recentSearches = [];

  String userName = '';
  String userEmail = '';
  String? userAvatarPath;
  ThemeMode themeMode = ThemeMode.light;

  bool offlineDemo = false; // simulates no connection across the app
  bool simulateBackupFailure = false; // demo switch for error states

  /// Explicitly notify listeners when external services modify vault state.
  void forceNotify() => notifyListeners();
  bool dailyDigest = true;
  bool weeklyReport = true;
  bool unreadReminders = false;
  int morningReminderMinutes = 9 * 60;
  int eveningReminderMinutes = 21 * 60;
  DateTime? lastBackupAt;
  int cachedBytes = 148 * 1024 * 1024;

  bool _firstRunDone = false;
  bool get firstRunDone => _firstRunDone;
  bool _notificationOnboardingHandled = false;
  bool get notificationOnboardingHandled => _notificationOnboardingHandled;

  Future<File> _getNotificationsFile() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDocDir.path, 'skillnest'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File(p.join(dir.path, 'app_notifications.json'));
    } catch (_) {
      return File('app_notifications.json');
    }
  }

  final Set<String> _dismissedNotificationKeys = {};

  Future<void> _loadNotifications({bool mergeOnly = false}) async {
    try {
      final file = await _getNotificationsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        if (!mergeOnly) {
          notifications.clear();
        }
        bool changed = false;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final id = m['id'] as String? ?? 'n_${DateTime.now().microsecondsSinceEpoch}';
          final title = m['title'] as String? ?? '';
          final body = m['body'] as String? ?? '';
          if (title.isEmpty && body.isEmpty) continue;

          final sig = '$title|||$body';
          if (mergeOnly && (_dismissedNotificationKeys.contains(sig) || _dismissedNotificationKeys.contains(id))) {
            continue;
          }

          if (mergeOnly) {
            final alreadyPresent = notifications.any(
              (n) => n.id == id || (n.title == title && n.body == body),
            );
            if (alreadyPresent) continue;
            notifications.insert(
              0,
              VaultNotification(
                id: id,
                title: title,
                body: body,
                read: m['read'] as bool? ?? false,
                resourceId: m['resourceId'] as String?,
                icon: Icons.notifications_outlined,
              ),
            );
            changed = true;
          } else {
            notifications.add(
              VaultNotification(
                id: id,
                title: title,
                body: body,
                read: m['read'] as bool? ?? false,
                resourceId: m['resourceId'] as String?,
                icon: Icons.notifications_outlined,
              ),
            );
          }
        }
        if (mergeOnly && changed) {
          if (notifications.length > 50) {
            notifications.removeRange(50, notifications.length);
          }
          await _saveNotifications();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Scans the system tray for active notifications (e.g. Firebase Console
  /// push notifications received while backgrounded) and synchronizes them
  /// into the in-app notification bell.
  Future<void> syncActiveSystemNotifications() async {
    try {
      // 1. Merge any notifications stored by background isolate
      await _loadNotifications(mergeOnly: true);

      // 2. Query active notifications currently sitting in the system tray
      if (_notificationService == null) return;
      final activeList = await _notificationService!.getActiveNotifications();
      bool changed = false;

      for (final active in activeList) {
        final title = active.title?.trim();
        final body = (active.bigText ?? active.body ?? '').trim();
        if ((title == null || title.isEmpty) && body.isEmpty) continue;

        final resolvedTitle = (title != null && title.isNotEmpty) ? title : 'SkillNest';
        final sig = '$resolvedTitle|||$body';
        if (_dismissedNotificationKeys.contains(sig)) continue;

        final exists = notifications.any(
          (n) => n.title == resolvedTitle && n.body == body,
        );

        if (!exists) {
          notifications.insert(
            0,
            VaultNotification(
              id: 'n_${DateTime.now().microsecondsSinceEpoch}',
              title: resolvedTitle,
              body: body,
              icon: Icons.notifications_outlined,
              read: false,
            ),
          );
          changed = true;
        }
      }

      if (changed) {
        if (notifications.length > 50) {
          notifications.removeRange(50, notifications.length);
        }
        await _saveNotifications();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('syncActiveSystemNotifications failed safely: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final file = await _getNotificationsFile();
      final list = notifications.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'read': n.read,
        'resourceId': n.resourceId,
      }).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  List<CollectionModel> subCollections(String parentId) =>
      collections.where((c) => c.parentId == parentId).toList();

  List<CollectionModel> get rootCollections =>
      collections.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();

  String getCollectionPath(String collectionId) {
    final c = collections.where((col) => col.id == collectionId).firstOrNull;
    if (c == null) return '';
    if (c.parentId != null && c.parentId!.isNotEmpty) {
      final parentPath = getCollectionPath(c.parentId!);
      if (parentPath.isNotEmpty) {
        return '$parentPath > ${c.emoji} ${c.name}';
      }
    }
    return '${c.emoji} ${c.name}';
  }

  Future<File> _getPrefsFile() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDocDir.path, 'skillnest'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File(p.join(dir.path, 'app_preferences.json'));
    } catch (_) {
      return File('app_preferences.json');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final file = await _getPrefsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _firstRunDone = json['firstRunDone'] as bool? ?? false;
        // Existing users predate this small onboarding. Keep their update
        // quiet; only newly completed onboarding flows should show it.
        _notificationOnboardingHandled =
            json['notificationOnboardingHandled'] as bool? ?? false;
        if (json['userName'] != null &&
            (json['userName'] as String).trim().isNotEmpty) {
          userName = (json['userName'] as String).trim();
        }
        if (json['userEmail'] != null) {
          final savedEmail = json['userEmail'] as String;
          userEmail = savedEmail == 'mohamed@skillnest.app' ? '' : savedEmail;
        }
        if (json['userAvatarPath'] != null) {
          userAvatarPath = json['userAvatarPath'] as String;
        }
        final theme = json['themeMode'] as String?;
        if (theme == 'dark') themeMode = ThemeMode.dark;
        if (theme == 'light') themeMode = ThemeMode.light;
        if (theme == 'system') themeMode = ThemeMode.light;
        dailyDigest = json['dailyDigest'] as bool? ?? dailyDigest;
        weeklyReport = json['weeklyReport'] as bool? ?? weeklyReport;
        unreadReminders = json['unreadReminders'] as bool? ?? unreadReminders;
        morningReminderMinutes =
            json['morningReminderMinutes'] as int? ?? morningReminderMinutes;
        eveningReminderMinutes =
            json['eveningReminderMinutes'] as int? ?? eveningReminderMinutes;
        final savedBackupAt = json['lastBackupAt'] as String?;
        lastBackupAt = savedBackupAt == null
            ? null
            : DateTime.tryParse(savedBackupAt)?.toLocal();
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final file = await _getPrefsFile();
      final json = {
        'firstRunDone': _firstRunDone,
        'notificationOnboardingHandled': _notificationOnboardingHandled,
        'userName': userName,
        'userEmail': userEmail,
        'userAvatarPath': userAvatarPath,
        'themeMode': themeMode.name,
        'dailyDigest': dailyDigest,
        'weeklyReport': weeklyReport,
        'unreadReminders': unreadReminders,
        'morningReminderMinutes': morningReminderMinutes,
        'eveningReminderMinutes': eveningReminderMinutes,
        'lastBackupAt': lastBackupAt?.toUtc().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(json));
    } catch (_) {}
  }

  Future<void> completeFirstRun() async {
    _firstRunDone = true;
    _notificationOnboardingHandled = false;
    // The first-run flag must reach disk before navigation. Otherwise a quick
    // background/close immediately after onboarding can reopen it next launch.
    await _savePreferences();
    notifyListeners();
  }

  /// Marks the one-time notification prompt as handled before the Android
  /// permission sheet is opened, so it never appears again automatically.
  Future<bool> handleNotificationOnboarding() async {
    _notificationOnboardingHandled = true;
    await _savePreferences();
    notifyListeners();

    return enableNotifications();
  }

  /// Requests notification access without scheduling or displaying a test.
  /// Used by the first-run prompt and the explicit Settings retry action.
  Future<bool> enableNotifications() async {
    final granted = await _notificationService?.requestPermissions() ?? false;
    if (granted) await _syncLearningReminders();
    return granted;
  }

  Future<void> dismissNotificationOnboarding() async {
    _notificationOnboardingHandled = true;
    await _savePreferences();
    notifyListeners();
  }

  /// Initialize database and load persistent data
  Future<void> init([
    AppDatabase? db,
    FileStorageService? storageService,
    AnalyticsService? analyticsService,
    AnalyticsRepository? analyticsRepo,
    NotificationService? notificationService,
  ]) async {
    _db = db ?? AppDatabase();
    _collectionDao = _db!.collectionDao;
    _resourceDao = _db!.resourceDao;
    _tagDao = _db!.tagDao;
    _fileDao = _db!.fileDao;
    _stickyNoteDao = _db!.stickyNoteDao;
    _stickyNoteRepo = StickyNoteRepository(_stickyNoteDao!);
    _searchDao = _db!.searchDao;
    _searchRepo = SearchRepository(_searchDao!, _tagDao!);
    _fileStorageService = storageService ?? FileStorageService();
    _fileRepo = FileRepository(_fileDao!, _fileStorageService!, _searchDao);
    _analyticsEventDao = _db!.analyticsEventDao;
    _analyticsService =
        analyticsService ?? AnalyticsService(_analyticsEventDao!);
    _analyticsRepo =
        analyticsRepo ??
        AnalyticsRepository(_analyticsEventDao!, _resourceDao!);
    _notificationService = notificationService ?? NotificationService.instance;
    await _notificationService?.init();
    _backupService = BackupService(_db!, _fileStorageService!);
    _restoreService = RestoreService(_db!, _fileStorageService!);

    await _loadPreferences();
    await _loadNotifications();
    await syncActiveSystemNotifications();
    await _syncLearningReminders();
    await reloadFromDb();
  }

  /// Reload all collections, active resources, and trash from database
  Future<void> reloadFromDb() async {
    if (_db == null) return;

    // 1. Load Collections
    collections.clear();
    final dbCollections = await _collectionDao!.getAll();
    for (final c in dbCollections) {
      collections.add(
        CollectionModel(
          id: c.id,
          name: c.name,
          emoji: c.emoji,
          accent: c.accent,
          parentId: c.parentId,
          createdAt: c.createdAt,
        ),
      );
    }

    // 2. Load Active Resources with Tags & Local Files
    items.clear();
    final dbResources = await _resourceDao!.getActiveResources();
    for (final r in dbResources) {
      final tags = await _tagDao!.getTagsForResource(r.id);
      final fileEntry = await _fileDao?.getFileForResource(r.id);
      final fileItem = fileEntry != null ? _mapFileEntry(fileEntry) : null;
      items.add(_mapResourceEntry(r, tags, fileItem));
    }

    // 3. Load Trash with Tags & Local Files
    trash.clear();
    final dbTrash = await _resourceDao!.getTrashResources();
    for (final t in dbTrash) {
      final tags = await _tagDao!.getTagsForResource(t.id);
      final fileEntry = await _fileDao?.getFileForResource(t.id);
      final fileItem = fileEntry != null ? _mapFileEntry(fileEntry) : null;
      trash.add(
        TrashEntry(
          item: _mapResourceEntry(t, tags, fileItem),
          deletedAt: t.deletedAt ?? DateTime.now(),
        ),
      );
    }

    // 4. Load Sticky Notes & Tasks
    stickyNotes.clear();
    if (_stickyNoteRepo != null) {
      final dbNotes = await _stickyNoteRepo!.getNotes();
      stickyNotes.addAll(dbNotes);
    }

    notifyListeners();
  }

  FileItem _mapFileEntry(FileEntry entry) {
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

  ResourceItem _mapResourceEntry(
    ResourceEntry entry,
    Set<String> tags, [
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
      tags: tags,
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

  // ---- simple preference setters (notify listeners) ----------------------
  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _savePreferences();
    notifyListeners();
  }

  void setOffline(bool v) {
    offlineDemo = v;
    notifyListeners();
  }

  void setSimulateBackupFailure(bool v) {
    simulateBackupFailure = v;
    notifyListeners();
  }

  Future<void> setNotificationPrefs({
    bool? daily,
    bool? weekly,
    bool? reminders,
  }) async {
    dailyDigest = daily ?? dailyDigest;
    weeklyReport = weekly ?? weeklyReport;
    unreadReminders = reminders ?? unreadReminders;
    await _savePreferences();
    await _syncLearningReminders();
    FirebaseUsageAnalytics.instance.notificationFeatureUsed();
    notifyListeners();
  }

  Future<void> setReminderTime({
    int? morningMinutes,
    int? eveningMinutes,
  }) async {
    morningReminderMinutes = morningMinutes ?? morningReminderMinutes;
    eveningReminderMinutes = eveningMinutes ?? eveningReminderMinutes;
    await _savePreferences();
    await _syncLearningReminders();
    FirebaseUsageAnalytics.instance.notificationFeatureUsed();
    notifyListeners();
  }

  Future<void> _syncLearningReminders({bool requestPermission = false}) async {
    await _notificationService?.configureLearningReminders(
      morningEnabled: dailyDigest,
      eveningEnabled: unreadReminders,
      weeklyEnabled: weeklyReport,
      morningMinutes: morningReminderMinutes,
      eveningMinutes: eveningReminderMinutes,
      userName: userName,
      requestPermission: requestPermission,
    );
  }

  Future<bool> enableAndTestNotifications() async {
    final enabled =
        await _notificationService?.enableAndTestLearningReminders(
          morningEnabled: dailyDigest,
          eveningEnabled: unreadReminders,
          weeklyEnabled: weeklyReport,
          morningMinutes: morningReminderMinutes,
          eveningMinutes: eveningReminderMinutes,
          userName: userName,
        ) ??
        false;
    if (enabled) notifyListeners();
    return enabled;
  }

  Future<void> setProfile(String name, [String? email]) async {
    userName = name;
    if (email != null) userEmail = email;
    await _savePreferences();
    await _syncLearningReminders();
    notifyListeners();
  }

  Future<void> setUserAvatar(String? path) async {
    userAvatarPath = path;
    await _savePreferences();
    notifyListeners();
  }

  void clearOfflineFiles() {
    cachedBytes = 0;
    notifyListeners();
  }

  Future<void> markBackedUp() async {
    lastBackupAt = DateTime.now();
    await _savePreferences();
    notifyListeners();
  }

  // ------------------------------------------------------------------ queries
  int get inboxCount => items.length;
  int get unreadCount =>
      items.where((e) => e.status == ResourceStatus.unread).length;
  int get unreadNotificationCount => notifications.where((n) => !n.read).length;

  List<ResourceItem> get continueLearning {
    final list =
        items.where((e) => e.status == ResourceStatus.inProgress).toList()
          ..sort(
            (a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(
              a.lastOpenedAt ?? a.addedAt,
            ),
          );
    return list;
  }

  List<ResourceItem> get recentSaves {
    final list = [...items]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  List<ResourceItem> get favorites => items.where((e) => e.favorite).toList();

  List<ResourceItem> byCollection(String id) =>
      items.where((e) => e.collectionId == id).toList();

  Set<String> get allTags {
    final s = <String>{};
    for (final e in items) {
      s.addAll(e.tags);
    }
    return s;
  }

  ResourceItem? find(String id) => items.where((e) => e.id == id).firstOrNull;

  ResourceItem? findByUrl(String url) {
    final clean = UrlNormalizer.normalize(url);
    if (clean.isEmpty) return null;
    return items
        .where((e) => UrlNormalizer.normalize(e.url) == clean)
        .firstOrNull;
  }

  List<ResourceItem> search(
    SearchFilters f, {
    SortOrder sort = SortOrder.newest,
  }) {
    Iterable<ResourceItem> result = items;
    if (f.query.trim().isNotEmpty) {
      final q = f.query.trim().toLowerCase();
      result = result.where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.source.toLowerCase().contains(q) ||
            e.tags.any((t) => t.toLowerCase().contains(q)),
      );
    }
    if (f.status != null) result = result.where((e) => e.status == f.status);
    if (f.kind != null) result = result.where((e) => e.kind == f.kind);
    if (f.collectionId != null) {
      result = result.where((e) => e.collectionId == f.collectionId);
    }
    if (f.tag != null) result = result.where((e) => e.tags.contains(f.tag));
    if (f.favoritesOnly) result = result.where((e) => e.favorite);

    final list = result.toList();
    switch (sort) {
      case SortOrder.newest:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortOrder.oldest:
        list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      case SortOrder.titleAZ:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SortOrder.recentlyOpened:
        list.sort(
          (a, b) => (b.lastOpenedAt ?? DateTime(2000)).compareTo(
            a.lastOpenedAt ?? DateTime(2000),
          ),
        );
    }
    return list;
  }

  // ------------------------------------------------------------------ mutations
  Future<ResourceItem> add({
    required String title,
    required String source,
    required String url,
    required ResourceKind kind,
    String? collectionId,
    Set<String>? tags,
    String? noteTitle,
    String? notes,
    bool fetchMetadata = false,
  }) async {
    final id = newId();
    final normalized = UrlNormalizer.normalize(url);
    final domain = source.isNotEmpty
        ? source
        : UrlNormalizer.extractDomain(url);
    final displayTitle = title.isNotEmpty
        ? title
        : (domain.isNotEmpty ? domain : 'Untitled Resource');
    final actualNote = notes ?? (kind == ResourceKind.note ? title : '');
    final actualNoteTitle =
        noteTitle?.trim() ?? (kind == ResourceKind.note ? displayTitle : '');

    final item = ResourceItem(
      id: id,
      title: displayTitle,
      source: domain,
      url: url,
      kind: kind,
      collectionId: collectionId,
      tags: tags ?? {},
      fetching: fetchMetadata,
      status: ResourceStatus.unread,
      accent: Random().nextInt(6),
      noteTitle: actualNoteTitle,
      note: actualNote,
    );
    items.insert(0, item);
    notifyListeners();

    // Persist to SQLite
    if (_resourceDao != null) {
      await _resourceDao!.insertResource(
        ResourcesCompanion(
          id: Value(id),
          title: Value(displayTitle),
          url: Value(url),
          normalizedUrl: Value(normalized),
          resourceType: Value(kind.name),
          source: Value(domain),
          collectionId: Value(collectionId),
          noteTitle: Value(actualNoteTitle),
          notes: Value(actualNote),
          minutes: Value(item.minutes),
          accent: Value(item.accent),
          isFavorite: const Value(false),
          status: const Value('unread'),
          createdAt: Value(item.addedAt),
        ),
      );
      if (tags != null && tags.isNotEmpty && _tagDao != null) {
        await _tagDao!.setTagsForResource(id, tags);
      }
      await _searchDao?.syncResource(id);
    }

    _analyticsService?.trackResourceAdded(id, source: domain);
    FirebaseUsageAnalytics.instance.resourceCreated();
    addNotification(
      title: kind == ResourceKind.note ? 'New note saved' : 'New source saved',
      body: '“$displayTitle” is ready whenever you are.',
      icon: kind == ResourceKind.note
          ? Icons.sticky_note_2_outlined
          : Icons.bookmark_added_outlined,
      resourceId: id,
    );

    if (fetchMetadata) _resolveMetadata(item);
    return item;
  }

  Future<void> _resolveMetadata(ResourceItem item) async {
    if (!item.fetching) return;
    if (offlineDemo) {
      item.fetching = false;
      notifyListeners();
      return;
    }

    try {
      final meta = await MetadataService.instance.fetchMetadata(item.url);
      item.fetching = false;

      // User Data Priority: Only overwrite title if it was automatically generated from URL/domain
      final cleanUrl = UrlNormalizer.normalize(item.url);
      final isAutoTitle =
          item.title.startsWith('http://') ||
          item.title.startsWith('https://') ||
          item.title.isEmpty ||
          item.title == 'Untitled Resource' ||
          item.title == cleanUrl ||
          item.title == item.url ||
          item.title == UrlNormalizer.extractDomain(item.url);

      if (isAutoTitle && meta.title != null && meta.title!.trim().isNotEmpty) {
        item.title = meta.title!.trim();
      }

      if (meta.siteName != null && meta.siteName!.trim().isNotEmpty) {
        item.source = meta.siteName!.trim();
      }

      notifyListeners();

      if (_resourceDao != null) {
        await _resourceDao!.updateResource(
          item.id,
          ResourcesCompanion(
            title: Value(item.title),
            source: Value(item.source),
            notes: meta.description != null && item.note.isEmpty
                ? Value(meta.description!)
                : const Value.absent(),
          ),
        );
        await _searchDao?.syncResource(item.id);
      }
    } catch (_) {
      item.fetching = false;
      notifyListeners();
    }
  }

  void retryMetadata(ResourceItem item) {
    item.fetching = true;
    notifyListeners();
    _resolveMetadata(item);
  }

  Future<void> toggleFavorite(String id) async {
    final e = find(id);
    if (e == null) return;
    e.favorite = !e.favorite;
    notifyListeners();

    await _resourceDao?.toggleFavorite(id, e.favorite);
    _analyticsService?.trackFavoriteChanged(id, e.favorite);
    FirebaseUsageAnalytics.instance.favoriteChanged();
  }

  Future<void> setFavorite(String id, bool value) async {
    final e = find(id);
    if (e == null) return;
    e.favorite = value;
    notifyListeners();

    await _resourceDao?.toggleFavorite(id, value);
    _analyticsService?.trackFavoriteChanged(id, value);
    FirebaseUsageAnalytics.instance.favoriteChanged();
  }

  Future<void> setStatus(String id, ResourceStatus status) async {
    final e = find(id);
    if (e == null) return;
    final oldStatus = e.status.name;
    e.status = status;
    notifyListeners();

    await _resourceDao?.setStatus(id, status.name);

    if (status == ResourceStatus.completed) {
      _analyticsService?.trackResourceCompleted(id);
    } else {
      _analyticsService?.trackResourceStatusChanged(id, oldStatus, status.name);
    }
  }

  Future<void> moveTo(String id, String? collectionId) async {
    final e = find(id);
    if (e == null) return;
    final oldCol = e.collectionId;
    e.collectionId = collectionId;
    notifyListeners();

    await _resourceDao?.moveToCollection(id, collectionId);
    await _searchDao?.syncResource(id);

    _analyticsService?.trackResourceMoved(id, oldCol, collectionId);
  }

  Future<void> addTag(String id, String tag) async {
    final e = find(id);
    final clean = tag.trim().toLowerCase();
    if (e == null || clean.isEmpty) return;
    e.tags.add(clean);
    notifyListeners();

    await _tagDao?.addTagToResource(id, clean);
    await _searchDao?.syncResource(id);
  }

  Future<void> removeTag(String id, String tag) async {
    final e = find(id);
    if (e == null) return;
    final clean = tag.trim().toLowerCase();
    e.tags.remove(clean);
    notifyListeners();

    await _tagDao?.removeTagFromResource(id, clean);
    await _searchDao?.syncResource(id);
  }

  Future<void> saveNote(String id, String note, {String? title}) async {
    final e = find(id);
    if (e == null) return;
    e.note = note;
    if (title != null) e.noteTitle = title;
    notifyListeners();

    await _resourceDao?.updateNotes(id, note, noteTitle: title);
    await _searchDao?.syncResource(id);

    _analyticsService?.trackNoteSaved(id);
    FirebaseUsageAnalytics.instance.noteSaved();
  }

  /// Opens the viewer: records the open, promotes Unread → In progress.
  Future<void> registerOpen(String id) async {
    final e = find(id);
    if (e == null) return;
    e.openCount += 1;
    e.lastOpenedAt = DateTime.now();
    if (e.status == ResourceStatus.unread) e.status = ResourceStatus.inProgress;
    notifyListeners();

    await _resourceDao?.registerOpen(id);
    _analyticsService?.trackResourceOpened(id);
    FirebaseUsageAnalytics.instance.resourceOpened();
  }

  Future<void> renameResource(String id, String newTitle) async {
    final clean = newTitle.trim();
    if (clean.isEmpty) return;
    final e = find(id);
    if (e == null) return;
    e.title = clean;
    notifyListeners();

    if (_resourceDao != null) {
      await _resourceDao!.updateResource(
        id,
        ResourcesCompanion(
          title: Value(clean),
        ),
      );
      await _searchDao?.syncResource(id);
    }
  }

  void readNotification(VaultNotification n) {
    n.read = true;
    _saveNotifications();
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    _saveNotifications();
    notifyListeners();
  }

  void deleteNotification(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final n = notifications.removeAt(idx);
      _dismissedNotificationKeys.add('${n.title}|||${n.body}');
      _dismissedNotificationKeys.add(n.id);
      _saveNotifications();
      _notificationService?.cancel(n.id.hashCode);
      notifyListeners();
    }
  }

  void clearAllNotifications() {
    for (final n in notifications) {
      _dismissedNotificationKeys.add('${n.title}|||${n.body}');
      _dismissedNotificationKeys.add(n.id);
    }
    notifications.clear();
    _saveNotifications();
    _notificationService?.cancelAllNotifications();
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String body,
    IconData icon = Icons.notifications_outlined,
    bool pushLocal = true,
    String? resourceId,
  }) {
    _dismissedNotificationKeys.remove('$title|||$body');
    // Avoid duplicate identical unread notification if already at top or recent
    final alreadyExists = notifications.any(
      (n) => n.title == title && n.body == body && !n.read,
    );
    if (alreadyExists) return;

    final notif = VaultNotification(
      id: 'n_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      icon: icon,
      resourceId: resourceId,
      read: false,
    );
    notifications.insert(0, notif);
    if (notifications.length > 50) notifications.removeLast();
    _saveNotifications();
    notifyListeners();

    if (pushLocal) {
      _notificationService?.showNotification(
        id: notif.id.hashCode,
        title: title,
        body: body,
      );
    }
  }

  void clearNotifications() {
    clearAllNotifications();
  }

  static int _idCounter = 0;
  String newId() => 'r${DateTime.now().microsecondsSinceEpoch}_${++_idCounter}';

  bool isDuplicateUrl(String url) => findByUrl(url) != null;

  // ---- search (FTS5) ----------------------------------------------------
  Future<List<ResourceItem>> searchAsync(
    SearchFilters f, {
    SortOrder sort = SortOrder.newest,
    int limit = 50,
  }) async {
    if (f.query.trim().isNotEmpty) {
      _analyticsService?.trackSearch(
        queryLength: f.query.trim().length,
        hasFilters: f.isActive,
      );
      FirebaseUsageAnalytics.instance.searchUsed();
    }
    if (_searchRepo != null) {
      return _searchRepo!.search(filters: f, sort: sort, limit: limit);
    }
    return search(f, sort: sort);
  }

  // ---- file management --------------------------------------------------
  Future<FileItem?> attachFile(
    String resourceId,
    String sourcePath,
    String fileName,
  ) async {
    final e = find(resourceId);
    if (_fileRepo != null) {
      final fileItem = await _fileRepo!.saveAndAttachFile(
        resourceId: resourceId,
        sourcePath: sourcePath,
        fileName: fileName,
      );
      if (e != null) {
        e.localFile = fileItem;
        notifyListeners();
      }

      _analyticsService?.trackFileAttached(resourceId, fileName);
      return fileItem;
    }
    return null;
  }

  Future<void> removeFile(String resourceId) async {
    final e = find(resourceId);
    if (_fileRepo != null) {
      await _fileRepo!.deleteFilesForResource(resourceId);
      if (e != null) {
        e.localFile = null;
        notifyListeners();
      }
    }
  }

  // ---- trash ------------------------------------------------------------
  Future<void> delete(String id) async {
    final e = find(id);
    if (e == null) return;
    items.remove(e);
    trash.insert(0, TrashEntry(item: e, deletedAt: DateTime.now()));
    notifyListeners();

    await _resourceDao?.softDelete(id);
    _analyticsService?.trackResourceDeleted(id);
    FirebaseUsageAnalytics.instance.resourceDeleted();
  }

  Future<void> restore(String id) async {
    final t = trash.where((t) => t.item.id == id).firstOrNull;
    if (t == null) return;
    trash.remove(t);
    items.insert(0, t.item);
    notifyListeners();

    await _resourceDao?.restore(id);
    _analyticsService?.trackResourceRestored(id);
  }

  Future<void> deletePermanent(String id) async {
    final t = trash.where((t) => t.item.id == id).firstOrNull;
    final fileLocalPath = t?.item.localFile?.localPath;
    if (fileLocalPath != null && _fileStorageService != null) {
      await _fileStorageService!.deletePhysicalFile(fileLocalPath);
    }
    if (_fileDao != null) {
      await _fileDao!.deleteFilesForResource(id);
    }

    trash.removeWhere((t) => t.item.id == id);
    notifyListeners();

    await _resourceDao?.permanentDelete(id);
    await _searchDao?.deleteFromIndex(id);
  }

  Future<void> emptyTrash() async {
    for (final t in trash) {
      final fileLocalPath = t.item.localFile?.localPath;
      if (fileLocalPath != null && _fileStorageService != null) {
        await _fileStorageService!.deletePhysicalFile(fileLocalPath);
      }
      if (_fileDao != null) {
        await _fileDao!.deleteFilesForResource(t.item.id);
      }
    }

    trash.clear();
    notifyListeners();

    await _resourceDao?.emptyTrash();
    await _searchDao?.rebuildIndex();
  }

  // ---- collections ------------------------------------------------------
  Future<CollectionModel> addCollection(
    String name, {
    String emoji = '📚',
    int? accent,
    String? parentId,
  }) async {
    final c = CollectionModel(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      accent: accent ?? Random().nextInt(6),
      parentId: parentId,
    );
    collections.add(c);
    notifyListeners();

    if (_collectionDao != null) {
      await _collectionDao!.insertCollection(
        CollectionsCompanion(
          id: Value(c.id),
          name: Value(c.name),
          emoji: Value(c.emoji),
          accent: Value(c.accent),
          parentId: Value(c.parentId),
          createdAt: Value(c.createdAt),
        ),
      );
    }
    _analyticsService?.trackCollectionCreated(c.id);
    FirebaseUsageAnalytics.instance.collectionCreated();
    return c;
  }

  Future<void> renameCollection(
    String id,
    String name, {
    String? emoji,
    int? accent,
    String? parentId,
  }) async {
    final c = collections.where((c) => c.id == id).firstOrNull;
    if (c == null) return;
    c.name = name;
    if (emoji != null) c.emoji = emoji;
    if (accent != null) c.accent = accent;
    if (parentId != null) c.parentId = parentId.isEmpty ? null : parentId;
    notifyListeners();

    await _collectionDao?.updateCollection(
      id,
      name: name,
      emoji: emoji,
      accent: accent,
      parentId: parentId != null ? (parentId.isEmpty ? null : parentId) : null,
    );
    await _searchDao?.syncCollectionResources(id);
  }

  Future<void> deleteCollection(String id) async {
    final deleted = collections.where((c) => c.id == id).firstOrNull;
    for (final child in subCollections(id)) {
      child.parentId = deleted?.parentId;
      await _collectionDao?.updateCollection(child.id, parentId: child.parentId);
    }
    collections.removeWhere((c) => c.id == id);
    for (final e in items.where((e) => e.collectionId == id)) {
      e.collectionId = null;
    }
    notifyListeners();
    await _collectionDao?.deleteCollection(id);
    await _searchDao?.syncCollectionResources(id);
    _analyticsService?.trackCollectionDeleted(id);
  }

  Future<StickyItemModel?> addStickyItem(
    String noteId,
    String text, {
    bool isBullet = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    if (_stickyNoteRepo != null) {
      final item = await _stickyNoteRepo!.addItem(
        noteId,
        clean,
        isBullet: isBullet,
      );
      final note = stickyNotes.where((n) => n.id == noteId).firstOrNull;
      if (note != null) {
        note.items.add(item);
        notifyListeners();
      }
      return item;
    }
    return null;
  }

  // ---- sticky notes & tasks --------------------------------------------
  Future<String> addStickyNote({
    required String title,
    required Color color,
    required List<String> items,
    bool isBullet = false,
  }) async {
    if (_stickyNoteRepo == null) return '';
    final id = await _stickyNoteRepo!.createNote(
      title: title,
      color: color,
      items: items,
      isBullet: isBullet,
    );
    final updatedList = await _stickyNoteRepo!.getNotes();
    stickyNotes.clear();
    stickyNotes.addAll(updatedList);
    notifyListeners();

    _analyticsService?.trackStickyNoteAdded(id);
    return id;
  }

  Future<void> updateStickyItemState(
    String noteId,
    String itemId,
    NotedCheckState state,
  ) async {
    final note = stickyNotes.where((n) => n.id == noteId).firstOrNull;
    final item = note?.items.where((it) => it.id == itemId).firstOrNull;
    if (item != null) {
      item.state = state;
      notifyListeners();
    }
    await _stickyNoteRepo?.updateItemState(itemId, state);
    _analyticsService?.trackStickyItemStateChanged(noteId, itemId, state.name);
  }

  Future<void> deleteStickyItem(String noteId, String itemId) async {
    final note = stickyNotes.where((n) => n.id == noteId).firstOrNull;
    if (note != null) {
      note.items.removeWhere((it) => it.id == itemId);
      notifyListeners();
    }
    await _stickyNoteRepo?.deleteItem(itemId);
  }

  Future<void> deleteStickyNote(String noteId) async {
    stickyNotes.removeWhere((n) => n.id == noteId);
    notifyListeners();
    await _stickyNoteRepo?.deleteNote(noteId);
  }

  // ---- search history ---------------------------------------------------
  void pushRecentSearch(String q) {
    final clean = q.trim();
    if (clean.isEmpty) return;
    recentSearches.remove(clean);
    recentSearches.insert(0, clean);
    if (recentSearches.length > 8) recentSearches.removeLast();
    notifyListeners();
  }

  void clearSearchHistory() {
    recentSearches.clear();
    notifyListeners();
  }

  // ---- backup -----------------------------------------------------------
  Future<BackupResult> exportBackupZip({
    String? customOutputDir,
    String? customFileName,
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_backupService == null) {
      throw StateError('Vault has not been initialized with BackupService.');
    }
    final result = await _backupService!.exportBackup(
      customOutputDir: customOutputDir,
      customFileName: customFileName,
      onProgress: onProgress,
    );
    await markBackedUp();
    FirebaseUsageAnalytics.instance.backupCreated();
    return result;
  }

  Future<RestoreResult> restoreBackupZip(
    String zipFilePath, {
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_restoreService == null) {
      throw StateError('Vault has not been initialized with RestoreService.');
    }
    final result = await _restoreService!.restoreBackup(
      zipFilePath,
      onProgress: onProgress,
    );
    await reloadFromDb();
    await markBackedUp();
    FirebaseUsageAnalytics.instance.backupRestored();
    return result;
  }

  Future<RestoreValidationResult> validateBackupZip(String zipFilePath) async {
    if (_restoreService == null) {
      throw StateError('Vault has not been initialized with RestoreService.');
    }
    return _restoreService!.validateBackup(zipFilePath);
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'SkillNest',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'collections': collections
        .map((c) => {'id': c.id, 'name': c.name, 'emoji': c.emoji})
        .toList(),
    'resources': items
        .map(
          (e) => {
            'title': e.title,
            'source': e.source,
            'url': e.url,
            'kind': e.kind.name,
            'status': e.status.name,
            'favorite': e.favorite,
            'collection': e.collectionId,
            'tags': e.tags.toList(),
            'note': e.note,
          },
        )
        .toList(),
  });

  // ------------------------------------------------------------------ analytics
  AnalyticsSnapshot analytics({int days = 30, String? collectionId}) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    bool inRange(DateTime d) =>
        !d.isBefore(from) && d.isBefore(now.add(const Duration(days: 1)));
    Iterable<ResourceItem> pool = items;
    if (collectionId != null) {
      pool = pool.where((e) => e.collectionId == collectionId);
    }

    final saved = pool.where((e) => inRange(e.addedAt)).length;
    final opened = pool.where((e) => e.openCount > 0).length;
    final completed = pool
        .where((e) => e.status == ResourceStatus.completed)
        .length;
    final inProgress = pool
        .where((e) => e.status == ResourceStatus.inProgress)
        .length;
    final unread = pool.where((e) => e.status == ResourceStatus.unread).length;
    final neverOpened = pool.where((e) => e.neverOpened).length;
    final reopened = pool.where((e) => e.reopened).length;
    final completionRate = pool.isEmpty ? 0.0 : completed / pool.length;

    final bySource = <String, int>{};
    for (final e in pool) {
      final key = e.source.isEmpty ? 'note' : e.source;
      bySource[key] = (bySource[key] ?? 0) + 1;
    }

    final byDay = List<int>.filled(min(days, 14), 0);
    final completedByDay = List<int>.filled(min(days, 14), 0);
    final dayMs = Duration(days: days).inMilliseconds / byDay.length;
    for (final e in pool) {
      final idx = ((now.difference(e.addedAt).inMilliseconds) / dayMs).floor();
      if (idx >= 0 && idx < byDay.length) byDay[idx]++;
      if (e.status == ResourceStatus.completed) {
        final cIdx =
            ((now.difference(e.lastOpenedAt ?? e.addedAt).inMilliseconds) /
                    dayMs)
                .floor();
        if (cIdx >= 0 && cIdx < completedByDay.length) completedByDay[cIdx]++;
      }
    }

    return AnalyticsSnapshot(
      saved: saved,
      opened: opened,
      completed: completed,
      completionRate: completionRate,
      inProgress: inProgress,
      unread: unread,
      neverOpened: neverOpened,
      reopened: reopened,
      bySource: bySource,
      activityByDay: byDay,
      completedByDay: completedByDay,
    );
  }

  Future<AnalyticsSnapshot> analyticsAsync({
    int days = 30,
    String? collectionId,
  }) async {
    if (_analyticsRepo != null) {
      return _analyticsRepo!.getAnalytics(
        days: days,
        collectionId: collectionId,
        activeResources: items,
      );
    }
    return analytics(days: days, collectionId: collectionId);
  }
}

class AnalyticsSnapshot {
  final int saved;
  final int opened;
  final int completed;
  final double completionRate;
  final int inProgress;
  final int unread;
  final int neverOpened;
  final int reopened;
  final Map<String, int> bySource;
  final List<int> activityByDay;
  final List<int> completedByDay;

  AnalyticsSnapshot({
    required this.saved,
    required this.opened,
    required this.completed,
    required this.completionRate,
    required this.inProgress,
    required this.unread,
    required this.neverOpened,
    required this.reopened,
    required this.bySource,
    required this.activityByDay,
    required this.completedByDay,
  });
}
