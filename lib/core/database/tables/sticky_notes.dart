import 'package:drift/drift.dart';

@DataClassName('StickyNoteEntry')
class StickyNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFFFDF6E2))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
