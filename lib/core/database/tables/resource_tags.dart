import 'package:drift/drift.dart';
import 'resources.dart';
import 'tags.dart';

@DataClassName('ResourceTagEntry')
class ResourceTags extends Table {
  TextColumn get resourceId => text().references(Resources, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {resourceId, tagId};
}
