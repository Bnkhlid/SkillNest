import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/sticky_note_dao.dart';
import '../../../widgets/components.dart';

class StickyNoteModel {
  final String id;
  String title;
  Color color;
  List<StickyItemModel> items;
  DateTime createdAt;

  StickyNoteModel({
    required this.id,
    required this.title,
    required this.color,
    required this.items,
    required this.createdAt,
  });
}

class StickyItemModel {
  final String id;
  final String noteId;
  String text;
  NotedCheckState state;
  bool isBullet;
  int position;

  StickyItemModel({
    required this.id,
    required this.noteId,
    required this.text,
    required this.state,
    required this.isBullet,
    this.position = 0,
  });
}

class StickyNoteRepository {
  final StickyNoteDao _dao;
  static const _uuid = Uuid();

  StickyNoteRepository(this._dao);

  NotedCheckState _parseState(String raw) {
    return switch (raw) {
      'completed' => NotedCheckState.completed,
      'discarded' => NotedCheckState.discarded,
      _ => NotedCheckState.unchecked,
    };
  }

  StickyNoteModel _mapToModel(StickyNoteWithItems entry) {
    return StickyNoteModel(
      id: entry.note.id,
      title: entry.note.title,
      color: Color(entry.note.colorValue),
      createdAt: entry.note.createdAt,
      items: entry.items.map((it) {
        return StickyItemModel(
          id: it.id,
          noteId: it.noteId,
          text: it.textContent,
          state: _parseState(it.state),
          isBullet: it.isBullet,
          position: it.position,
        );
      }).toList(),
    );
  }

  Stream<List<StickyNoteModel>> watchNotes() {
    return _dao.watchAllNotesWithItems().map(
      (list) => list.map(_mapToModel).toList(),
    );
  }

  Future<List<StickyNoteModel>> getNotes() async {
    final list = await _dao.getAllNotesWithItems();
    return list.map(_mapToModel).toList();
  }

  Future<String> createNote({
    required String title,
    required Color color,
    required List<String> items,
    bool isBullet = false,
  }) async {
    final noteId = 'sn_${_uuid.v4()}';
    await _dao.insertNote(
      StickyNotesCompanion(
        id: Value(noteId),
        title: Value(title),
        colorValue: Value(color.toARGB32()),
        createdAt: Value(DateTime.now()),
      ),
    );

    for (int i = 0; i < items.length; i++) {
      final itemId = 'si_${_uuid.v4()}';
      await _dao.insertItem(
        StickyItemsCompanion(
          id: Value(itemId),
          noteId: Value(noteId),
          textContent: Value(items[i]),
          state: const Value('unchecked'),
          isBullet: Value(isBullet),
          position: Value(i),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    return noteId;
  }

  Future<void> updateItemState(String itemId, NotedCheckState state) {
    return _dao.updateItemState(itemId, state.name);
  }

  Future<void> deleteItem(String itemId) {
    return _dao.deleteItem(itemId);
  }

  Future<void> deleteNote(String noteId) {
    return _dao.deleteNote(noteId);
  }
}
