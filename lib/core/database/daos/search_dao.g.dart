// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_dao.dart';

// ignore_for_file: type=lint
mixin _$SearchDaoMixin on DatabaseAccessor<AppDatabase> {
  $ResourcesTable get resources => attachedDatabase.resources;
  $CollectionsTable get collections => attachedDatabase.collections;
  $TagsTable get tags => attachedDatabase.tags;
  $ResourceTagsTable get resourceTags => attachedDatabase.resourceTags;
  $FilesTable get files => attachedDatabase.files;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db.attachedDatabase, _db.resources);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$ResourceTagsTableTableManager get resourceTags =>
      $$ResourceTagsTableTableManager(_db.attachedDatabase, _db.resourceTags);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
}
