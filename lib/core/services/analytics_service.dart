import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/analytics_event_dao.dart';
import '../models/analytics_event.dart';

class AnalyticsService {
  final AnalyticsEventDao _dao;
  static const _uuid = Uuid();

  AnalyticsService(this._dao);

  /// Low-level safe event dispatch
  Future<void> track({
    required AnalyticsEventType eventType,
    String? resourceId,
    Map<String, dynamic>? metadata,
    int? durationSeconds,
    double? progressPercent,
    String? source,
    DateTime? occurredAt,
  }) async {
    try {
      final eventId = 'ev_${_uuid.v4()}';
      final metaJson = metadata != null ? jsonEncode(metadata) : null;
      await _dao.insertEvent(
        AnalyticsEventsCompanion(
          id: Value(eventId),
          resourceId: Value(resourceId),
          eventType: Value(eventType.value),
          occurredAt: Value(occurredAt ?? DateTime.now()),
          metadataJson: Value(metaJson),
          durationSeconds: Value(durationSeconds),
          progressPercent: Value(progressPercent),
          source: Value(source),
        ),
      );
    } catch (_) {
      // Analytics must never crash or block primary user workflows
    }
  }

  Future<void> trackResourceAdded(String resourceId, {String? source}) => track(
        eventType: AnalyticsEventType.resourceAdded,
        resourceId: resourceId,
        source: source,
      );

  Future<void> trackResourceDeleted(String resourceId) => track(
        eventType: AnalyticsEventType.resourceDeleted,
        resourceId: resourceId,
      );

  Future<void> trackResourceRestored(String resourceId) => track(
        eventType: AnalyticsEventType.resourceRestored,
        resourceId: resourceId,
      );

  Future<void> trackResourceOpened(
    String resourceId, {
    int? durationSeconds,
    double? progressPercent,
    String? source,
  }) =>
      track(
        eventType: AnalyticsEventType.resourceOpened,
        resourceId: resourceId,
        durationSeconds: durationSeconds,
        progressPercent: progressPercent,
        source: source,
      );

  Future<void> trackResourceCompleted(String resourceId) => track(
        eventType: AnalyticsEventType.resourceCompleted,
        resourceId: resourceId,
      );

  Future<void> trackResourceStatusChanged(
    String resourceId,
    String oldStatus,
    String newStatus,
  ) =>
      track(
        eventType: AnalyticsEventType.resourceStatusChanged,
        resourceId: resourceId,
        metadata: {'oldStatus': oldStatus, 'newStatus': newStatus},
      );

  Future<void> trackFavoriteChanged(String resourceId, bool isFavorite) =>
      track(
        eventType: AnalyticsEventType.favoriteChanged,
        resourceId: resourceId,
        metadata: {'favorite': isFavorite},
      );

  Future<void> trackNoteSaved(String resourceId) => track(
        eventType: AnalyticsEventType.noteSaved,
        resourceId: resourceId,
      );

  Future<void> trackResourceMoved(
    String resourceId,
    String? oldCollectionId,
    String? newCollectionId,
  ) =>
      track(
        eventType: AnalyticsEventType.resourceMoved,
        resourceId: resourceId,
        metadata: {
          'oldCollectionId': oldCollectionId,
          'newCollectionId': newCollectionId,
        },
      );

  Future<void> trackStickyNoteAdded(String noteId) => track(
        eventType: AnalyticsEventType.stickyNoteAdded,
        metadata: {'noteId': noteId},
      );

  Future<void> trackStickyItemStateChanged(
    String noteId,
    String itemId,
    String state,
  ) =>
      track(
        eventType: AnalyticsEventType.stickyItemStateChanged,
        metadata: {'noteId': noteId, 'itemId': itemId, 'state': state},
      );

  Future<void> trackFileAttached(String resourceId, String fileName) => track(
        eventType: AnalyticsEventType.fileAttached,
        resourceId: resourceId,
        metadata: {'fileName': fileName},
      );

  Future<void> trackFileOpened(String resourceId, String fileName) => track(
        eventType: AnalyticsEventType.fileOpened,
        resourceId: resourceId,
        metadata: {'fileName': fileName},
      );

  Future<void> trackSearch({
    int queryLength = 0,
    int resultCount = 0,
    bool hasFilters = false,
  }) =>
      track(
        eventType: AnalyticsEventType.searchPerformed,
        metadata: {
          'queryLength': queryLength,
          'resultCount': resultCount,
          'hasFilters': hasFilters,
        },
      );

  Future<void> trackCollectionCreated(String collectionId) => track(
        eventType: AnalyticsEventType.collectionCreated,
        metadata: {'collectionId': collectionId},
      );

  Future<void> trackCollectionDeleted(String collectionId) => track(
        eventType: AnalyticsEventType.collectionDeleted,
        metadata: {'collectionId': collectionId},
      );
}
