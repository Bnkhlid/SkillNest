import 'dart:async';
import 'dart:io';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    Color selectedColor =
        isDark ? NotedColors.pastelCard(0, isDark: true) : NotedColors.yellowLight;
    bool isBullet = false;

    final colors = [
      ('Yellow', isDark ? NotedColors.pastelCard(0, isDark: true) : NotedColors.yellowLight),
      ('Pink', isDark ? NotedColors.pastelCard(2, isDark: true) : NotedColors.pinkCard),
      ('Mint', isDark ? NotedColors.pastelCard(1, isDark: true) : NotedColors.mintCard),
      ('Purple', isDark ? NotedColors.pastelCard(3, isDark: true) : NotedColors.purpleLight),
      ('Blue', isDark ? NotedColors.pastelCard(4, isDark: true) : NotedColors.blueLight),
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
              side: BorderSide(
                color: isDark ? scheme.outlineVariant : NotedColors.border,
                width: 2.2,
              ),
            ),
            backgroundColor:
                isDark ? scheme.surfaceContainerLow : Colors.white,
            title: Text(
              'New Sticky Note',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
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
                    Text(
                      'Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: scheme.onSurface,
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
                                    ? (isDark ? Colors.white : NotedColors.ink)
                                    : (isDark
                                        ? scheme.outlineVariant
                                        : NotedColors.border),
                                width: isSel ? 2.5 : 1.5,
                              ),
                            ),
                            child: isSel
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color:
                                        isDark ? Colors.white : NotedColors.ink,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: scheme.onSurface,
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
                child: Text(
                  'Cancel',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? const Color(0xFF352C16) : NotedColors.yellow,
                  foregroundColor: isDark ? Colors.white : NotedColors.ink,
                  side: BorderSide(
                    color: isDark ? const Color(0xFFFFC107) : NotedColors.border,
                    width: 2,
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? scheme.outlineVariant : NotedColors.border,
            width: 2.2,
          ),
        ),
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        title: Text(
          'Delete Note',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: Colors.white,
              side: BorderSide(
                color: isDark ? scheme.outlineVariant : NotedColors.border,
                width: 2,
              ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? scheme.outlineVariant : NotedColors.border,
            width: 2.2,
          ),
        ),
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        title: Text(
          'Delete Task',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$taskText"?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: Colors.white,
              side: BorderSide(
                color: isDark ? scheme.outlineVariant : NotedColors.border,
                width: 2,
              ),
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

  void _promptAddStickyItem(BuildContext context, StickyNoteModel note) {
    final textCtrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isBullet = note.items.isNotEmpty ? note.items.first.isBullet : false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? scheme.outlineVariant : NotedColors.border,
              width: 2.2,
            ),
          ),
          backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
          title: Text(
            'Add to "${note.title}"',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Item text',
                  hintText: 'e.g. Review chapter 2',
                ),
                onSubmitted: (val) async {
                  if (val.trim().isNotEmpty) {
                    await Vault.I.addStickyItem(
                      note.id,
                      val.trim(),
                      isBullet: isBullet,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Task (Checkbox)'),
                    selected: !isBullet,
                    onSelected: (v) => setDialogState(() => isBullet = !v),
                  ),
                  ChoiceChip(
                    label: const Text('Bullet'),
                    selected: isBullet,
                    onSelected: (v) => setDialogState(() => isBullet = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF352C16) : NotedColors.yellow,
                foregroundColor: isDark ? Colors.white : NotedColors.ink,
                side: BorderSide(
                  color: isDark ? const Color(0xFFFFC107) : NotedColors.border,
                  width: 2,
                ),
              ),
              onPressed: () async {
                final text = textCtrl.text.trim();
                if (text.isNotEmpty) {
                  await Vault.I.addStickyItem(
                    note.id,
                    text,
                    isBullet: isBullet,
                  );
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: scheme.surface,
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
                          color: isLight ? Colors.white : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLight ? NotedColors.border : scheme.outline,
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
                  backgroundColor: scheme.surface,
                  title: Row(
                    children: [
                      GestureDetector(
                        onTap: () => promptAvatarPicker(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (vault.userAvatarPath != null &&
                                        File(vault.userAvatarPath!).existsSync())
                                    ? Colors.transparent
                                    : NotedColors.yellow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isLight ? NotedColors.border : scheme.outline,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isLight ? NotedColors.shadow : Colors.black,
                                    offset: const Offset(2, 2.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: (vault.userAvatarPath != null &&
                                      File(vault.userAvatarPath!).existsSync())
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(vault.userAvatarPath!),
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44,
                                      ),
                                    )
                                  : Text(
                                      vault.userName.isNotEmpty
                                          ? vault.userName[0].toUpperCase()
                                          : '✨',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: NotedColors.ink,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: -3,
                              bottom: -3,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : const Color(0xFF262626),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isLight ? NotedColors.border : scheme.outline,
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 9,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              vault.userName.isNotEmpty
                                  ? '$_greeting, ${vault.userName}'
                                  : _greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vault.unreadCount} unread · ${vault.inboxCount} in vault',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    LvIconBtn(
                      icon: vault.themeMode == ThemeMode.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      tooltip: vault.themeMode == ThemeMode.dark
                          ? 'Light mode'
                          : 'Dark mode',
                      onTap: () {
                        vault.setThemeMode(
                          vault.themeMode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark,
                        );
                      },
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
                    LvIconBtn(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onTap: () =>
                          Navigator.pushNamed(context, RoutePaths.settings),
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
                            color: !isLight ? scheme.surfaceContainerLow : Colors.white,
                            radius: 18,
                            borderColor: !isLight ? scheme.outlineVariant : NotedColors.border,
                            shadowColor: !isLight ? Colors.black : NotedColors.shadow,
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
                                    color: isLight ? NotedColors.border : scheme.outlineVariant,
                                    width: 2,
                                  ),
                                ),
                               child: Icon(
                                 Icons.sticky_note_2_outlined,
                                  color: NotedColors.ink,
                               ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No sticky notes yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isLight ? NotedColors.ink : scheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap "New +" to create quick tasks or notes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isLight ? NotedColors.inkMuted : scheme.onSurfaceVariant,
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
                                onAddItem: () => _promptAddStickyItem(
                                  context,
                                  note,
                                ),
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
    unawaited(Vault.I.syncActiveSystemNotifications());
    final vault = Vault.I;
    LvSheet.show(
      context,
      title: 'Notifications',
      builder: (ctx) => ListenableBuilder(
        listenable: vault,
        builder: (ctx, _) {
          final scheme = Theme.of(ctx).colorScheme;
          final isLight = Theme.of(ctx).brightness == Brightness.light;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vault.notifications.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'You’re all caught up.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Use Quick Add to save a source, then its updates will appear here.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(ctx, RoutePaths.add);
                        },
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Save a source'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => vault.clearAllNotifications(),
                          icon: Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                            color: scheme.error,
                          ),
                          label: Text(
                            'Clear all',
                            style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => vault.markAllNotificationsRead(),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text(
                            'Mark all as read',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: vault.notifications.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (ctx, i) {
                        final n = vault.notifications[i];
                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: scheme.errorContainer,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: scheme.errorContainer,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) {
                            vault.deleteNotification(n.id);
                          },
                          child: ListTile(
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
                                color: n.read
                                    ? (isLight
                                        ? Colors.white
                                        : scheme.surfaceContainerHigh)
                                    : (isLight
                                        ? NotedColors.yellow
                                        : const Color(0xFF352C16)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isLight
                                      ? NotedColors.border
                                      : (n.read
                                          ? scheme.outlineVariant
                                          : const Color(0xFFFFC107)),
                                  width: 1.8,
                                ),
                              ),
                              child: Icon(
                                n.icon,
                                size: 19,
                                color: isLight
                                    ? NotedColors.ink
                                    : (n.read
                                        ? scheme.onSurfaceVariant
                                        : Colors.white),
                              ),
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    n.read ? FontWeight.w600 : FontWeight.w800,
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
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = vault.items.length;
    final done = vault.items
        .where((e) => e.status == ResourceStatus.completed)
        .length;
    final inProg = vault.items
        .where((e) => e.status == ResourceStatus.inProgress)
        .length;

    return Container(
      decoration: NotedBox.card(
        color: isDark ? const Color(0xFF332A18) : NotedColors.yellow,
        radius: 18,
        borderColor: isDark
            ? const Color(0xFFFFC107).withValues(alpha: 0.4)
            : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
      ),
      padding: const EdgeInsets.all(Insets.m),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFFFC107).withValues(alpha: 0.5)
                    : NotedColors.border,
                width: 2,
              ),
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
                Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$done completed · $inProg in progress',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? scheme.onSurfaceVariant : NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? scheme.surfaceContainerHigh : Colors.white,
                      foregroundColor:
                          isDark ? scheme.onSurface : NotedColors.ink,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: BorderSide(
                        color:
                            isDark ? scheme.outlineVariant : NotedColors.border,
                        width: 2,
                      ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = NotedColors.pastelCard(1, isDark: isDark);
    final accentColor = NotedColors.collectionAccent(1);

    return Container(
      decoration: NotedBox.card(
        color: cardColor,
        radius: 18,
        borderColor: isDark
            ? accentColor.withValues(alpha: 0.4)
            : NotedColors.border,
        shadowColor: isDark ? Colors.black : NotedColors.shadow,
      ),
      padding: const EdgeInsets.all(Insets.m),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(Radii.thumb),
              border: Border.all(
                color: isDark
                    ? accentColor.withValues(alpha: 0.5)
                    : NotedColors.border,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.inbox_rounded,
              color: isDark ? accentColor : NotedColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vault.inboxCount} saved · auto-synced',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? scheme.onSurfaceVariant : NotedColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? scheme.surfaceContainerHigh : Colors.white,
              foregroundColor:
                  isDark ? scheme.onSurface : NotedColors.ink,
              side: BorderSide(
                color: isDark ? scheme.outlineVariant : NotedColors.border,
                width: 2,
              ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = [
      (Icons.note_add_rounded, 'New note', NotedColors.pastelCard(0, isDark: isDark)),
      (Icons.link_rounded, 'Paste link', NotedColors.pastelCard(1, isDark: isDark)),
      (Icons.upload_file_rounded, 'Upload file', NotedColors.pastelCard(2, isDark: isDark)),
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
                        borderColor: isDark ? scheme.outlineVariant : NotedColors.border,
                        shadowColor: isDark ? Colors.black : NotedColors.shadow,
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
                                Icon(
                                  a.$1,
                                  size: 24,
                                  color: isDark ? scheme.onSurface : NotedColors.ink,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.$2,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? scheme.onSurface : NotedColors.ink,
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
