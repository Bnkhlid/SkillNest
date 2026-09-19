import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _query = TextEditingController();
  SortOrder _sort = SortOrder.newest;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      appBar: AppBar(
        backgroundColor: NotedColors.canvasLight,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: NotedColors.ink),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Favorites', style: TextStyle(color: NotedColors.ink, fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: Vault.I,
        builder: (context, _) {
          var items = Vault.I.favorites;
          if (_query.text.trim().isNotEmpty) {
            final q = _query.text.trim().toLowerCase();
            items = items
                .where((e) => e.title.toLowerCase().contains(q) || e.source.toLowerCase().contains(q))
                .toList();
          }
          switch (_sort) {
            case SortOrder.newest:
              items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
            case SortOrder.oldest:
              items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
            case SortOrder.titleAZ:
              items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
            case SortOrder.recentlyOpened:
              items.sort((a, b) => (b.lastOpenedAt ?? DateTime(2000)).compareTo(a.lastOpenedAt ?? DateTime(2000)));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.m, 4),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search favorites…',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 0, Insets.s, 4),
                child: Row(
                  children: [
                    LvIconBtn(
                      icon: Icons.sort_rounded,
                      tooltip: 'Sort',
                      onTap: () => LvSheet.show<SortOrder>(
                        context,
                        title: 'Sort by',
                        builder: (ctx) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ('Newest', SortOrder.newest),
                            ('Oldest', SortOrder.oldest),
                            ('Title A–Z', SortOrder.titleAZ),
                          ]
                              .map(
                                (p) => ListTile(
                                  title: Text(p.$1),
                                  trailing: _sort == p.$2
                                      ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                                      : null,
                                  onTap: () => Navigator.pop(ctx, p.$2),
                                ),
                              )
                              .toList(),
                        ),
                      ).then((s) {
                        if (s != null) setState(() => _sort = s);
                      })),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${items.length} favorite${items.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? (_query.text.isEmpty
                        ? EmptyState(
                            icon: Icons.star_outline_rounded,
                            title: 'No favorites yet',
                            message: 'Tap the star on any resource and it will wait for you here.',
                          )
                        : EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message: 'No favorite matches \u201C${_query.text}\u201D.',
                            actionLabel: 'Clear',
                            onAction: () {
                              _query.clear();
                              setState(() {});
                            },
                          ))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.m, 120),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = items[i];
                          return ResourceTile(
                            item: e,
                            trailingFavorite: true,
                            onOpen: () => Navigator.pushNamed(context, '/details', arguments: e.id),
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
}
