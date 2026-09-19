import 'package:drift/drift.dart';
import 'sticky_notes.dart';

@DataClassName('StickyItemEntry')
class StickyItems extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().references(StickyNotes, #id, onDelete: KeyAction.cascade)();
  TextColumn get textContent => text().withDefault(const Constant(''))();
  TextColumn get state => text().withDefault(const Constant('unchecked'))();
  BoolColumn get isBullet => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
