import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../core/utils/url_normalizer.dart';
import '../models.dart';
import '../vault.dart';
import '../widgets/components.dart';

enum AddSource { link, note, file, share }

class AddArgs {
  const AddArgs({this.presetCollectionId, this.initialUrl, this.source});

  final String? presetCollectionId;
  final String? initialUrl;
  final AddSource? source;
}

class AddResourceScreen extends StatefulWidget {
  const AddResourceScreen({super.key, this.args});

  final AddArgs? args;

  @override
  State<AddResourceScreen> createState() => _AddResourceScreenState();
}

enum _SourceTab { link, paste, file, share }

class _AddResourceScreenState extends State<AddResourceScreen> {
  _SourceTab _tab = _SourceTab.link;
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteTitleController = TextEditingController();
  final _textController = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _pickedFileSize;
  String? _collectionId;
  final Set<String> _tags = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _collectionId = widget.args?.presetCollectionId;
    _tab = switch (widget.args?.source) {
      AddSource.note => _SourceTab.paste,
      AddSource.file => _SourceTab.file,
      AddSource.share => _SourceTab.share,
      _ => _SourceTab.link,
    };
    if (widget.args?.initialUrl != null &&
        widget.args!.initialUrl!.isNotEmpty) {
      _urlController.text = widget.args!.initialUrl!;
      _tab = _SourceTab.link;
    }
  }

  @override
  void didUpdateWidget(covariant AddResourceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.args?.initialUrl != null &&
        widget.args!.initialUrl!.isNotEmpty &&
        widget.args!.initialUrl != oldWidget.args?.initialUrl) {
      _urlController.text = widget.args!.initialUrl!;
      _tab = _SourceTab.link;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _noteTitleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  bool get _canSave {
    switch (_tab) {
      case _SourceTab.link:
        return Uri.tryParse(_urlController.text.trim())?.hasAbsolutePath ??
            false;
      case _SourceTab.paste:
        return _textController.text.trim().length > 2;
      case _SourceTab.file:
        return _pickedFilePath != null && _pickedFileName != null;
      case _SourceTab.share:
        return Uri.tryParse(_urlController.text.trim())?.hasAbsolutePath ??
            false;
    }
  }

  ResourceKind _detectFileKind(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) return ResourceKind.pdf;
    if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi')) {
      return ResourceKind.video;
    }
    if (ext.endsWith('.epub') ||
        ext.endsWith('.doc') ||
        ext.endsWith('.docx') ||
        ext.endsWith('.txt') ||
        ext.endsWith('.md')) {
      return ResourceKind.article;
    }
    return ResourceKind.pdf;
  }

  String _sourceForUrl(String url) {
    final domain = UrlNormalizer.extractDomain(url);
    const names = {
      'facebook.com': 'Facebook',
      'instagram.com': 'Instagram',
      'tiktok.com': 'TikTok',
      'youtube.com': 'YouTube',
      'youtu.be': 'YouTube',
      'linkedin.com': 'LinkedIn',
      'x.com': 'X',
      'twitter.com': 'X',
    };
    return names[domain] ?? domain;
  }

  Future<void> _save() async {
    if (_saving) return; // Prevent double-tap submissions
    setState(() => _saving = true);

    try {
      final vault = Vault.I;
      final url = _tab == _SourceTab.paste || _tab == _SourceTab.file
          ? ''
          : _urlController.text.trim();
      final kind = switch (_tab) {
        _SourceTab.link => ResourceKind.page,
        _SourceTab.paste => ResourceKind.note,
        _SourceTab.file => _detectFileKind(_pickedFileName ?? ''),
        _SourceTab.share => ResourceKind.page,
      };
      final customTitle = _titleController.text.trim();
      final title = switch (_tab) {
        _SourceTab.link => customTitle.isNotEmpty ? customTitle : url,
        _SourceTab.paste =>
          _noteTitleController.text.trim().isEmpty
              ? 'Untitled Note'
              : _noteTitleController.text.trim(),
        _SourceTab.file =>
          customTitle.isNotEmpty ? customTitle : (_pickedFileName ?? 'File'),
        _SourceTab.share => customTitle.isNotEmpty ? customTitle : url,
      };
      final source = switch (_tab) {
        _SourceTab.paste => '',
        _SourceTab.file => 'local file',
        _SourceTab.link => _sourceForUrl(url),
        _SourceTab.share => _sourceForUrl(url),
      };

      // Duplicate check (URL-based)
      if (url.isNotEmpty) {
        final existing = vault.findByUrl(url);
        if (existing != null && mounted) {
          setState(() => _saving = false);
          final choice = await _duplicateDialog(existing);
          if (choice != 'anyway') return;
          if (!mounted) return;
          setState(() => _saving = true);
        }
      }

      final noteText = _tab == _SourceTab.paste
          ? _textController.text.trim()
          : null;
      final noteTitle = _tab == _SourceTab.paste
          ? _noteTitleController.text.trim()
          : null;
      final item = await vault.add(
        title: title,
        source: source,
        url: url,
        kind: kind,
        collectionId: _collectionId,
        tags: {..._tags},
        noteTitle: noteTitle,
        notes: noteText,
        fetchMetadata: _tab == _SourceTab.link || _tab == _SourceTab.share,
      );

      if (_tab == _SourceTab.file &&
          _pickedFilePath != null &&
          _pickedFileName != null) {
        await vault.attachFile(item.id, _pickedFilePath!, _pickedFileName!);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final rootNav = Navigator.of(context, rootNavigator: true);
      Navigator.pop(context);
      final scheme = Theme.of(context).colorScheme;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: scheme.inversePrimary,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Saved to Inbox')),
              _snackAction(
                'Open Inbox',
                scheme,
                () => rootNav.pushNamed('/inbox'),
              ),
              const SizedBox(width: 12),
              _snackAction('Undo', scheme, () => Vault.I.delete(item.id)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        LvSnackbar.show(
          context,
          'Failed to save resource: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _snackAction(String label, ColorScheme scheme, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        onTap();
      },
      child: Text(
        label,
        style: TextStyle(
          color: scheme.inversePrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Future<String?> _duplicateDialog(ResourceItem existing) async {
    final scheme = Theme.of(context).colorScheme;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.content_copy_rounded,
          color: scheme.tertiary,
          size: 26,
        ),
        title: const Text(
          'Already in your library',
          textAlign: TextAlign.center,
        ),
        content: Text(
          '\u201C${existing.title}\u201D is saved${existing.collectionId != null ? ' in ${Vault.I.collections.where((c) => c.id == existing.collectionId).first.name}' : ''}. Keep both copies?',
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, 'existing'),
              child: const Text('Open Existing'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, 'anyway'),
              child: const Text('Save Anyway'),
            ),
          ),
        ],
      ),
    );
    if (choice == 'existing' && mounted) {
      Navigator.pop(context); // close Add screen
      Navigator.pushNamed(context, '/details', arguments: existing.id);
    }
    return choice;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vault = Vault.I;

    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      appBar: AppBar(
        backgroundColor: NotedColors.canvasLight,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: NotedColors.ink),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Resource',
          style: TextStyle(color: NotedColors.ink, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: _saveBar(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: vault,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(Insets.l, 8, Insets.l, 24),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 390;
                  return SegmentedButton<_SourceTab>(
                    segments: [
                      ButtonSegment(
                        value: _SourceTab.link,
                        icon: const Icon(Icons.link_rounded, size: 17),
                        label: compact ? null : const Text('URL'),
                      ),
                      ButtonSegment(
                        value: _SourceTab.paste,
                        icon: const Icon(Icons.content_paste_rounded, size: 17),
                        label: compact ? null : const Text('Paste'),
                      ),
                      ButtonSegment(
                        value: _SourceTab.file,
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: compact ? null : const Text('File'),
                      ),
                      ButtonSegment(
                        value: _SourceTab.share,
                        icon: const Icon(Icons.ios_share_rounded, size: 17),
                        label: compact ? null : const Text('Share'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                    showSelectedIcon: false,
                  );
                },
              ),
              const SizedBox(height: Insets.m),
              if (_tab != _SourceTab.paste) ...[
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: _tab == _SourceTab.file
                        ? 'Defaults to the file name'
                        : 'e.g. Flutter Riverpod guide',
                  ),
                ),
                const SizedBox(height: Insets.m),
              ],
              _sourceInput(scheme),
              const SizedBox(height: Insets.l),
              _collectionPicker(vault, scheme),
              const SizedBox(height: Insets.l),
              _tagPicker(scheme),
              const SizedBox(height: Insets.l),
              if (vault.offlineDemo) const OfflineBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceInput(ColorScheme scheme) {
    switch (_tab) {
      case _SourceTab.link:
      case _SourceTab.share:
        final isShare = _tab == _SourceTab.share;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isShare) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: use system Share → SkillNest to send links here from any app.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.m),
            ],
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'https://example.com/article',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      _urlController.text = data.text!.trim();
                      setState(() {});
                    } else {
                      if (mounted) {
                        LvSnackbar.show(
                          context,
                          'Clipboard is empty',
                          icon: Icons.info_outline_rounded,
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        );
      case _SourceTab.paste:
        return Column(
          children: [
            TextField(
              controller: _noteTitleController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Note Title (optional)',
                hintText: 'e.g. Ideas for the project',
              ),
            ),
            const SizedBox(height: Insets.m),
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Note Content',
                hintText: 'Paste text or write a quick note…',
                alignLabelWithHint: true,
              ),
            ),
          ],
        );
      case _SourceTab.file:
        final sizeText = _pickedFileSize != null
            ? FileItem(
                id: '',
                resourceId: '',
                localPath: '',
                fileName: _pickedFileName ?? '',
                fileSize: _pickedFileSize!,
              ).humanSize
            : null;
        return Column(
          children: [
            Container(
              decoration: NotedBox.card(color: Colors.white, radius: 18),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickFile,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.upload_file_rounded,
                          size: 38,
                          color: NotedColors.ink,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _pickedFileName ?? 'Choose a file',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: NotedColors.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sizeText != null
                              ? 'Selected · $sizeText'
                              : 'PDF, document, image or generic file',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: NotedColors.inkMuted,
                          ),
                        ),
                        if (_pickedFileName != null)
                          TextButton(
                            onPressed: _pickFile,
                            child: const Text('Change file'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final f = files.first;
        int? size;
        if (f.path != null) {
          try {
            size = await File(f.path!).length();
          } catch (_) {}
        }
        setState(() {
          _pickedFilePath = f.path;
          _pickedFileName = f.name;
          _pickedFileSize = size;
        });
      }
    } catch (e) {
      if (mounted) {
        LvSnackbar.show(
          context,
          'Could not open file picker',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Widget _collectionPicker(Vault vault, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Collection', style: _labelStyle(scheme)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Inbox only'),
              selected: _collectionId == null,
              onSelected: (_) => setState(() => _collectionId = null),
            ),
            ...vault.collections.map(
              (c) => ChoiceChip(
                label: Text('${c.emoji} ${c.name}'),
                selected: _collectionId == c.id,
                onSelected: (_) => setState(() => _collectionId = c.id),
              ),
            ),
            ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 17,
                color: NotedColors.ink,
              ),
              label: const Text('Add Collection'),
              onPressed: () async {
                final name = await LvDialog.prompt(
                  context,
                  title: 'New collection',
                  hint: 'e.g. Writing',
                );
                if (name != null && name.isNotEmpty && mounted) {
                  final c = await Vault.I.addCollection(name);
                  setState(() => _collectionId = c.id);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _tagPicker(ColorScheme scheme) {
    final suggestions = (Vault.I.allTags.toList()..sort())
        .where((t) => !_tags.contains(t))
        .take(6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: _labelStyle(scheme)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map(
              (t) => InputChip(
                label: Text(t),
                onDeleted: () => setState(() => _tags.remove(t)),
              ),
            ),
            ...suggestions.map(
              (t) => ActionChip(
                label: Text('+ $t'),
                onPressed: () => setState(() => _tags.add(t)),
              ),
            ),
            ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 17,
                color: NotedColors.ink,
              ),
              label: const Text('Add Tag'),
              onPressed: () async {
                final tag = await LvDialog.prompt(
                  context,
                  title: 'Add tag',
                  hint: 'e.g. design',
                );
                if (tag != null && tag.isNotEmpty && mounted) {
                  setState(() => _tags.add(tag.trim().toLowerCase()));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _labelStyle(ColorScheme scheme) => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: NotedColors.ink,
  );

  /// Save bar — floats above the keyboard when a field is focused.
  Widget _saveBar(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: NotedColors.border, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.l, 12, Insets.l, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: NotedColors.ink,
                      side: const BorderSide(
                        color: NotedColors.border,
                        width: 2,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSave
                          ? NotedColors.yellow
                          : const Color(0xFFE5DFD1),
                      foregroundColor: NotedColors.ink,
                      side: const BorderSide(
                        color: NotedColors.border,
                        width: 2,
                      ),
                    ),
                    onPressed: _canSave && !_saving ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NotedColors.ink,
                            ),
                          )
                        : Text(
                            _tab == _SourceTab.paste
                                ? 'Save Note'
                                : 'Save Resource',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: NotedColors.ink,
                            ),
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
}
