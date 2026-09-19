import 'package:drift/drift.dart';
import 'collections.dart';

@DataClassName('ResourceEntry')
@TableIndex(name: 'resource_normalized_url_idx', columns: {#normalizedUrl})
@TableIndex(name: 'resource_collection_id_idx', columns: {#collectionId})
@TableIndex(name: 'resource_status_idx', columns: {#status})
@TableIndex(name: 'resource_deleted_at_idx', columns: {#deletedAt})
class Resources extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId => text().nullable().references(
    Collections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get normalizedUrl => text().withDefault(const Constant(''))();
  TextColumn get resourceType =>
      text().withDefault(const Constant('article'))();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  // Optional heading for the resource's own note. The note body remains in
  // `notes`, keeping URL resources and their notes in one durable record.
  TextColumn get noteTitle => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('unread'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get openCount => integer().withDefault(const Constant(0))();
  IntColumn get minutes => integer().withDefault(const Constant(6))();
  BoolColumn get fetching => boolean().withDefault(const Constant(false))();
  IntColumn get accent => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
