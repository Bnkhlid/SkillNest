// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_dao.dart';

// ignore_for_file: type=lint
mixin _$FileDaoMixin on DatabaseAccessor<AppDatabase> {
  $FilesTable get files => attachedDatabase.files;
  FileDaoManager get managers => FileDaoManager(this);
}

class FileDaoManager {
  final _$FileDaoMixin _db;
  FileDaoManager(this._db);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
}
