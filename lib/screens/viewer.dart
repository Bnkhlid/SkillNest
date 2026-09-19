import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../app_theme.dart';
import '../core/utils/external_launcher.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _scroll = ScrollController();
  double _readProgress = 0;
  bool _downloading = false;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Vault.I.registerOpen(widget.itemId);
    });
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      setState(
        () => _readProgress = max <= 0
            ? 0
            : (_scroll.offset / max).clamp(0.0, 1.0),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

  Future<void> _openSystemViewer(String localPath) async {
    final exists = await File(localPath).exists();
    if (!exists) {
      if (mounted) {
        LvSnackbar.show(
          context,
          'Local file not found on disk',
          icon: Icons.warning_amber_rounded,
        );
      }
      return;
    }
    try {
      final res = await OpenFilex.open(localPath);
      if (res.type != ResultType.done && mounted) {
        LvSnackbar.show(
          context,
          'Could not open file: ${res.message}',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        LvSnackbar.show(
          context,
          'Failed to launch file viewer',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _copyNote(ResourceItem item) async {
    final content = item.note.trim();
    if (content.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      LvSnackbar.show(context, 'Note copied', icon: Icons.content_copy_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          backgroundColor: NotedColors.canvasLight,
          appBar: AppBar(
            backgroundColor: NotedColors.canvasLight,
            leading: const BackButton(),
            actions: [
              if (e.url.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.open_in_browser_rounded),
                  tooltip: 'Open in app / browser',
                  onPressed: () => _launchUrl(context, e),
                ),
              if (e.note.trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.content_copy_rounded),
                  tooltip: 'Copy note',
                  onPressed: () => _copyNote(e),
                ),
              IconButton(
                icon: Icon(
                  e.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                ),
                color: e.favorite
                    ? const Color(0xFFE2A62D)
                    : scheme.onSurfaceVariant,
                tooltip: 'Favorite',
                onPressed: () => Vault.I.toggleFavorite(e.id),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Share',
                onPressed: () => LvSnackbar.show(
                  context,
                  'Share sheet (demo)',
                  icon: Icons.ios_share_rounded,
                ),
              ),
              _downloadBtn(context, e),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (a) {
                  if (a == 'move') showMoveSheet(context, e);
                  if (a == 'tag') showTagsSheet(context, e);
                  if (a == 'delete') {
                    confirmDelete(
                      context,
                      e,
                      onDeleted: () {
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'move',
                    child: Text('Move to collection…'),
                  ),
                  PopupMenuItem(value: 'tag', child: Text('Tags…')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: _readProgress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 16),
              child: e.status == ResourceStatus.completed
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Completed — nice work',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Vault.I.setStatus(
                            e.id,
                            ResourceStatus.inProgress,
                          ),
                          child: const Text('Reopen'),
                        ),
                      ],
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () {
                        Vault.I.setStatus(e.id, ResourceStatus.completed);
                        LvSnackbar.show(context, 'Marked as completed');
                      },
                      child: const Text('Mark as Completed'),
                    ),
            ),
          ),
          body: Vault.I.offlineDemo && !_downloaded
              ? _offlineError(scheme)
              : e.localFile != null
              ? _localFileViewer(e, e.localFile!, scheme)
              : SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Insets.l,
                    Insets.l,
                    Insets.l,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(status: e.status),
                      const SizedBox(height: 12),
                      Text(
                        e.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.25,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 20),
                      if (e.url.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: NotedBox.card(
                            color: Colors.white,
                            radius: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    color: NotedColors.ink,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: NotedColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NotedColors.yellow,
                                  foregroundColor: NotedColors.ink,
                                  side: const BorderSide(
                                    color: NotedColors.border,
                                    width: 2,
                                  ),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                icon: const Icon(
                                  Icons.open_in_browser_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Open in App / Browser',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                onPressed: () => _launchUrl(context, e),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (e.url.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: NotedBox.card(
                            color: Colors.white,
                            radius: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.note.isNotEmpty ? e.note : e.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.65,
                                  color: NotedColors.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (e.note.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _copyNote(e),
                                  icon: const Icon(
                                    Icons.content_copy_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Copy Note'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (e.note.isNotEmpty) ...[
                        const Text(
                          'NOTES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: NotedColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: NotedBox.card(
                            color: Colors.white,
                            radius: 14,
                          ),
                          child: Text(
                            e.note,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: NotedColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _localFileViewer(ResourceItem e, FileItem file, ColorScheme scheme) {
    final isImage = [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'gif',
      'bmp',
    ].contains(file.fileExtension);
    final ext = file.fileExtension.toUpperCase();

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Insets.l, Insets.l, Insets.l, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(status: e.status),
          const SizedBox(height: 12),
          Text(
            e.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.25,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Local file · $ext · ${file.humanSize}',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(file.localPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _missingFileBox(file),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: NotedBox.card(
                color: Colors.white,
                radius: 18,
                shadow: true,
                shadowOffset: const Offset(2, 2.5),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NotedColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NotedColors.border, width: 2),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: NotedColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    file.fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: NotedColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stored locally · $ext · ${file.humanSize}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NotedColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open with System App'),
                    onPressed: () => _openSystemViewer(file.localPath),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _missingFileBox(FileItem file) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NotedBox.card(color: const Color(0xFFFFECEB), radius: 16),
      child: Column(
        children: [
          const Icon(
            Icons.broken_image_rounded,
            size: 40,
            color: NotedColors.pink,
          ),
          const SizedBox(height: 8),
          const Text(
            'Image not found on disk',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: NotedColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            file.fileName,
            style: const TextStyle(fontSize: 12, color: NotedColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _downloadBtn(BuildContext context, ResourceItem e) {
    if (_downloaded) {
      return IconButton(
        icon: const Icon(Icons.download_done_rounded),
        color: Theme.of(context).colorScheme.primary,
        tooltip: 'Available offline',
        onPressed: null,
      );
    }
    return IconButton(
      icon: _downloading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      tooltip: 'Download',
      onPressed: _downloading
          ? null
          : () async {
              setState(() => _downloading = true);
              await Future.delayed(const Duration(milliseconds: 1500));
              if (!mounted) return;
              setState(() {
                _downloading = false;
                _downloaded = true;
              });
              LvSnackbar.show(
                this.context,
                'Available offline',
                icon: Icons.download_done_rounded,
              );
            },
    );
  }

  Widget _offlineError(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Radii.sheet),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Can\u2019t load while offline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download resources ahead of time to read them without a connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => LvSnackbar.show(
                context,
                'Will retry when back online',
                icon: Icons.sync_rounded,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
