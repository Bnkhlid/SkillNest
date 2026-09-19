import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/analytics_events.dart';
import '../tables/resources.dart';

part 'analytics_event_dao.g.dart';

@DriftAccessor(tables: [AnalyticsEvents, Resources])
class AnalyticsEventDao extends DatabaseAccessor<AppDatabase>
    with _$AnalyticsEventDaoMixin {
  AnalyticsEventDao(super.db);

  Future<int> insertEvent(AnalyticsEventsCompanion event) {
    return into(analyticsEvents).insert(event);
  }

  Future<int> insertRawEvent(AnalyticsEventEntry event) {
    return into(analyticsEvents).insert(event, mode: InsertMode.insertOrReplace);
  }

  Future<void> insertEvents(List<AnalyticsEventsCompanion> events) async {
    await batch((b) {
      b.insertAll(analyticsEvents, events);
    });
  }

  Future<List<AnalyticsEventEntry>> getAllEventsRaw() {
    return (select(analyticsEvents)
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
  }

  Future<int> deleteAllEvents() {
    return delete(analyticsEvents).go();
  }

  Future<List<AnalyticsEventEntry>> getEvents({
    DateTime? from,
    DateTime? to,
    String? eventType,
    String? resourceId,
    int? limit,
  }) {
    final query = select(analyticsEvents);
    if (from != null) {
      query.where((e) => e.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((e) => e.occurredAt.isSmallerOrEqualValue(to));
    }
    if (eventType != null) {
      query.where((e) => e.eventType.equals(eventType));
    }
    if (resourceId != null) {
      query.where((e) => e.resourceId.equals(resourceId));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.occurredAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<List<AnalyticsEventEntry>> getEventsByDateRange(DateTime from, DateTime to) {
    return (select(analyticsEvents)
          ..where((e) =>
              e.occurredAt.isBiggerOrEqualValue(from) &
              e.occurredAt.isSmallerOrEqualValue(to))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
  }

  Future<List<AnalyticsEventEntry>> getEventsByType(String eventType) {
    return (select(analyticsEvents)
          ..where((e) => e.eventType.equals(eventType))
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
        .get();
  }

  Future<int> countEvents({
    DateTime? from,
    DateTime? to,
    String? eventType,
    String? resourceId,
  }) async {
    final countExp = analyticsEvents.id.count();
    final query = selectOnly(analyticsEvents)..addColumns([countExp]);
    if (from != null) {
      query.where(analyticsEvents.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(analyticsEvents.occurredAt.isSmallerOrEqualValue(to));
    }
    if (eventType != null) {
      query.where(analyticsEvents.eventType.equals(eventType));
    }
    if (resourceId != null) {
      query.where(analyticsEvents.resourceId.equals(resourceId));
    }
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> deleteEventsBefore(DateTime cutoff) {
    return (delete(analyticsEvents)
          ..where((e) => e.occurredAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
