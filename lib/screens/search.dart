import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../core/providers/database_providers.dart';
import '../core/services/firebase_usage_analytics.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _filters = SearchFilters();
  SortOrder _sort = SortOrder.newest;
  bool _ranSearch = false;
  Timer? _debounceTimer;
  List<ResourceItem> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch(immediate: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _performSearch({bool immediate = false}) {
    _debounceTimer?.cancel();
    if (immediate) {
      _executeSearch();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 200), _executeSearch);
    }
  }

  Future<void> _executeSearch() async {
    if (!mounted) return;
    final showResults =
        _ranSearch || _filters.isActive || _filters.query.isNotEmpty;
    if (!showResults) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final searchRepo = ref.read(searchRepositoryProvider);
      final results = await searchRepo.search(filters: _filters, sort: _sort);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _run([String? q]) {
    if (q != null && q.trim().isNotEmpty) Vault.I.pushRecentSearch(q);
    FirebaseUsageAnalytics.instance.searchUsed();
    setState(() => _ranSearch = true);
    _performSearch(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          'Search',
          style: TextStyle(color: NotedColors.ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          final results = _searchResults;
          final showResults =
              _ranSearch || _filters.isActive || _filters.query.isNotEmpty;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 4, Insets.m, 4),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => _run(v),
                  onChanged: (v) {
                    setState(() => _filters.query = v);
                    _performSearch();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search titles, sources, tags…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            tooltip: 'Clear',
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _filters.query = '';
                                _ranSearch = false;
                              });
                              _performSearch(immediate: true);
                            },
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.m, 0, Insets.s, 4),
                child: Row(
                  children: [
                    FilterBadgeIcon(
                      active: _filters.activeCount,
                      onTap: _showFilters,
                    ),
                    LvIconBtn(
                      icon: Icons.sort_rounded,
                      tooltip: 'Sort',
                      onTap: _showSort,
                    ),
                    const SizedBox(width: 4),
                    if (showResults)
                      Expanded(
                        child: Text(
                          '${results.length} result${results.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: showResults
                    ? (results.isEmpty && !_isLoading
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No results',
                              message:
                                  'Nothing matches \u201C${_filters.query}\u201D${_filters.isActive ? ' with these filters' : ''}. Try different keywords.',
                              actionLabel: 'Clear all',
                              onAction: () {
                                setState(() {
                                  _filters.reset();
                                  _controller.clear();
                                });
                                _performSearch(immediate: true);
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                Insets.m,
                                4,
                                Insets.m,
                                120,
                              ),
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) => ResourceTile(
                                item: results[i],
                                trailingFavorite: true,
                                onOpen: () {
                                  _run(_controller.text);
                                  Navigator.pushNamed(
                                    context,
                                    '/details',
                                    arguments: results[i].id,
                                  ).then((_) {
                                    _performSearch(immediate: true);
                                  });
                                },
                              ),
                            ))
                    : _recentSearches(scheme, vault),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _recentSearches(ColorScheme scheme, Vault vault) {
    if (vault.recentSearches.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: 'Search your library',
        message: 'Find anything you saved — by title, source or tag.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.l, 12, Insets.l, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Vault.I.clearSearchHistory(),
              child: const Text('Clear History'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vault.recentSearches
              .map(
                (q) => ActionChip(
                  avatar: Icon(
                    Icons.history_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: Text(q),
                  onPressed: () {
                    _controller.text = q;
                    setState(() => _filters.query = q);
                    _run(q);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _showFilters() {
    return LvSheet.show<void>(
      context,
      title: 'Filters',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(Insets.l, 0, Insets.l, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [null, ...ResourceStatus.values]
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
              const SizedBox(height: 14),
              _label('Type'),
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
              const SizedBox(height: 14),
              _label('Collection'),
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
              const SizedBox(height: 14),
              _label('Tag'),
              Builder(
                builder: (ctx) {
                  final tags = Vault.I.allTags.toList()..sort();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filters.tag == null,
                        onSelected: (v) => setSheet(() => _filters.tag = null),
                      ),
                      ...tags.map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: _filters.tag == t,
                          onSelected: (v) =>
                              setSheet(() => _filters.tag = v ? t : null),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
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
                      onPressed: () => setSheet(() => _filters.reset()),
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
      if (mounted) {
        setState(() {});
        _performSearch(immediate: true);
      }
    });
  }

  Widget _label(String s) => Text(
    s.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Future<void> _showSort() {
    return LvSheet.show<SortOrder>(
      context,
      title: 'Sort by',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Newest'),
            trailing: _sort == SortOrder.newest
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.pop(ctx, SortOrder.newest),
          ),
          ListTile(
            title: const Text('Oldest'),
            trailing: _sort == SortOrder.oldest
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.pop(ctx, SortOrder.oldest),
          ),
          ListTile(
            title: const Text('Title A–Z'),
            trailing: _sort == SortOrder.titleAZ
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(ctx).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.pop(ctx, SortOrder.titleAZ),
          ),
        ],
      ),
    ).then((s) {
      if (s != null) {
        setState(() => _sort = s);
        _performSearch(immediate: true);
      }
    });
  }
}
