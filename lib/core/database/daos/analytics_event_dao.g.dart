// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event_dao.dart';

// ignore_for_file: type=lint
mixin _$AnalyticsEventDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnalyticsEventsTable get analyticsEvents => attachedDatabase.analyticsEvents;
  $ResourcesTable get resources => attachedDatabase.resources;
  AnalyticsEventDaoManager get managers => AnalyticsEventDaoManager(this);
}

class AnalyticsEventDaoManager {
  final _$AnalyticsEventDaoMixin _db;
  AnalyticsEventDaoManager(this._db);
  $$AnalyticsEventsTableTableManager get analyticsEvents =>
      $$AnalyticsEventsTableTableManager(
        _db.attachedDatabase,
        _db.analyticsEvents,
      );
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db.attachedDatabase, _db.resources);
}
