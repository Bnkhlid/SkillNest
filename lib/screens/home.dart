import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../core/utils/share_parser.dart';
import '../main.dart';
import '../models.dart';
import 'add_resource.dart';
import '../vault.dart';
import '../widgets/components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _showCreateStickyNote(BuildContext context) {
    final titleCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    Color selectedColor = NotedColors.yellowLight;
    bool isBullet = false;

    final colors = [
      ('Yellow', NotedColors.yellowLight),
      ('Pink', NotedColors.pinkCard),
      ('Mint', NotedColors.mintCard),
      ('Purple', NotedColors.purpleLight),
      ('Blue', NotedColors.blueLight),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final maxDialogHeight = MediaQuery.sizeOf(ctx).height * .72;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: NotedColors.border, width: 2.2),
            ),
            backgroundColor: Colors.white,
            title: const Text(
              'New Sticky Note',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: NotedColors.ink,
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Wednesday Tasks, Reading',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: NotedColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.map((c) {
                        final isSel = selectedColor == c.$2;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = c.$2),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.$2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? NotedColors.ink
                                    : NotedColors.border,
                                width: isSel ? 2.5 : 1.5,
                              ),
                            ),
                            child: isSel
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: NotedColors.ink,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: NotedColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tasks (Checkbox)'),
                          selected: !isBullet,
                          onSelected: (v) =>
                              setDialogState(() => isBullet = !v),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Bullets'),
                          selected: isBullet,
                          onSelected: (v) => setDialogState(() => isBullet = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: itemsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Items (one per line)',
                        hintText: 'Task 1\nTask 2\nTask 3',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NotedColors.yellow,
                  foregroundColor: NotedColors.ink,
                  side: const BorderSide(color: NotedColors.border, width: 2),
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim().isEmpty
                      ? 'Note'
                      : titleCtrl.text.trim();
                  final rawLines = itemsCtrl.text
                      .split('\n')
                      .map((l) => l.trim())
                      .where((l) => l.isNotEmpty)
                      .toList();

                  final lines = rawLines.isEmpty ? ['New item'] : rawLines;

                  await Vault.I.addStickyNote(
                    title: title,
                    color: selectedColor,
                    items: lines,
                    isBullet: isBullet,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'Create Note',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteStickyNote(
    BuildContext context,
    String noteId,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NotedColors.border, width: 2.2),
        ),
        title: const Text(
          'Delete Note',
          style: TextStyle(fontWeight: FontWeight.w800, color: NotedColors.ink),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: NotedColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NotedColors.pink,
              foregroundColor: Colors.white,
              side: const BorderSide(color: NotedColors.border, width: 2),
            ),
            onPressed: () async {
              await Vault.I.deleteStickyNote(noteId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTaskItem(
    BuildContext context,
    String noteId,
    String itemId,
    String taskText,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NotedColors.border, width: 2.2),
        ),
        title: const Text(
          'Delete Task',
          style: TextStyle(fontWeight: FontWeight.w800, color: NotedColors.ink),
        ),
        content: Text(
          'Are you sure you want to delete "$taskText"?',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: NotedColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NotedColors.pink,
              foregroundColor: Colors.white,
              side: const BorderSide(color: NotedColors.border, width: 2),
            ),
            onPressed: () async {
              await Vault.I.deleteStickyItem(noteId, itemId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _openDetails(ResourceItem item) {
    Navigator.pushNamed(context, RoutePaths.details, arguments: item.id);
  }

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;

    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: vault,
          builder: (context, _) {
            if (_loading) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 24),
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: NotedColors.border,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 14, width: 160),
                          SizedBox(height: 8),
                          SkeletonBox(height: 11, width: 110),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SkeletonBox(height: 18, width: 150),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 156,
                    child: Row(
                      children: [
                        Expanded(child: SkeletonContinueCard()),
                        SizedBox(width: 10),
                        Expanded(child: SkeletonContinueCard()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SkeletonBox(height: 110, radius: 16),
                  const SizedBox(height: 28),
                  const SkeletonBox(height: 18, width: 120),
                  const SizedBox(height: 16),
                  ...skeletonList(context, count: 2),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  toolbarHeight: 74,
                  pinned: true,
                  backgroundColor: NotedColors.canvasLight,
                  title: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: NotedColors.yellow,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: NotedColors.border,
                            width: 2.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: NotedColors.shadow,
                              offset: Offset(2, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          vault.userName.isNotEmpty
                              ? vault.userName[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: NotedColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_greeting, ${vault.userName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: NotedColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vault.unreadCount} unread · ${vault.inboxCount} notes in vault',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: NotedColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    LvIconBtn(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onTap: () =>
                          Navigator.pushNamed(context, RoutePaths.settings),
                    ),
                    LvIconBtn(
                      icon: Icons.search_rounded,
                      tooltip: 'Search',
                      onTap: () => appTab.value = 1,
                    ),
                    Stack(
                      children: [
                        LvIconBtn(
                          icon: Icons.notifications_none_rounded,
                          tooltip: 'Notifications',
                          onTap: () => _showNotifications(context),
                        ),
                        if (vault.unreadNotificationCount > 0)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: NotedColors.pink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: NotedColors.border,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (vault.offlineDemo) ...[
                        const OfflineBanner(),
                        const SizedBox(height: Insets.m),
                      ],

                      // ── Sticky Notes Carousel (from Figma) ────────────────
                      SectionHeader(
                        'My Sticky Notes',
                        actionLabel: 'New +',
                        onAction: () => _showCreateStickyNote(context),
                      ),
                      if (vault.stickyNotes.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Insets.m),
                          decoration: NotedBox.card(
                            color: Colors.white,
                            radius: 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: NotedColors.yellowLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: NotedColors.border,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.sticky_note_2_outlined,
                                  color: NotedColors.ink,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No sticky notes yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: NotedColors.ink,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap "New +" to create quick tasks or notes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: NotedColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NotedColors.yellow,
                                  foregroundColor: NotedColors.ink,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showCreateStickyNote(context),
                                child: const Text(
                                  'New +',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: vault.stickyNotes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, noteIdx) {
                              final note = vault.stickyNotes[noteIdx];
                              return NotedStickyCard(
                                title: note.title,
                                color: note.color,
                                width: 235,
                                onDelete: () => _confirmDeleteStickyNote(
                                  context,
                                  note.id,
                                  note.title,
                                ),
                                items: note.items.map((it) {
                                  return NotedCardItem(
                                    text: it.text,
                                    isBullet: it.isBullet,
                                    state: it.state,
                                    onToggle: () {
                                      final nextState = it.isBullet
                                          ? (it.state ==
                                                    NotedCheckState.completed
                                                ? NotedCheckState.unchecked
                                                : NotedCheckState.completed)
                                          : (switch (it.state) {
                                              NotedCheckState.unchecked =>
                                                NotedCheckState.completed,
                                              NotedCheckState.completed =>
                                                NotedCheckState.discarded,
                                              NotedCheckState.discarded =>
                                                NotedCheckState.unchecked,
                                            });
                                      vault.updateStickyItemState(
                                        note.id,
                                        it.id,
                                        nextState,
                                      );
                                    },
                                    onDelete: () {
                                      _confirmDeleteTaskItem(
                                        context,
                                        note.id,
                                        it.id,
                                        it.text,
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: Insets.l),

                      // ── Continue Learning ─────────────────────────────────
                      _ContinueSection(onOpen: _openDetails),
                      const SizedBox(height: Insets.l),

                      // ── Progress Card ─────────────────────────────────────
                      _ProgressCard(
                        onAnalytics: () =>
                            Navigator.pushNamed(context, RoutePaths.analytics),
                      ),
                      const SizedBox(height: Insets.l),

                      // ── Recent Saves ──────────────────────────────────────
                      _RecentSection(onOpen: _openDetails),
                      const SizedBox(height: Insets.l),

                      // ── Inbox Card ────────────────────────────────────────
                      _InboxCard(
                        onOpenInbox: () =>
                            Navigator.pushNamed(context, RoutePaths.inbox),
                      ),
                      const SizedBox(height: Insets.l),

                      // ── Quick Actions ─────────────────────────────────────
                      _QuickAddRow(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final vault = Vault.I;
    LvSheet.show(
      context,
      title: 'Notifications',
      builder: (ctx) => ListenableBuilder(
        listenable: vault,
        builder: (ctx, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vault.notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('You\u2019re all caught up.'),
              )
            else
              ...vault.notifications.map(
                (n) => ListTile(
                  onTap: () {
                    vault.readNotification(n);
                    Navigator.pop(ctx);
                    if (n.resourceId != null &&
                        vault.find(n.resourceId!) != null) {
                      Navigator.pushNamed(
                        ctx,
                        RoutePaths.details,
                        arguments: n.resourceId,
                      );
                    } else {
                      Navigator.pushNamed(ctx, RoutePaths.inbox);
                    }
                  },
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: n.read ? Colors.white : NotedColors.yellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: NotedColors.border, width: 1.8),
                    ),
                    child: Icon(n.icon, size: 19, color: NotedColors.ink),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    n.body,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: n.read
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: NotedColors.pink,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
            if (vault.notifications.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Use Quick Add to save a source, then its updates will appear here.',
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(ctx, RoutePaths.add);
                },
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Save a source'),
              ),
            ] else
              TextButton(
                onPressed: () => vault.markAllNotificationsRead(),
                child: const Text('Mark all as read'),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  const _ContinueSection({required this.onOpen});

  final void Function(ResourceItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;
    final items = vault.continueLearning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Continue Learning',
          actionLabel: 'See All',
          onAction: () => Navigator.pushNamed(context, RoutePaths.inbox),
        ),
        if (items.isEmpty)
          const Text(
            'Nothing in progress yet — open a save to pick up where you left off.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: NotedColors.inkMuted,
            ),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  ContinueCard(item: items[i], onOpen: () => onOpen(items[i])),
            ),
          ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.onAnalytics});

  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;
    final total = vault.items.length;
    final done = vault.items
        .where((e) => e.status == ResourceStatus.completed)
        .length;
    final inProg = vault.items
        .where((e) => e.status == ResourceStatus.inProgress)
        .length;

    return Container(
      decoration: NotedBox.card(color: NotedColors.yellow, radius: 18),
      padding: const EdgeInsets.all(Insets.m),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NotedColors.border, width: 2),
            ),
            child: ProgressRing(
              value: total == 0 ? 0 : done / total,
              size: 56,
              stroke: 6.5,
            ),
          ),
          const SizedBox(width: Insets.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$done completed · $inProg in progress',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: NotedColors.ink,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: onAnalytics,
                    child: const Text(
                      'View Analytics',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.onOpen});

  final void Function(ResourceItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;
    final recent = vault.recentSaves.take(3).toList();
    return Column(
      children: [
        SectionHeader(
          'Recent Saves',
          actionLabel: 'See All',
          onAction: () => Navigator.pushNamed(context, RoutePaths.inbox),
        ),
        ...recent.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceTile(
              item: e,
              onOpen: () => onOpen(e),
              trailingFavorite: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.onOpenInbox});

  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    final vault = Vault.I;
    return Container(
      decoration: NotedBox.card(color: NotedColors.mintLight, radius: 18),
      padding: const EdgeInsets.all(Insets.m),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.thumb),
              border: Border.all(color: NotedColors.border, width: 2),
            ),
            child: const Icon(Icons.inbox_rounded, color: NotedColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vault.inboxCount} saved · auto-synced',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NotedColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: NotedColors.ink,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onOpenInbox,
            child: const Text(
              'Open Inbox',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  Future<void> _pasteClipboardLink(BuildContext context) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim() ?? '';
    final url = ShareParser.extractUrl(text) ?? text;

    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      RoutePaths.add,
      arguments: AddArgs(
        initialUrl: url.isEmpty ? null : url,
        source: AddSource.link,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.note_add_rounded, 'New note', NotedColors.yellowLight),
      (Icons.link_rounded, 'Paste link', NotedColors.mintLight),
      (Icons.upload_file_rounded, 'Upload file', NotedColors.pinkLight),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick Add'),
        Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      decoration: NotedBox.card(
                        color: a.$3,
                        radius: 16,
                        shadow: true,
                        shadowOffset: const Offset(2.5, 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (a.$2 == 'Paste link') {
                              _pasteClipboardLink(context);
                            } else {
                              Navigator.pushNamed(
                                context,
                                RoutePaths.add,
                                arguments: AddArgs(
                                  source: a.$2 == 'New note'
                                      ? AddSource.note
                                      : AddSource.file,
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              children: [
                                Icon(a.$1, size: 24, color: NotedColors.ink),
                                const SizedBox(height: 6),
                                Text(
                                  a.$2,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: NotedColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
