import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _query = TextEditingController();
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<TrashEntry> get _filtered {
    final q = _query.text.trim().toLowerCase();
    var list = Vault.I.trash;
    if (q.isNotEmpty) {
      list = list.where((t) => t.item.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vault = Vault.I;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel',
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }),
              )
            : const BackButton(),
        title: Text(_selectMode ? '${_selected.length} selected' : 'Trash'),
        actions: _selectMode
            ? [
                TextButton(
                  onPressed: () => setState(() {
                    _selected.addAll(_filtered.map((t) => t.item.id));
                  }),
                  child: const Text('Select All'),
                ),
              ]
            : [
                if (vault.trash.isNotEmpty)
                  TextButton(
                    onPressed: () => LvDialog.show(
                      context,
                      icon: Icons.delete_forever_rounded,
                      iconColor: scheme.error,
                      title: 'Empty Trash?',
                      message: 'All ${vault.trash.length} item${vault.trash.length == 1 ? '' : 's'} will be permanently deleted. This can\u2019t be undone.',
                      confirmLabel: 'Empty Trash',
                      confirmColor: scheme.error,
                      onConfirm: () {
                        Vault.I.emptyTrash();
                        LvSnackbar.show(context, 'Trash emptied', icon: Icons.delete_forever_rounded);
                      },
                    ),
                    child: Text('Empty', style: TextStyle(color: scheme.error)),
                  ),
                const SizedBox(width: 4),
              ],
      ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty ? _bulkBar(context, scheme) : null,
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          final entries = _filtered;
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline_rounded,
              title: _query.text.isEmpty ? 'Trash is empty' : 'No matches',
              message: _query.text.isEmpty
                  ? 'Deleted items rest here for 30 days, then disappear forever.'
                  : 'Nothing in Trash matches \u201C${_query.text}\u201D.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.m, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search trash…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            tooltip: 'Clear',
                            onPressed: () {
                              _query.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Insets.m, 0, Insets.m, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = entries[i];
                    final selected = _selected.contains(t.item.id);
                    return Container(
                      decoration: NotedBox.card(
                        color: isDark ? scheme.surfaceContainerLow : Colors.white,
                        radius: Radii.card,
                        borderColor: selected
                            ? scheme.primary
                            : (isDark ? scheme.outlineVariant : NotedColors.border),
                        shadowColor: isDark ? Colors.black : NotedColors.shadow,
                        shadowOffset: const Offset(2.5, 3.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleSelect(t.item.id),
                          onLongPress: () => _toggleSelect(t.item.id),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                if (_selectMode) ...[
                                  Icon(
                                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: selected ? scheme.primary : scheme.outline,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Row(
                                    children: [
                                      LvThumb(item: t.item, size: 44),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.2,
                                                color: scheme.onSurface.withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'deleted · ${t.daysLeft}d left',
                                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      LvIconBtn(
                                        icon: Icons.restore_rounded,
                                        tooltip: 'Restore',
                                        onTap: () {
                                          Vault.I.restore(t.item.id);
                                          LvSnackbar.show(context, '\u201C${t.item.title}\u201D restored to library');
                                        },
                                      ),
                                      LvIconBtn(
                                        icon: Icons.delete_forever_outlined,
                                        tooltip: 'Delete permanently',
                                        color: scheme.error,
                                        onTap: () => LvDialog.show(
                                          context,
                                          icon: Icons.delete_forever_rounded,
                                          iconColor: scheme.error,
                                          title: 'Delete forever?',
                                          message: '\u201C${t.item.title}\u201D will be gone for good.',
                                          confirmLabel: 'Delete',
                                          confirmColor: scheme.error,
                                          onConfirm: () {
                                            Vault.I.deletePermanent(t.item.id);
                                            if (_selected.contains(t.item.id)) _selected.remove(t.item.id);
                                            LvSnackbar.show(context, 'Deleted permanently', icon: Icons.delete_forever_rounded);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bulkBar(BuildContext context, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Insets.m, 8, Insets.m, 8),
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerLowest : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? scheme.outlineVariant : NotedColors.border,
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : NotedColors.shadow,
              offset: const Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.restore_rounded, size: 20),
              label: const Text('Restore'),
              onPressed: () {
                final n = _selected.length;
                if (n == 0) {
                  LvSnackbar.show(context, 'No items selected');
                  return;
                }
                for (final id in _selected.toList()) {
                  Vault.I.restore(id);
                }
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
                LvSnackbar.show(context, 'Restored $n item${n == 1 ? '' : 's'}');
              },
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_forever_outlined, size: 20),
              label: const Text('Delete'),
              onPressed: () {
                if (_selected.isEmpty) {
                  LvSnackbar.show(context, 'No items selected');
                  return;
                }
                LvDialog.show(
                  context,
                  icon: Icons.delete_forever_rounded,
                  iconColor: scheme.error,
                  title: 'Delete ${_selected.length} items forever?',
                  message: 'This can\u2019t be undone.',
                  confirmLabel: 'Delete',
                  confirmColor: scheme.error,
                  onConfirm: () {
                    final n = _selected.length;
                    for (final id in _selected.toList()) {
                      Vault.I.deletePermanent(id);
                    }
                    setState(() {
                      _selectMode = false;
                      _selected.clear();
                    });
                    LvSnackbar.show(context, '$n item${n == 1 ? '' : 's'} deleted forever', icon: Icons.delete_forever_rounded);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
