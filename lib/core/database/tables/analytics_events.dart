import 'package:drift/drift.dart';

@DataClassName('AnalyticsEventEntry')
@TableIndex(name: 'analytics_events_occurred_at_idx', columns: {#occurredAt})
@TableIndex(name: 'analytics_events_resource_id_idx', columns: {#resourceId})
@TableIndex(name: 'analytics_events_type_idx', columns: {#eventType})
class AnalyticsEvents extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId =>
      text().nullable().customConstraint('REFERENCES resources(id) ON DELETE SET NULL')();
  TextColumn get eventType => text()();
  DateTimeColumn get occurredAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadataJson => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get progressPercent => real().nullable()();
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
