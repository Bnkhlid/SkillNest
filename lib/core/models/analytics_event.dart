import 'dart:convert';

enum AnalyticsEventType {
  resourceAdded('resourceAdded'),
  resourceDeleted('resourceDeleted'),
  resourceRestored('resourceRestored'),
  resourceOpened('resourceOpened'),
  resourceCompleted('resourceCompleted'),
  resourceStatusChanged('resourceStatusChanged'),
  favoriteChanged('favoriteChanged'),
  noteSaved('noteSaved'),
  resourceMoved('resourceMoved'),
  stickyNoteAdded('stickyNoteAdded'),
  stickyItemStateChanged('stickyItemStateChanged'),
  fileAttached('fileAttached'),
  fileOpened('fileOpened'),
  searchPerformed('searchPerformed'),
  collectionCreated('collectionCreated'),
  collectionDeleted('collectionDeleted');

  final String value;
  const AnalyticsEventType(this.value);

  static AnalyticsEventType fromString(String raw) {
    return AnalyticsEventType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => AnalyticsEventType.resourceAdded,
    );
  }
}

class AnalyticsEvent {
  final String id;
  final String? resourceId;
  final AnalyticsEventType eventType;
  final DateTime occurredAt;
  final String? metadataJson;
  final int? durationSeconds;
  final double? progressPercent;
  final String? source;

  AnalyticsEvent({
    required this.id,
    this.resourceId,
    required this.eventType,
    DateTime? occurredAt,
    this.metadataJson,
    this.durationSeconds,
    this.progressPercent,
    this.source,
  }) : occurredAt = occurredAt ?? DateTime.now();

  Map<String, dynamic>? get metadata {
    if (metadataJson == null || metadataJson!.isEmpty) return null;
    try {
      return jsonDecode(metadataJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
