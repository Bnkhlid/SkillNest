import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.presetStatus});

  final ResourceStatus? presetStatus;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _query = TextEditingController();
  final _filters = SearchFilters();
  SortOrder _sort = SortOrder.newest;
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _filters.status = widget.presetStatus;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(ResourceItem e) =>
      Navigator.pushNamed(context, '/details', arguments: e.id);

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selectMode && _selected.isEmpty) _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vault = Vault.I;

    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      appBar: _selectMode
          ? _selectionAppBar(scheme)
          : _normalAppBar(context, scheme),
      bottomNavigationBar: _selectMode ? _bulkBar(context, scheme) : null,
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          final results = vault.search(_filters, sort: _sort);
          return Column(
            children: [
              if (!_selectMode) _toolbar(context, scheme, results.length),
              if (vault.offlineDemo) const OfflineBanner(),
              Expanded(
                child: results.isEmpty
                    ? _emptyState()
                    : SafeArea(
                        top: false,
                        child: ListView.separated(
                          // Keep the last card entirely above Android's
                          // gesture/navigation bar on edge-to-edge devices.
                          padding: const EdgeInsets.fromLTRB(
                            Insets.m,
                            8,
                            Insets.m,
                            32,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final e = results[i];
                            return ResourceTile(
                              item: e,
                              onOpen: () => _open(e),
                              selectMode: _selectMode,
                              selected: _selected.contains(e.id),
                              onToggleSelect: () => _toggleSelect(e.id),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _normalAppBar(BuildContext context, ColorScheme scheme) {
    final canPop = Navigator.canPop(context);
    return AppBar(
      backgroundColor: NotedColors.canvasLight,
      leading: canPop
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
        'Inbox',
        style: TextStyle(color: NotedColors.ink, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist_rounded, color: NotedColors.ink),
          tooltip: 'Select',
          onPressed: () => setState(() => _selectMode = true),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: NotedColors.canvasLight,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel',
        onPressed: () => setState(() {
          _selectMode = false;
          _selected.clear();
        }),
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            final all = Vault.I
                .search(_filters, sort: _sort)
                .map((e) => e.id)
                .toSet();
            if (_selected.containsAll(all)) {
              _selected.clear();
            } else {
              _selected.addAll(all);
            }
          }),
          child: const Text('Select All'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ColorScheme scheme, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.m, 8, Insets.m, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _query,
            onChanged: (v) => setState(() => _filters.query = v),
            decoration: InputDecoration(
              hintText: 'Search your library…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Clear',
                      onPressed: () {
                        _query.clear();
                        setState(() => _filters.query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterBadgeIcon(
                active: _filters.activeCount,
                onTap: _showFilterSheet,
              ),
              LvIconBtn(
                icon: Icons.sort_rounded,
                tooltip: 'Sort',
                onTap: _showSortSheet,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _sort == SortOrder.newest
                      ? '$count items'
                      : '$count items · ${_sortLabel(_sort)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(SortOrder s) => switch (s) {
    SortOrder.newest => 'Newest',
    SortOrder.oldest => 'Oldest',
    SortOrder.titleAZ => 'A–Z',
    SortOrder.recentlyOpened => 'Recently opened',
  };

  Widget _emptyState() {
    if (_filters.isActive || _filters.query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Nothing matches your filters. Try clearing them.',
        actionLabel: 'Clear filters',
        onAction: () => setState(() {
          _filters.reset();
          _query.clear();
        }),
      );
    }
    return EmptyState(
      icon: Icons.inbox_rounded,
      title: 'Inbox is empty',
      message:
          'Save links, files and notes — they land here first, then organize themselves.',
      actionLabel: 'Add resource',
      onAction: () => Navigator.pushNamed(context, '/add'),
    );
  }

  Future<void> _showFilterSheet() {
    return LvSheet.show<void>(
      context,
      title: 'Filter',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(Insets.l, 0, Insets.l, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filterLabel('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          null,
                          ResourceStatus.unread,
                          ResourceStatus.inProgress,
                          ResourceStatus.completed,
                        ]
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s == null ? 'All' : s.label),
                            selected: _filters.status == s,
                            onSelected: (v) =>
                                setSheet(() => _filters.status = v ? s : null),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              _filterLabel('Type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [null, ...ResourceKind.values]
                    .map(
                      (k) => ChoiceChip(
                        label: Text(k == null ? 'All' : k.label),
                        selected: _filters.kind == k,
                        onSelected: (v) =>
                            setSheet(() => _filters.kind = v ? k : null),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _filterLabel('Collection'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filters.collectionId == null,
                    onSelected: (v) =>
                        setSheet(() => _filters.collectionId = null),
                  ),
                  ...Vault.I.collections.map(
                    (c) => ChoiceChip(
                      label: Text('${c.emoji} ${c.name}'),
                      selected: _filters.collectionId == c.id,
                      onSelected: (v) => setSheet(
                        () => _filters.collectionId = v ? c.id : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _filterLabel('Favorites'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _filters.favoritesOnly,
                onChanged: (v) => setSheet(() => _filters.favoritesOnly = v),
                secondary: const Icon(Icons.star_rounded),
                title: const Text('Favorites only'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheet(() => _filters.reset());
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _filterLabel(String s) => Text(
    s.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Future<void> _showSortSheet() {
    return LvSheet.show<SortOrder>(
      context,
      title: 'Sort by',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: SortOrder.values
            .map(
              (s) => ListTile(
                title: Text(
                  _sortLabel(s),
                  style: const TextStyle(fontSize: 15),
                ),
                trailing: _sort == s
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
            )
            .toList(),
      ),
    ).then((s) {
      if (s != null) setState(() => _sort = s);
    });
  }

  Widget _bulkBar(BuildContext context, ColorScheme scheme) {
    final n = _selected.length;
    final items = Vault.I.items.where((e) => _selected.contains(e.id)).toList();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Insets.m, 8, Insets.m, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: NotedColors.border, width: 1.5),
          ),
          boxShadow: const [
            BoxShadow(
              color: NotedColors.shadow,
              offset: Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bulkAction(
              scheme,
              Icons.drive_file_move_outline,
              'Move',
              () async {
                if (items.isEmpty) {
                  LvSnackbar.show(context, 'No items selected');
                  return;
                }
                await showMoveSheet(
                  context,
                  items.first,
                  ids: _selected.toList(),
                );
                if (mounted) {
                  setState(() {
                    _selectMode = false;
                    _selected.clear();
                  });
                }
              },
            ),
            _bulkAction(scheme, Icons.sell_outlined, 'Tag', () async {
              if (items.isEmpty) {
                LvSnackbar.show(context, 'No items selected');
                return;
              }
              await showTagsSheet(
                context,
                items.first,
                ids: _selected.toList(),
              );
              if (mounted) {
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              }
            }),
            _bulkAction(scheme, Icons.star_rounded, 'Favorite', () {
              if (items.isEmpty) {
                LvSnackbar.show(context, 'No items selected');
                return;
              }
              for (final e in items) {
                Vault.I.setFavorite(e.id, !e.favorite);
              }
              LvSnackbar.show(context, 'Updated $n items');
              setState(() {
                _selectMode = false;
                _selected.clear();
              });
            }),
            _bulkAction(scheme, Icons.delete_outline_rounded, 'Delete', () {
              if (items.isEmpty) {
                LvSnackbar.show(context, 'No items selected');
                return;
              }
              LvDialog.show(
                context,
                icon: Icons.delete_outline_rounded,
                iconColor: scheme.error,
                title: 'Delete $n items?',
                message:
                    'They\u2019ll stay in Trash for 30 days before being removed forever.',
                confirmLabel: 'Delete',
                confirmColor: scheme.error,
                onConfirm: () {
                  for (final e in items) {
                    Vault.I.delete(e.id);
                  }
                  LvSnackbar.show(
                    context,
                    'Moved $n items to Trash',
                    actionLabel: 'Undo',
                    onAction: () {
                      for (final e in items) {
                        Vault.I.restore(e.id);
                      }
                    },
                    icon: Icons.delete_outline_rounded,
                  );
                  setState(() {
                    _selectMode = false;
                    _selected.clear();
                  });
                },
              );
            }, scheme.error),
          ],
        ),
      ),
    );
  }

  Widget _bulkAction(
    ColorScheme scheme,
    IconData icon,
    String label,
    VoidCallback onTap, [
    Color? color,
  ]) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? scheme.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
