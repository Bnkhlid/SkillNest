// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sticky_note_dao.dart';

// ignore_for_file: type=lint
mixin _$StickyNoteDaoMixin on DatabaseAccessor<AppDatabase> {
  $StickyNotesTable get stickyNotes => attachedDatabase.stickyNotes;
  $StickyItemsTable get stickyItems => attachedDatabase.stickyItems;
  StickyNoteDaoManager get managers => StickyNoteDaoManager(this);
}

class StickyNoteDaoManager {
  final _$StickyNoteDaoMixin _db;
  StickyNoteDaoManager(this._db);
  $$StickyNotesTableTableManager get stickyNotes =>
      $$StickyNotesTableTableManager(_db.attachedDatabase, _db.stickyNotes);
  $$StickyItemsTableTableManager get stickyItems =>
      $$StickyItemsTableTableManager(_db.attachedDatabase, _db.stickyItems);
}
