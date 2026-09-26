import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../app_theme.dart';
import '../core/utils/external_launcher.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';
import '../main.dart' show RoutePaths;

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: Vault.I.find(widget.itemId)?.note ?? '',
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openLocalFile(BuildContext context, ResourceItem e) async {
    final file = e.localFile;
    if (file == null) return;
    final exists =
        await Vault.I.fileRepo?.fileExistsOnDisk(file.localPath) ?? false;
    if (!exists) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: NotedColors.pink,
            size: 28,
          ),
          title: const Text('File unavailable', textAlign: TextAlign.center),
          content: const Text(
            'The local file could not be found at its saved location.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NotedColors.pink,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Vault.I.removeFile(e.id);
                Navigator.pop(ctx);
                LvSnackbar.show(context, 'Removed broken file attachment');
              },
              child: const Text('Remove attachment'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      Vault.I.registerOpen(e.id);
      final res = await OpenFilex.open(file.localPath);
      if (res.type != ResultType.done && context.mounted) {
        LvSnackbar.show(
          context,
          'Could not open file: ${res.message}',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (_) {
      if (context.mounted) {
        LvSnackbar.show(
          context,
          'Failed to launch file viewer',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, ResourceItem e) async {
    final raw = e.url.trim();
    if (raw.isEmpty) return;
    Vault.I.registerOpen(e.id);
    final ok = await ExternalLauncher.openUrl(raw);
    if (!ok && context.mounted) {
      LvSnackbar.show(
        context,
        'Could not open link in external app',
        icon: Icons.open_in_browser_rounded,
      );
    }
  }

  Future<void> _copyNote(ResourceItem e) async {
    final content = e.note.trim();
    if (content.isEmpty) {
      LvSnackbar.show(
        context,
        'Write a note first',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      LvSnackbar.show(context, 'Note copied', icon: Icons.content_copy_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: Vault.I,
      builder: (context, _) {
        final e = Vault.I.find(widget.itemId);
        if (e == null) {
          return const Scaffold(
            body: Center(child: Text('Resource not found')),
          );
        }

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            backgroundColor: scheme.surface,
            leading: BackButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed(RoutePaths.root);
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                tooltip: 'Reader Mode',
                onPressed: () => Navigator.pushNamed(
                  context,
                  RoutePaths.viewer,
                  arguments: e.id,
                ),
              ),
              IconButton(
                icon: Icon(
                  e.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: e.favorite
                      ? const Color(0xFFE2A62D)
                      : scheme.onSurfaceVariant,
                ),
                tooltip: e.favorite ? 'Remove favorite' : 'Favorite',
                onPressed: () {
                  Vault.I.toggleFavorite(e.id);
                  LvSnackbar.show(
                    context,
                    e.favorite
                        ? 'Removed from favorites'
                        : 'Added to favorites',
                    icon: e.favorite
                        ? Icons.star_border_rounded
                        : Icons.star_rounded,
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (a) => _onMenuAction(a, e),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'viewer',
                    child: Text('Reader Mode (Clean View)'),
                  ),
                  if (e.url.isNotEmpty)
                    const PopupMenuItem(
                      value: 'open_url',
                      child: Text('Open in app / browser'),
                    ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename source…'),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Text('Move to collection…'),
                  ),
                  const PopupMenuItem(value: 'tag', child: Text('Tags…')),
                  if (e.url.isNotEmpty)
                    const PopupMenuItem(value: 'copy', child: Text('Copy URL')),
                  if (e.localFile != null)
                    const PopupMenuItem(
                      value: 'open_file',
                      child: Text('Open local file'),
                    ),
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                  if (e.url.isNotEmpty)
                    const PopupMenuItem(
                      value: 'retry',
                      child: Text('Retry metadata'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  if (e.localFile != null) {
                    _openLocalFile(context, e);
                  } else if (e.url.isNotEmpty) {
                    _launchUrl(context, e);
                  } else {
                    Navigator.pushNamed(context, '/viewer', arguments: e.id);
                  }
                },
                child: Text(e.localFile != null ? 'Open File' : 'Open'),
              ),
            ),
          ),
          body: ListView(
            // The extra bottom space lets the final fields scroll fully above
            // the persistent Open button on short devices.
            padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 120),
            children: [
              // Hero
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LvThumb(item: e, size: 84, radius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.fetching)
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(height: 18, width: 220),
                              SizedBox(height: 8),
                              SkeletonBox(height: 13, width: 130),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.sync_rounded, size: 13),
                                  SizedBox(width: 6),
                                  Text(
                                    'Fetching metadata…',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  e.title,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Rename source',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () => promptRenameResource(context, e),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (e.source.isNotEmpty) e.source,
                              e.kind.label,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.l),

              // Status
              Text('STATUS', style: _sectionLabel(scheme)),
              const SizedBox(height: 10),
              _StatusSelector(
                status: e.status,
                onChanged: (newStatus) {
                  Vault.I.setStatus(e.id, newStatus);
                  if (newStatus == ResourceStatus.completed) {
                    LvSnackbar.show(context, 'Marked as completed');
                  }
                },
              ),
              const SizedBox(height: Insets.l),

              // Collection
              Text('COLLECTION', style: _sectionLabel(scheme)),
              const SizedBox(height: 10),
              _collectionRow(context, e, scheme),
              const SizedBox(height: Insets.l),

              // Tags
              Text('TAGS', style: _sectionLabel(scheme)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...e.tags.map(
                    (t) => InputChip(
                      label: Text(t),
                      onDeleted: () => Vault.I.removeTag(e.id, t),
                    ),
                  ),
                  ActionChip(
                    avatar: Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: scheme.primary,
                    ),
                    label: const Text('Add Tag'),
                    onPressed: () => showTagsSheet(context, e),
                  ),
                ],
              ),
              const SizedBox(height: Insets.l),

              // Resource note — kept separate from the URL/resource title.
              Text('NOTES', style: _sectionLabel(scheme)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(Insets.m),
                decoration: NotedBox.card(
                  color: isDark ? scheme.surfaceContainerLow : Colors.white,
                  radius: 16,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _noteController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Note Content',
                        hintText: 'Add a note or description…',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (content) => Vault.I.saveNote(e.id, content),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.s),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Saved automatically',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: Insets.l),

              // Attached File
              if (e.localFile != null) ...[
                Text('ATTACHED FILE', style: _sectionLabel(scheme)),
                const SizedBox(height: 10),
                _fileCard(context, e, e.localFile!, scheme),
                const SizedBox(height: Insets.l),
              ],

              // Actions
              _actionRow(
                context,
                Icons.edit_outlined,
                'Rename Source',
                () => promptRenameResource(context, e),
              ),
              _actionRow(
                context,
                Icons.content_copy_rounded,
                'Copy URL',
                e.url.isEmpty ? null : () => _copyUrl(e),
              ),
              if (e.note.trim().isNotEmpty)
                _actionRow(
                  context,
                  Icons.copy_all_outlined,
                  'Copy Note',
                  () => _copyNote(e),
                ),
              if (e.localFile != null)
                _actionRow(
                  context,
                  Icons.file_open_outlined,
                  'Open Local File',
                  () => _openLocalFile(context, e),
                ),
              _actionRow(context, Icons.ios_share_rounded, 'Share', () {
                LvSnackbar.show(
                  context,
                  'Share sheet (demo)',
                  icon: Icons.ios_share_rounded,
                );
              }),
              if (e.url.isNotEmpty)
                _actionRow(context, Icons.sync_rounded, 'Retry metadata', () {
                  Vault.I.retryMetadata(e);
                  LvSnackbar.show(
                    context,
                    'Refreshing details…',
                    icon: Icons.sync_rounded,
                  );
                }),
              _actionRow(
                context,
                Icons.delete_outline_rounded,
                'Delete',
                () => confirmDelete(
                  context,
                  e,
                  onDeleted: () {
                    if (mounted) Navigator.pop(context);
                  },
                ),
                foreground: scheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                'Saved ${e.addedAt.toLocal().toString().split(' ').first}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _sectionLabel(ColorScheme scheme) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: scheme.onSurface,
  );

  Widget _fileCard(
    BuildContext context,
    ResourceItem e,
    FileItem file,
    ColorScheme scheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ext = file.fileExtension.isNotEmpty
        ? file.fileExtension.toUpperCase()
        : 'FILE';
    return Container(
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: 16,
        shadow: true,
        shadowOffset: const Offset(2, 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _openLocalFile(context, e),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF352C16) : NotedColors.yellow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFFFFC107) : NotedColors.border,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.description_outlined,
              color: isDark ? Colors.white : NotedColors.ink,
              size: 22,
            ),
          ),
          title: Text(
            file.fileName,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$ext · ${file.humanSize}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? scheme.onSurfaceVariant : NotedColors.inkMuted,
            ),
          ),
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _openLocalFile(context, e),
            child: const Text(
              'Open',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collectionRow(
    BuildContext context,
    ResourceItem e,
    ColorScheme scheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = e.collectionId == null
        ? null
        : Vault.I.collections.where((c) => c.id == e.collectionId).firstOrNull;
    return Container(
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => showMoveSheet(context, e),
          leading: c != null
              ? Text(c.emoji, style: const TextStyle(fontSize: 22))
              : Icon(
                  Icons.folder_open_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
          title: Text(
            c?.name ?? 'Inbox (no collection)',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _actionRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color? foreground,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: NotedBox.card(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        radius: 14,
        shadow: true,
        shadowOffset: const Offset(2, 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          enabled: onTap != null,
          leading: Icon(icon, color: foreground ?? scheme.onSurface, size: 21),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: foreground ?? scheme.onSurface,
            ),
          ),
          dense: true,
        ),
      ),
    );
  }

  void _copyUrl(ResourceItem e) {
    Clipboard.setData(ClipboardData(text: e.url));
    LvSnackbar.show(
      context,
      'URL copied to clipboard',
      icon: Icons.content_copy_rounded,
    );
  }

  void _onMenuAction(String action, ResourceItem e) {
    switch (action) {
      case 'viewer':
        Navigator.pushNamed(context, RoutePaths.viewer, arguments: e.id);
      case 'open_url':
        _launchUrl(context, e);
      case 'rename':
        promptRenameResource(context, e);
      case 'move':
        showMoveSheet(context, e);
      case 'tag':
        showTagsSheet(context, e);
      case 'copy':
        if (e.url.isNotEmpty) _copyUrl(e);
      case 'open_file':
        _openLocalFile(context, e);
      case 'share':
        LvSnackbar.show(
          context,
          'Share sheet (demo)',
          icon: Icons.ios_share_rounded,
        );
      case 'retry':
        Vault.I.retryMetadata(e);
        LvSnackbar.show(
          context,
          'Refreshing details…',
          icon: Icons.sync_rounded,
        );
      case 'delete':
        confirmDelete(
          context,
          e,
          onDeleted: () {
            if (mounted) Navigator.pop(context);
          },
        );
    }
  }
}

class _StatusSelector extends StatefulWidget {
  const _StatusSelector({
    required this.status,
    required this.onChanged,
  });

  final ResourceStatus status;
  final ValueChanged<ResourceStatus> onChanged;

  @override
  State<_StatusSelector> createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<_StatusSelector> {
  late ResourceStatus _current;

  @override
  void initState() {
    super.initState();
    _current = widget.status;
  }

  @override
  void didUpdateWidget(covariant _StatusSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _current = widget.status;
    }
  }

  Alignment _alignmentFor(ResourceStatus s) {
    switch (s) {
      case ResourceStatus.unread:
        return const Alignment(-1.0, 0.0);
      case ResourceStatus.inProgress:
        return const Alignment(0.0, 0.0);
      case ResourceStatus.completed:
        return const Alignment(1.0, 0.0);
    }
  }

  void _select(ResourceStatus next) {
    if (_current == next) return;
    setState(() => _current = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const options = [
      (ResourceStatus.unread, 'Unread'),
      (ResourceStatus.inProgress, 'Progress'),
      (ResourceStatus.completed, 'Done'),
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : const Color(0xFFF0EBDC),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(
          color: isDark ? scheme.outlineVariant : NotedColors.border,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Gliding active pill indicator
          AnimatedAlign(
            alignment: _alignmentFor(_current),
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF352C16) : NotedColors.yellow,
                  borderRadius: BorderRadius.circular(Radii.control - 4),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFFC107)
                        : NotedColors.border,
                    width: 1.8,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: NotedColors.shadow,
                            offset: Offset(1.5, 2),
                            blurRadius: 0,
                          ),
                        ],
                ),
              ),
            ),
          ),
          // Interactive text tabs
          Row(
            children: options.map((opt) {
              final isSelected = opt.$1 == _current;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(opt.$1),
                  child: Container(
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected
                            ? (isDark ? Colors.white : NotedColors.ink)
                            : (isDark
                                ? scheme.onSurfaceVariant
                                : NotedColors.inkMuted),
                      ),
                      child: Text(opt.$2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
