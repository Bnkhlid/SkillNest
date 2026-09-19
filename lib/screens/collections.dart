import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';
import 'add_resource.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  void _open(BuildContext context, CollectionModel c) {
    Navigator.pushNamed(context, '/collection', arguments: c.id);
  }

  Future<void> _create(BuildContext context) async {
    final draft = await showCollectionEditor(context);
    if (draft != null && context.mounted) {
      await Vault.I.addCollection(
        draft.name,
        emoji: draft.emoji,
        accent: draft.accent,
      );
      if (context.mounted) {
        LvSnackbar.show(
          context,
          'Collection \u201C${draft.name}\u201D created',
        );
      }
    }
  }

  Future<void> _more(BuildContext context, CollectionModel c) {
    final scheme = Theme.of(context).colorScheme;
    return LvSheet.show<String>(
      context,
      title: c.name,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LvSheetAction(
            icon: Icons.folder_open_rounded,
            label: 'Open',
            onTap: () => Navigator.pop(ctx, 'open'),
          ),
          LvSheetAction(
            icon: Icons.edit_outlined,
            label: 'Edit collection',
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          LvSheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete collection',
            foreground: scheme.error,
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    ).then((action) async {
      if (action == null || !context.mounted) return;
      switch (action) {
        case 'open':
          _open(context, c);
        case 'edit':
          final draft = await showCollectionEditor(context, collection: c);
          if (draft != null) {
            await Vault.I.renameCollection(
              c.id,
              draft.name,
              emoji: draft.emoji,
              accent: draft.accent,
            );
          }
        case 'delete':
          final count = Vault.I.byCollection(c.id).length;
          await LvDialog.show(
            context,
            icon: Icons.folder_off_rounded,
            iconColor: Theme.of(context).colorScheme.error,
            title: 'Delete \u201C${c.name}\u201D?',
            message: count == 0
                ? 'This collection is empty.'
                : '$count item${count == 1 ? '' : 's'} will move back to the Inbox (nothing is deleted).',
            confirmLabel: 'Delete',
            confirmColor: Theme.of(context).colorScheme.error,
            onConfirm: () async {
              await Vault.I.deleteCollection(c.id);
              if (context.mounted) {
                LvSnackbar.show(context, 'Collection deleted');
              }
            },
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;
    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      appBar: AppBar(
        backgroundColor: NotedColors.canvasLight,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: NotedColors.ink,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Collections',
          style: TextStyle(color: NotedColors.ink, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'New collection',
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_rounded, color: NotedColors.ink),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          if (vault.collections.isEmpty) {
            return EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No collections yet',
              message:
                  'Group resources by topic or goal — \u201CML basics\u201D, \u201CInterview prep\u201D, anything.',
              actionLabel: 'Create collection',
              onAction: () => _create(context),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(Insets.m, 8, Insets.m, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.94,
            ),
            itemCount: vault.collections.length,
            itemBuilder: (context, i) {
              final c = vault.collections[i];
              return CollectionCard(
                collection: c,
                onOpen: () => _open(context, c),
                onMore: () => _more(context, c),
              );
            },
          );
        },
      ),
    );
  }
}

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  ResourceStatus? _statusFilter;
  SortOrder _sort = SortOrder.newest;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Vault.I,
      builder: (context, _) {
        final c = Vault.I.collections
            .where((c) => c.id == widget.collectionId)
            .firstOrNull;
        if (c == null) {
          return const Scaffold(
            body: Center(child: Text('Collection not found')),
          );
        }
        var items = Vault.I.byCollection(c.id);
        if (_statusFilter != null) {
          items = items.where((e) => e.status == _statusFilter).toList();
        }
        switch (_sort) {
          case SortOrder.newest:
            items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          case SortOrder.oldest:
            items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
          case SortOrder.titleAZ:
            items.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
          case SortOrder.recentlyOpened:
            items.sort(
              (a, b) => (b.lastOpenedAt ?? DateTime(2000)).compareTo(
                a.lastOpenedAt ?? DateTime(2000),
              ),
            );
        }

        return Scaffold(
          backgroundColor: NotedColors.canvasLight,
          appBar: AppBar(
            backgroundColor: NotedColors.canvasLight,
            leading: const BackButton(color: NotedColors.ink),
            title: Text(
              '${c.emoji} ${c.name}',
              style: const TextStyle(
                color: NotedColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              LvIconBtn(
                icon: Icons.add_circle_outline_rounded,
                tooltip: 'Add to collection',
                onTap: () => _showAddMenu(context, c),
              ),
              LvIconBtn(
                icon: Icons.more_vert_rounded,
                tooltip: 'More',
                onTap: () => _moreMenu(context, c),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Add resource banner
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.m, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showAddMenu(context, c),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add to collection'),
                  ),
                ),
              ),
              // Status filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.s, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in [null, ...ResourceStatus.values])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(s == null ? 'All' : s.label),
                                  selected: _statusFilter == s,
                                  onSelected: (v) => setState(
                                    () => _statusFilter = v ? s : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    LvIconBtn(
                      icon: Icons.sort_rounded,
                      tooltip: 'Sort',
                      onTap: () =>
                          LvSheet.show<SortOrder>(
                            context,
                            title: 'Sort by',
                            builder: (ctx) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: SortOrder.values
                                  .map(
                                    (s) => ListTile(
                                      title: Text(
                                        s.name == 'titleAZ'
                                            ? 'Title A–Z'
                                            : switch (s) {
                                                SortOrder.newest => 'Newest',
                                                SortOrder.oldest => 'Oldest',
                                                SortOrder.recentlyOpened =>
                                                  'Recently opened',
                                                _ => 'Title A–Z',
                                              },
                                      ),
                                      trailing: _sort == s
                                          ? Icon(
                                              Icons.check_rounded,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.primary,
                                            )
                                          : null,
                                      onTap: () => Navigator.pop(ctx, s),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ).then((s) {
                            if (s != null) setState(() => _sort = s);
                          }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_open_rounded,
                        title: _statusFilter == null
                            ? 'Nothing here yet'
                            : 'No ${_statusFilter!.label.toLowerCase()} items',
                        message: _statusFilter == null
                            ? 'Add resources to this collection and they\u2019ll show up here.'
                            : 'Switch filters to see the rest of the collection.',
                        actionLabel: _statusFilter == null
                            ? 'Add to collection'
                            : null,
                        onAction: _statusFilter == null
                            ? () => _showAddMenu(context, c)
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.m,
                          4,
                          Insets.m,
                          120,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => ResourceTile(
                          item: items[i],
                          trailingFavorite: true,
                          onOpen: () => Navigator.pushNamed(
                            context,
                            '/details',
                            arguments: items[i].id,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddMenu(
    BuildContext context,
    CollectionModel collection,
  ) async {
    final action = await LvSheet.show<String>(
      context,
      title: 'Add to ${collection.name}',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LvSheetAction(
            icon: Icons.add_link_rounded,
            label: 'Add new source',
            onTap: () => Navigator.pop(sheetContext, 'new'),
          ),
          LvSheetAction(
            icon: Icons.playlist_add_rounded,
            label: 'Add saved source',
            onTap: () => Navigator.pop(sheetContext, 'saved'),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'new') {
      await Navigator.pushNamed(
        context,
        '/add',
        arguments: AddArgs(presetCollectionId: collection.id),
      );
    } else if (action == 'saved') {
      await _selectSavedResources(context, collection);
    }
  }

  Future<void> _selectSavedResources(
    BuildContext context,
    CollectionModel collection,
  ) async {
    final vault = Vault.I;
    final available = vault.items
        .where((item) => item.collectionId != collection.id)
        .toList();
    if (available.isEmpty) {
      LvSnackbar.show(
        context,
        'All saved sources are already in this collection.',
      );
      return;
    }

    final selected = <String>{};
    final ids = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add saved sources'),
          content: SizedBox(
            width: 360,
            height: 390,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select sources to move into this collection.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = available[index];
                      return CheckboxListTile(
                        value: selected.contains(item.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.collectionId == null
                              ? 'Inbox'
                              : 'Moves from another collection',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (checked) => setDialogState(() {
                          if (checked ?? false) {
                            selected.add(item.id);
                          } else {
                            selected.remove(item.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, Set.of(selected)),
              child: Text('Add (${selected.length})'),
            ),
          ],
        ),
      ),
    );
    if (ids == null || ids.isEmpty) return;

    for (final id in ids) {
      await vault.moveTo(id, collection.id);
    }
    if (context.mounted) {
      LvSnackbar.show(
        context,
        '${ids.length} source${ids.length == 1 ? '' : 's'} added to ${collection.name}',
      );
    }
  }

  void _moreMenu(BuildContext context, CollectionModel c) {
    final scheme = Theme.of(context).colorScheme;
    LvSheet.show<String>(
      context,
      title: '${c.emoji} ${c.name}',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LvSheetAction(
            icon: Icons.edit_outlined,
            label: 'Edit collection',
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          LvSheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete collection',
            foreground: scheme.error,
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    ).then((a) async {
      if (a == null || !context.mounted) return;
      if (a == 'edit') {
        final draft = await showCollectionEditor(context, collection: c);
        if (draft != null) {
          await Vault.I.renameCollection(
            c.id,
            draft.name,
            emoji: draft.emoji,
            accent: draft.accent,
          );
        }
      } else if (a == 'delete') {
        LvDialog.show(
          context,
          icon: Icons.folder_off_rounded,
          iconColor: scheme.error,
          title: 'Delete \u201C${c.name}\u201D?',
          message: 'Items inside move back to the Inbox — nothing is deleted.',
          confirmLabel: 'Delete',
          confirmColor: scheme.error,
          onConfirm: () async {
            await Vault.I.deleteCollection(c.id);
            if (context.mounted) {
              Navigator.pop(context); // detail → back to list
            }
          },
        );
      }
    });
  }
}

class CollectionDraft {
  const CollectionDraft({
    required this.name,
    required this.emoji,
    required this.accent,
  });
  final String name;
  final String emoji;
  final int accent;
}

Future<CollectionDraft?> showCollectionEditor(
  BuildContext context, {
  CollectionModel? collection,
}) {
  return showDialog<CollectionDraft>(
    context: context,
    builder: (_) => _CollectionEditor(collection: collection),
  );
}

class _CollectionEditor extends StatefulWidget {
  const _CollectionEditor({this.collection});
  final CollectionModel? collection;

  @override
  State<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<_CollectionEditor> {
  static const _emojis = [
    '📚',
    '💻',
    '🎯',
    '🧠',
    '🎨',
    '🚀',
    '💼',
    '🌱',
    '🎬',
    '📝',
  ];
  static const _colors = [
    NotedColors.yellowLight,
    NotedColors.mintLight,
    NotedColors.pinkLight,
    NotedColors.purpleLight,
    NotedColors.blueLight,
    Color(0xFFFDEED8),
  ];
  late final TextEditingController _name;
  late final TextEditingController _emoji;
  late int _accent;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.collection?.name ?? '');
    _emoji = TextEditingController(text: widget.collection?.emoji ?? '📚');
    _accent = widget.collection?.accent ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotedColors.canvasLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.dialog),
        side: const BorderSide(color: NotedColors.border, width: 2),
      ),
      title: Text(
        widget.collection == null ? 'New collection' : 'Edit collection',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.collection == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Collection name',
                  hintText: 'e.g. System Design',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Emoji',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emoji,
                maxLength: 8,
                decoration: const InputDecoration(
                  hintText: 'Write or paste any emoji',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _emojis
                    .map(
                      (emoji) => ChoiceChip(
                        label: Text(
                          emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        selected: _emoji.text == emoji,
                        onSelected: (_) => setState(() => _emoji.text = emoji),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'Color',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 11,
                children: List.generate(
                  _colors.length,
                  (index) => InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(() => _accent = index),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _colors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NotedColors.border,
                          width: _accent == index ? 3 : 1.5,
                        ),
                      ),
                      child: _accent == index
                          ? const Icon(Icons.check_rounded, size: 19)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final emoji = _emoji.text.trim().isEmpty
                ? '📚'
                : _emoji.text.trim();
            Navigator.pop(
              context,
              CollectionDraft(name: name, emoji: emoji, accent: _accent),
            );
          },
          child: Text(widget.collection == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
