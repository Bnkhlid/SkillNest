import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sticky_items.dart';
import '../tables/sticky_notes.dart';

part 'sticky_note_dao.g.dart';

class StickyNoteWithItems {
  final StickyNoteEntry note;
  final List<StickyItemEntry> items;

  StickyNoteWithItems({required this.note, required this.items});
}

@DriftAccessor(tables: [StickyNotes, StickyItems])
class StickyNoteDao extends DatabaseAccessor<AppDatabase> with _$StickyNoteDaoMixin {
  StickyNoteDao(super.db);

  Stream<List<StickyNoteWithItems>> watchAllNotesWithItems() {
    final notesQuery = select(stickyNotes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)]);
    return notesQuery.watch().asyncMap((notesList) async {
      final result = <StickyNoteWithItems>[];
      for (final note in notesList) {
        final items = await (select(stickyItems)
              ..where((it) => it.noteId.equals(note.id))
              ..orderBy([(it) => OrderingTerm.asc(it.position)]))
            .get();
        result.add(StickyNoteWithItems(note: note, items: items));
      }
      return result;
    });
  }

  Future<List<StickyNoteWithItems>> getAllNotesWithItems() async {
    final notesList = await (select(stickyNotes)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).get();
    final result = <StickyNoteWithItems>[];
    for (final note in notesList) {
      final items = await (select(stickyItems)
            ..where((it) => it.noteId.equals(note.id))
            ..orderBy([(it) => OrderingTerm.asc(it.position)]))
          .get();
      result.add(StickyNoteWithItems(note: note, items: items));
    }
    return result;
  }

  Future<int> insertNote(StickyNotesCompanion note) {
    return into(stickyNotes).insert(note);
  }

  Future<int> insertItem(StickyItemsCompanion item) {
    return into(stickyItems).insert(item);
  }

  Future<bool> updateItemState(String itemId, String state) {
    return (update(stickyItems)..where((it) => it.id.equals(itemId))).write(
      StickyItemsCompanion(
        state: Value(state),
      ),
    ).then((count) => count > 0);
  }

  Future<int> deleteItem(String itemId) {
    return (delete(stickyItems)..where((it) => it.id.equals(itemId))).go();
  }

  Future<void> deleteNote(String noteId) {
    return transaction(() async {
      await (delete(stickyItems)..where((it) => it.noteId.equals(noteId))).go();
      await (delete(stickyNotes)..where((n) => n.id.equals(noteId))).go();
    });
  }

  Future<List<StickyNoteEntry>> getAllNotesRaw() {
    return (select(stickyNotes)..orderBy([(n) => OrderingTerm.asc(n.createdAt)])).get();
  }

  Future<List<StickyItemEntry>> getAllItemsRaw() {
    return (select(stickyItems)..orderBy([(i) => OrderingTerm.asc(i.position)])).get();
  }

  Future<int> insertRawNote(StickyNoteEntry entry) {
    return into(stickyNotes).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> insertRawItem(StickyItemEntry entry) {
    return into(stickyItems).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<int> deleteAllStickyItems() {
    return delete(stickyItems).go();
  }

  Future<int> deleteAllStickyNotes() {
    return delete(stickyNotes).go();
  }
}
