import 'package:drift/drift.dart';
import 'resources.dart';

@DataClassName('FileEntry')
@TableIndex(name: 'files_resource_id_idx', columns: {#resourceId})
class Files extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId =>
      text().references(Resources, #id, onDelete: KeyAction.cascade)();
  TextColumn get localPath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
