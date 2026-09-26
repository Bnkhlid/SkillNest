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

enum _AnalyticsTab { overview, activity, topics }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 30;
  String? _collectionFilter;
  _AnalyticsTab _currentTab = _AnalyticsTab.overview;

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

        final streakData = _calculateStreak(pool);
        final insights = _generateInsights(pool);

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            backgroundColor: scheme.surface,
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
              // Top Segmented Tab Selector
              SegmentedButton<_AnalyticsTab>(
                segments: const [
                  ButtonSegment(
                    value: _AnalyticsTab.overview,
                    icon: Icon(Icons.dashboard_outlined, size: 16),
                    label: Text('Overview'),
                  ),
                  ButtonSegment(
                    value: _AnalyticsTab.activity,
                    icon: Icon(Icons.insights_rounded, size: 16),
                    label: Text('Activity'),
                  ),
                  ButtonSegment(
                    value: _AnalyticsTab.topics,
                    icon: Icon(Icons.category_outlined, size: 16),
                    label: Text('Topics'),
                  ),
                ],
                selected: {_currentTab},
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) {
                    setState(() => _currentTab = selected.first);
                  }
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: Insets.m),

              // TAB 1: OVERVIEW
              if (_currentTab == _AnalyticsTab.overview) ...[
                // Learning Streak Card
                _streakCard(context, scheme, streakData),
                const SizedBox(height: Insets.m),

                // Time range chips
                _timeRangeSelector(),
                const SizedBox(height: Insets.m),

                // Smart Insights Section
                if (insights.isNotEmpty) ...[
                  _smartInsightsSection(context, scheme, insights),
                  const SizedBox(height: Insets.m),
                ],

                // KPI grid
                _kpiGrid(context, scheme, snap, pool, days),
                const SizedBox(height: 12),

                // Monthly Progress / Goal Card
                _monthlyGoalCard(context, scheme, pool),
              ],

              // TAB 2: ACTIVITY & TRENDS
              if (_currentTab == _AnalyticsTab.activity) ...[
                // Time range chips
                _timeRangeSelector(),
                const SizedBox(height: Insets.m),

                // Activity Charts
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
              ],

              // TAB 3: TOPICS & MEDIA
              if (_currentTab == _AnalyticsTab.topics) ...[
                // Content Format Breakdown
                _card(
                  context,
                  'Content Formats',
                  'Resources & completion by type',
                  _formatBreakdown(scheme, pool),
                ),
                const SizedBox(height: 12),

                // Top Topics & Tags
                _card(
                  context,
                  'Top Topics & Tags',
                  'Most frequent subjects in your library',
                  _topTagsBreakdown(scheme, pool),
                ),
                const SizedBox(height: Insets.l),

                // Quick Action Lists
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
            ],
          ),
        );
      },
    );
  }

  Widget _timeRangeSelector() {
    return SingleChildScrollView(
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
    );
  }

  Widget _kpiGrid(
    BuildContext context,
    ColorScheme scheme,
    AnalyticsSnapshot snap,
    List<ResourceItem> pool,
    int days,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
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
    );
  }

  // ---- 1. Streak Tracker ---------------------------------------------------

  _StreakInfo _calculateStreak(List<ResourceItem> pool) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeDates = <DateTime>{};
    for (final item in pool) {
      activeDates.add(DateTime(item.addedAt.year, item.addedAt.month, item.addedAt.day));
      if (item.lastOpenedAt != null) {
        activeDates.add(DateTime(item.lastOpenedAt!.year, item.lastOpenedAt!.month, item.lastOpenedAt!.day));
      }
    }

    int currentStreak = 0;
    DateTime checkDay = today;
    if (!activeDates.contains(today)) {
      checkDay = today.subtract(const Duration(days: 1));
    }

    while (activeDates.contains(checkDay)) {
      currentStreak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    // Last 7 days status (from 6 days ago to today)
    final last7Days = <(String, bool)>[];
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final label = weekdayLabels[d.weekday - 1];
      final active = activeDates.contains(d);
      last7Days.add((label, active));
    }

    return _StreakInfo(
      streakCount: currentStreak,
      isActiveToday: activeDates.contains(today),
      last7Days: last7Days,
    );
  }

  Widget _streakCard(BuildContext context, ColorScheme scheme, _StreakInfo info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: isDark ? const Color(0xFF2A2211) : const Color(0xFFFFF9E6),
        borderColor: isDark ? const Color(0xFFFFC107) : NotedColors.border,
        radius: Radii.card,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.streakCount > 0
                          ? '${info.streakCount} Day Learning Streak!'
                          : 'Start Your Streak Today!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.isActiveToday
                          ? 'Great job! You continued your streak today.'
                          : 'Save or open a resource today to keep your streak burning!',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: info.last7Days.map((entry) {
              final label = entry.$1;
              final active = entry.$2;
              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? (isDark ? const Color(0xFFFFC107) : NotedColors.yellow)
                          : (isDark ? scheme.surfaceContainerHigh : const Color(0xFFEBE6D8)),
                      border: Border.all(
                        color: active
                            ? NotedColors.border
                            : scheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: active
                        ? const Icon(Icons.check_rounded, size: 20, color: NotedColors.ink)
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---- 2. Smart Insights (Neo-Brutalist Pastel Cards) ----------------------

  List<_InsightItem> _generateInsights(List<ResourceItem> pool) {
    if (pool.isEmpty) return [];
    final insights = <_InsightItem>[];

    // Peak day calculation
    final dayCounts = List<int>.filled(7, 0);
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final e in pool) {
      dayCounts[e.addedAt.weekday - 1]++;
    }
    int bestDayIdx = 0;
    int maxAdds = 0;
    for (int i = 0; i < 7; i++) {
      if (dayCounts[i] > maxAdds) {
        maxAdds = dayCounts[i];
        bestDayIdx = i;
      }
    }
    if (maxAdds > 0) {
      insights.add(
        _InsightItem(
          icon: Icons.trending_up_rounded,
          colorIndex: 0,
          title: 'Productivity Peak',
          description: '${dayNames[bestDayIdx]} is your most active day for saving & learning.',
        ),
      );
    }

    // Stale resources
    final stale = pool.where((e) => e.openCount == 0 && DateTime.now().difference(e.addedAt).inDays >= 14).toList();
    if (stale.isNotEmpty) {
      insights.add(
        _InsightItem(
          icon: Icons.inventory_2_outlined,
          colorIndex: 1,
          title: 'Unread Items',
          description: '${stale.length} unread ${stale.length == 1 ? 'item' : 'items'} waiting for you from past weeks.',
          actionLabel: 'Review',
          onTapItems: stale,
        ),
      );
    }

    // Completion mastery
    final completed = pool.where((e) => e.status == ResourceStatus.completed).length;
    if (pool.isNotEmpty) {
      final rate = (completed / pool.length * 100).round();
      insights.add(
        _InsightItem(
          icon: Icons.auto_graph_rounded,
          colorIndex: 2,
          title: 'Knowledge Flow',
          description: 'You completed $rate% of your saved resources. Keep the momentum going!',
        ),
      );
    }

    return insights;
  }

  Widget _smartInsightsSection(BuildContext context, ColorScheme scheme, List<_InsightItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 19,
                color: isDark ? const Color(0xFFFFC107) : NotedColors.ink,
              ),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              final cardBg = NotedColors.pastelCard(item.colorIndex, isDark: isDark);

              return Container(
                width: 250,
                decoration: NotedBox.card(
                  color: cardBg,
                  radius: Radii.note,
                  borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
                  shadowColor: isDark ? Colors.black : NotedColors.shadow,
                  shadowOffset: const Offset(3, 4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.note),
                    onTap: item.onTapItems != null
                        ? () => _showRelated(context, item.title, item.onTapItems!)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black26
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? scheme.outlineVariant : NotedColors.border,
                                    width: 1.4,
                                  ),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 17,
                                  color: isDark ? Colors.white : NotedColors.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : NotedColors.ink,
                                  ),
                                ),
                              ),
                              if (item.actionLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : NotedColors.yellow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? Colors.white30 : NotedColors.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    item.actionLabel!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : NotedColors.ink,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              item.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : NotedColors.ink.withValues(alpha: 0.85),
                              ),
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
  }

  // ---- 3. Monthly Goal Tracker ---------------------------------------------

  Widget _monthlyGoalCard(BuildContext context, ColorScheme scheme, List<ResourceItem> pool) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);

    final completedThisMonth = pool.where((e) {
      return e.status == ResourceStatus.completed &&
          e.lastOpenedAt != null &&
          e.lastOpenedAt!.isAfter(thisMonthStart);
    }).length;

    const monthlyTarget = 10;
    final progress = (completedThisMonth / monthlyTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: Radii.card,
        borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
        shadowOffset: const Offset(3, 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Goal',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$completedThisMonth / $monthlyTarget Done',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Target to complete $monthlyTarget resources this month',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isDark ? scheme.surfaceContainerHighest : const Color(0xFFEBE6D8),
              valueColor: const AlwaysStoppedAnimation(NotedColors.mint),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 4. Content Format Breakdown -----------------------------------------

  Widget _formatBreakdown(ColorScheme scheme, List<ResourceItem> pool) {
    if (pool.isEmpty) {
      return Text('No resources yet.', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant));
    }

    final formats = [
      (ResourceKind.page, 'Links & Articles', Icons.language_rounded, const Color(0xFF42A5F5)),
      (ResourceKind.video, 'Videos', Icons.play_circle_outline_rounded, const Color(0xFFF06292)),
      (ResourceKind.pdf, 'PDFs & Docs', Icons.picture_as_pdf_outlined, const Color(0xFFFF9800)),
      (ResourceKind.note, 'Notes & Pastes', Icons.edit_note_rounded, const Color(0xFF2EB872)),
    ];

    return Column(
      children: formats.map((fmt) {
        final kind = fmt.$1;
        final label = fmt.$2;
        final icon = fmt.$3;
        final color = fmt.$4;

        final itemsOfKind = pool.where((e) => e.kind == kind).toList();
        final done = itemsOfKind.where((e) => e.status == ResourceStatus.completed).length;
        final total = itemsOfKind.length;
        final rate = total == 0 ? 0.0 : done / total;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                        ),
                        Text(
                          '$done/$total (${(rate * 100).round()}%)',
                          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
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

  // ---- 5. Top Topics & Tags ------------------------------------------------

  Widget _topTagsBreakdown(ColorScheme scheme, List<ResourceItem> pool) {
    final tagCounts = <String, (int, int)>{}; // tag -> (total, completed)
    for (final e in pool) {
      for (final tag in e.tags) {
        final current = tagCounts[tag] ?? (0, 0);
        final isDone = e.status == ResourceStatus.completed ? 1 : 0;
        tagCounts[tag] = (current.$1 + 1, current.$2 + isDone);
      }
    }

    if (tagCounts.isEmpty) {
      return Text(
        'Add tags to your resources to see topic insights.',
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      );
    }

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedTags.take(8).map((entry) {
        final tag = entry.key;
        final total = entry.value.$1;
        final done = entry.value.$2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('#$tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$done/$total',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: Radii.card,
        borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: Radii.card,
        borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = sorted.where(filter).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(Insets.m),
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: Radii.card,
        borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
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
                    color: isDark
                        ? scheme.surfaceContainerHigh
                        : scheme.surfaceContainer,
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

class _StreakInfo {
  final int streakCount;
  final bool isActiveToday;
  final List<(String, bool)> last7Days;

  _StreakInfo({
    required this.streakCount,
    required this.isActiveToday,
    required this.last7Days,
  });
}

class _InsightItem {
  final IconData icon;
  final int colorIndex;
  final String title;
  final String description;
  final String? actionLabel;
  final List<ResourceItem>? onTapItems;

  _InsightItem({
    required this.icon,
    required this.colorIndex,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onTapItems,
  });
}
