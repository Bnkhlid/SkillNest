import 'dart:math';
import '../database/app_database.dart';
import '../database/daos/analytics_event_dao.dart';
import '../database/daos/resource_dao.dart';
import '../models/analytics_event.dart';
import '../../models.dart';
import '../../vault.dart' show AnalyticsSnapshot;

class AnalyticsRepository {
  final AnalyticsEventDao _eventDao;
  final ResourceDao? _resourceDao;

  AnalyticsRepository(this._eventDao, [this._resourceDao]);

  ResourceDao? get resourceDao => _resourceDao;

  /// Computes persistent analytics snapshot for the given date range and optional collection.
  Future<AnalyticsSnapshot> getAnalytics({
    int days = 30,
    String? collectionId,
    required List<ResourceItem> activeResources,
  }) async {
    final now = DateTime.now();
    final isAll = days == 0;
    final from = isAll
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : now.subtract(Duration(days: days));

    // Filter resource pool by collection
    Iterable<ResourceItem> pool = activeResources;
    if (collectionId != null && collectionId.isNotEmpty) {
      pool = pool.where((e) => e.collectionId == collectionId);
    }
    final poolList = pool.toList();

    // Query events in range
    final events = await _eventDao.getEvents(from: from, to: now);

    // Filter events by resources in collection if specified
    final poolIds = poolList.map((e) => e.id).toSet();
    final filteredEvents = collectionId != null && collectionId.isNotEmpty
        ? events.where((e) => e.resourceId != null && poolIds.contains(e.resourceId!)).toList()
        : events;

    // 1. Calculate KPIs
    final savedEvents = filteredEvents.where((e) => e.eventType == AnalyticsEventType.resourceAdded.value).length;
    final saved = savedEvents > 0
        ? savedEvents
        : poolList.where((e) => isAll || (e.addedAt.isAfter(from) && e.addedAt.isBefore(now.add(const Duration(days: 1))))).length;

    final opened = poolList.where((e) => e.openCount > 0).length;
    final completed = poolList.where((e) => e.status == ResourceStatus.completed).length;
    final inProgress = poolList.where((e) => e.status == ResourceStatus.inProgress).length;
    final unread = poolList.where((e) => e.status == ResourceStatus.unread).length;
    final neverOpened = poolList.where((e) => e.neverOpened).length;
    final reopened = poolList.where((e) => e.reopened).length;
    final completionRate = poolList.isEmpty ? 0.0 : completed / poolList.length;

    // 2. Sources breakdown
    final bySource = <String, int>{};
    for (final e in poolList) {
      final key = e.source.isEmpty ? 'note' : e.source;
      bySource[key] = (bySource[key] ?? 0) + 1;
    }

    // 3. Bucket calculations
    final effectiveDays = isAll ? 365 : max(days, 1);
    final bucketCount = min(effectiveDays, 14);
    final activityByDay = List<int>.filled(bucketCount, 0);
    final completedByDay = List<int>.filled(bucketCount, 0);

    final totalRangeMs = Duration(days: effectiveDays).inMilliseconds;
    final bucketMs = totalRangeMs / bucketCount;

    // Populate activity from events or resources
    for (final ev in filteredEvents) {
      if (ev.eventType == AnalyticsEventType.resourceAdded.value) {
        final diffMs = now.difference(ev.occurredAt).inMilliseconds;
        final idx = (diffMs / bucketMs).floor();
        if (idx >= 0 && idx < activityByDay.length) {
          activityByDay[idx]++;
        }
      } else if (ev.eventType == AnalyticsEventType.resourceCompleted.value) {
        final diffMs = now.difference(ev.occurredAt).inMilliseconds;
        final cIdx = (diffMs / bucketMs).floor();
        if (cIdx >= 0 && cIdx < completedByDay.length) {
          completedByDay[cIdx]++;
        }
      }
    }

    // Fallback if no specific events were recorded yet
    if (activityByDay.every((v) => v == 0)) {
      for (final e in poolList) {
        final idx = ((now.difference(e.addedAt).inMilliseconds) / bucketMs).floor();
        if (idx >= 0 && idx < activityByDay.length) {
          activityByDay[idx]++;
        }
      }
    }

    if (completedByDay.every((v) => v == 0)) {
      for (final e in poolList.where((e) => e.status == ResourceStatus.completed)) {
        final cIdx = ((now.difference(e.lastOpenedAt ?? e.addedAt).inMilliseconds) / bucketMs).floor();
        if (cIdx >= 0 && cIdx < completedByDay.length) {
          completedByDay[cIdx]++;
        }
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
      activityByDay: activityByDay,
      completedByDay: completedByDay,
    );
  }

  Future<int> countEvents({String? eventType, DateTime? from, DateTime? to}) {
    return _eventDao.countEvents(eventType: eventType, from: from, to: to);
  }

  Future<List<AnalyticsEventEntry>> getRawEvents({int? limit}) {
    return _eventDao.getEvents(limit: limit);
  }
}
