// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_dao.dart';

// ignore_for_file: type=lint
mixin _$ResourceDaoMixin on DatabaseAccessor<AppDatabase> {
  $ResourcesTable get resources => attachedDatabase.resources;
  $CollectionsTable get collections => attachedDatabase.collections;
  ResourceDaoManager get managers => ResourceDaoManager(this);
}

class ResourceDaoManager {
  final _$ResourceDaoMixin _db;
  ResourceDaoManager(this._db);
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db.attachedDatabase, _db.resources);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
}
