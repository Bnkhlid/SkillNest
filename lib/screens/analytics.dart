import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/charts.dart';
import '../widgets/components.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 30;
  String? _collectionFilter;

  static const _ranges = [
    (7, '7D'),
    (30, '30D'),
    (90, '90D'),
    (365, '1Y'),
    (0, 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vault = Vault.I;

    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final days = _days == 0 ? 3650 : _days;
        final snap = vault.analytics(
          days: days,
          collectionId: _collectionFilter,
        );
        final pool = _collectionFilter == null
            ? vault.items
            : vault.items
                  .where((e) => e.collectionId == _collectionFilter)
                  .toList();

        return Scaffold(
          backgroundColor: NotedColors.canvasLight,
          appBar: AppBar(
            backgroundColor: NotedColors.canvasLight,
            leading: const BackButton(),
            title: const Text('Analytics'),
            actions: [
              LvIconBtn(
                icon: Icons.filter_alt_outlined,
                tooltip: 'Filter by collection',
                onTap: () =>
                    LvSheet.show<String>(
                      context,
                      title: 'Filter',
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('All collections'),
                            trailing: _collectionFilter == null
                                ? Icon(
                                    Icons.check_rounded,
                                    color: scheme.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(ctx, ''),
                          ),
                          ...vault.collections.map(
                            (c) => ListTile(
                              leading: Text(
                                c.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              title: Text(c.name),
                              trailing: _collectionFilter == c.id
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: scheme.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(ctx, c.id),
                            ),
                          ),
                        ],
                      ),
                    ).then((id) {
                      if (id != null) {
                        setState(
                          () => _collectionFilter = id.isEmpty ? null : id,
                        );
                      }
                    }),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 120),
            children: [
              // Time range chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (d, label) in _ranges)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _days == d,
                          onSelected: (_) => setState(() => _days = d),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.m),

              // KPI grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 10) / 2;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    // Keep enough vertical room for icon, value and label on
                    // narrow phones and with larger accessibility text.
                    childAspectRatio: cardWidth / 150,
                    children: [
                      _kpi(
                        context,
                        '${snap.saved}',
                        'Saved',
                        Icons.bookmark_add_outlined,
                        _savedInRange(pool, days),
                      ),
                      _kpi(
                        context,
                        '${snap.opened}',
                        'Opened',
                        Icons.visibility_outlined,
                        _opened(pool),
                      ),
                      _kpi(
                        context,
                        '${snap.completed}',
                        'Completed',
                        Icons.task_alt_outlined,
                        _completed(pool),
                      ),
                      _kpi(
                        context,
                        '${(snap.completionRate * 100).round()}%',
                        'Completion rate',
                        Icons.done_all_outlined,
                        null,
                      ),
                      _kpi(
                        context,
                        '${snap.inProgress}',
                        'In progress',
                        Icons.trending_up_rounded,
                        _inProgress(pool),
                      ),
                      _kpi(
                        context,
                        '${snap.unread}',
                        'Unread',
                        Icons.mark_email_unread_outlined,
                        _unread(pool),
                      ),
                      _kpi(
                        context,
                        '${snap.neverOpened}',
                        'Never opened',
                        Icons.hourglass_empty_rounded,
                        _neverOpened(pool),
                      ),
                      _kpi(
                        context,
                        '${snap.reopened}',
                        'Reopened',
                        Icons.repeat_rounded,
                        _reopened(pool),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: Insets.l),

              _card(
                context,
                'Activity',
                'Items saved over time',
                BarChart(
                  values: snap.activityByDay,
                  labels: _bucketLabels(_days, snap.activityByDay.length),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                'Saved vs Completed',
                'Learning rhythm per period',
                GroupedBarChart(
                  saved: snap.activityByDay,
                  completed: snap.completedByDay,
                  labels: _bucketLabels(_days, snap.activityByDay.length),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                'Sources',
                'Where your library comes from',
                DonutChart(slices: snap.bySource),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                'Collections',
                'Completion by collection',
                _collectionsBars(scheme, vault),
              ),
              const SizedBox(height: Insets.l),

              _listSection(
                context,
                'Most opened',
                [...pool]..sort((a, b) => b.openCount.compareTo(a.openCount)),
                (e) => e.openCount > 0,
                (e) => '${e.openCount}×',
                Icons.local_fire_department_rounded,
              ),
              const SizedBox(height: 12),
              _listSection(
                context,
                'Never opened',
                [...pool]..sort((a, b) => a.addedAt.compareTo(b.addedAt)),
                (e) => e.openCount == 0,
                (e) => _daysLeftLabel(e),
                Icons.hourglass_bottom_outlined,
              ),
              const SizedBox(height: Insets.l),
              OutlinedButton.icon(
                onPressed: () => _export(context, vault),
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text('Export report'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- helpers ------------------------------------------------------------

  List<ResourceItem> _savedInRange(List<ResourceItem> pool, int days) {
    final from = DateTime.now().subtract(Duration(days: days));
    return pool.where((e) => e.addedAt.isAfter(from)).toList();
  }

  List<ResourceItem> _opened(List<ResourceItem> pool) =>
      pool.where((e) => e.openCount > 0).toList();
  List<ResourceItem> _completed(List<ResourceItem> pool) =>
      pool.where((e) => e.status == ResourceStatus.completed).toList();
  List<ResourceItem> _inProgress(List<ResourceItem> pool) =>
      pool.where((e) => e.status == ResourceStatus.inProgress).toList();
  List<ResourceItem> _unread(List<ResourceItem> pool) =>
      pool.where((e) => e.status == ResourceStatus.unread).toList();
  List<ResourceItem> _neverOpened(List<ResourceItem> pool) =>
      pool.where((e) => e.openCount == 0).toList();
  List<ResourceItem> _reopened(List<ResourceItem> pool) =>
      pool.where((e) => e.openCount > 1).toList();

  String _daysLeftLabel(ResourceItem e) {
    final d = DateTime.now().difference(e.addedAt).inDays;
    return '$d${d == 1 ? 'day' : 'days'} here';
  }

  List<String> _bucketLabels(int days, int n) {
    if (days <= 7) {
      const wk = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return List.generate(n, (i) => wk[i % 7]);
    }
    return List.generate(n, (i) => days <= 90 ? 'W${i + 1}' : 'P${i + 1}');
  }

  Widget _kpi(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    List<ResourceItem>? onTapItems,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: NotedBox.card(
        color: Colors.white,
        radius: Radii.card,
        shadowOffset: const Offset(2.5, 3.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapItems == null
              ? null
              : () => _showRelated(context, label, onTapItems),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRelated(
    BuildContext context,
    String label,
    List<ResourceItem> items,
  ) {
    LvSheet.show<void>(
      context,
      title: label,
      subtitle: '${items.length} item${items.length == 1 ? '' : 's'}',
      builder: (ctx) => items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nothing here yet.'),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items
                    .map(
                      (e) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        leading: LvThumb(item: e, size: 38),
                        title: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          e.source.isEmpty ? e.kind.label : e.source,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(
                            context,
                            '/details',
                            arguments: e.id,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    String subtitle,
    Widget child,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: Colors.white,
        radius: Radii.card,
        shadowOffset: const Offset(3, 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _collectionsBars(ColorScheme scheme, Vault vault) {
    if (vault.collections.isEmpty) {
      return Text(
        'No collections yet.',
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      children: vault.collections.map((c) {
        final items = vault.byCollection(c.id);
        final done = items
            .where((e) => e.status == ResourceStatus.completed)
            .length;
        final v = items.isEmpty ? 0.0 : done / items.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(c.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '$done/${items.length}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: v, minHeight: 6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _listSection(
    BuildContext context,
    String title,
    List<ResourceItem> sorted,
    bool Function(ResourceItem) filter,
    String Function(ResourceItem) trailing,
    IconData emptyIcon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = sorted.where(filter).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: Colors.white,
        radius: Radii.card,
        shadowOffset: const Offset(3, 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          if (items.isEmpty)
            Text(
              'Nothing here yet.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            )
          else
            ...items.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: LvThumb(item: e, size: 38),
                title: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  e.source.isEmpty ? e.kind.label : e.source,
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trailing(e),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onTap: () =>
                    Navigator.pushNamed(context, '/details', arguments: e.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, Vault vault) async {
    final scheme = Theme.of(context).colorScheme;
    final fmt = await LvSheet.show<String>(
      context,
      title: 'Export report',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.data_object_rounded),
            title: const Text(
              'JSON',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Full library, ready to re-import'),
            onTap: () => Navigator.pop(ctx, 'json'),
          ),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text(
              'CSV summary',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'KPIs for ${_ranges.firstWhere((r) => r.$1 == _days).$2} range',
            ),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
        ],
      ),
    );
    if (fmt == null || !context.mounted) return;

    // progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!context.mounted) return;
    Navigator.pop(context); // close progress

    if (vault.simulateBackupFailure) {
      LvDialog.show(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: scheme.error,
        title: 'Export failed',
        message: 'Something went wrong writing the file. Please try again.',
        confirmLabel: 'Retry',
        onConfirm: () => _export(context, vault),
      );
      return;
    }
    LvSnackbar.show(
      context,
      'Exported learning-vault-${DateTime.now().toIso8601String().split('T').first}.${fmt == 'json' ? 'json' : 'csv'}',
      icon: Icons.file_download_done_rounded,
    );
  }
}
