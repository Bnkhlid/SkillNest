import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../vault.dart';

/// ─── noted Brand & Accents ──────────────────────────────────────────────────
List<Color> accentContainerOf(ColorScheme scheme) => [
  NotedColors.yellow,
  NotedColors.mint,
  NotedColors.pink,
  NotedColors.yellowLight,
  NotedColors.mintLight,
  NotedColors.pinkLight,
];

/// ─── noted Logo Widget (3 Tilted Stacked Pastel Notes with Checkmark) ────────

class NotedLogo extends StatelessWidget {
  const NotedLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Bottom Pink Note
          Transform.translate(
            offset: Offset(-size * 0.16, size * 0.14),
            child: Transform.rotate(
              angle: -0.34,
              child: _NoteSquare(
                color: NotedColors.pink,
                size: size * 0.62,
                radius: size * 0.14,
              ),
            ),
          ),
          // 2. Middle Mint Note
          Transform.translate(
            offset: Offset(-size * 0.08, -size * 0.02),
            child: Transform.rotate(
              angle: -0.14,
              child: _NoteSquare(
                color: NotedColors.mint,
                size: size * 0.64,
                radius: size * 0.14,
              ),
            ),
          ),
          // 3. Top Yellow Note with Checkmark
          Transform.translate(
            offset: Offset(size * 0.12, -size * 0.08),
            child: Transform.rotate(
              angle: 0.12,
              child: _NoteSquare(
                color: NotedColors.yellow,
                size: size * 0.66,
                radius: size * 0.14,
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.40,
                  color: NotedColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSquare extends StatelessWidget {
  const _NoteSquare({
    required this.color,
    required this.size,
    required this.radius,
    this.child,
  });

  final Color color;
  final double size;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: NotedColors.border, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: NotedColors.shadow,
            offset: Offset(2.5, 3),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// ─── noted Checkbox Component (3 States: Unchecked, Completed, Discarded) ───

enum NotedCheckState { unchecked, completed, discarded }

class NotedCheckbox extends StatelessWidget {
  const NotedCheckbox({
    super.key,
    required this.state,
    required this.onChanged,
    this.size = 26,
  });

  final NotedCheckState state;
  final ValueChanged<NotedCheckState> onChanged;
  final double size;

  void _cycle() {
    switch (state) {
      case NotedCheckState.unchecked:
        onChanged(NotedCheckState.completed);
      case NotedCheckState.completed:
        onChanged(NotedCheckState.discarded);
      case NotedCheckState.discarded:
        onChanged(NotedCheckState.unchecked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, icon, iconColor) = switch (state) {
      NotedCheckState.unchecked => (Colors.white, null, null),
      NotedCheckState.completed => (
        NotedColors.mint,
        Icons.check_rounded,
        NotedColors.ink,
      ),
      NotedCheckState.discarded => (
        NotedColors.pink,
        Icons.close_rounded,
        Colors.white,
      ),
    };

    return GestureDetector(
      onTap: _cycle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.checkbox),
          border: Border.all(color: NotedColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: size * 0.72, color: iconColor)
            : null,
      ),
    );
  }
}

/// ─── noted Bullet Component (Circle bullet with border & check) ───────────────

class NotedBullet extends StatelessWidget {
  const NotedBullet({
    super.key,
    this.checked = false,
    this.onTap,
    this.size = 22,
    this.color = NotedColors.mintLight,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? NotedColors.mint : color,
          shape: BoxShape.circle,
          border: Border.all(color: NotedColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: checked
            ? Icon(
                Icons.check_rounded,
                size: size * 0.7,
                color: NotedColors.ink,
              )
            : null,
      ),
    );
  }
}

/// ─── noted Sticky Note Card (Header bar + Divider + Todo List) ──────────────

class NotedCardItem {
  final String text;
  final NotedCheckState state;
  final bool isBullet;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const NotedCardItem({
    required this.text,
    this.state = NotedCheckState.unchecked,
    this.isBullet = false,
    this.onToggle,
    this.onDelete,
  });
}

class NotedStickyCard extends StatelessWidget {
  const NotedStickyCard({
    super.key,
    required this.title,
    required this.items,
    this.color = NotedColors.yellow,
    this.onTap,
    this.onDelete,
    this.width = 240,
  });

  final String title;
  final List<NotedCardItem> items;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: NotedBox.card(color: color, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: NotedColors.border, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: NotedColors.ink,
                      ),
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: NotedColors.ink,
                    tooltip: 'Delete Note',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                children: items.map((it) => _NotedItemRow(item: it)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotedItemRow extends StatelessWidget {
  const _NotedItemRow({required this.item});

  final NotedCardItem item;

  @override
  Widget build(BuildContext context) {
    final isDone = item.state == NotedCheckState.completed;
    final isDiscarded = item.state == NotedCheckState.discarded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item.isBullet)
            NotedBullet(checked: isDone, onTap: item.onToggle, size: 20)
          else ...[
            Expanded(
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDiscarded
                      ? NotedColors.inkMuted
                      : (isDone
                            ? NotedColors.ink.withValues(alpha: 0.6)
                            : NotedColors.ink),
                  decoration: isDone
                      ? TextDecoration.lineThrough
                      : (isDiscarded ? TextDecoration.lineThrough : null),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (isDone && item.onDelete != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: NotedColors.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: NotedColors.ink,
                  ),
                ),
              ),
            NotedCheckbox(
              state: item.state,
              onChanged: (_) => item.onToggle?.call(),
              size: 24,
            ),
          ],
          if (item.isBullet) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? NotedColors.ink.withValues(alpha: 0.6)
                      : NotedColors.ink,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isDone && item.onDelete != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: NotedColors.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: NotedColors.ink,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// ─── Small building blocks ────────────────────────────────────────────────

class LvIconBtn extends StatelessWidget {
  const LvIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: color ?? NotedColors.ink,
      tooltip: tooltip,
    );
    return btn;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final ResourceStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, icon, fg) = switch (status) {
      ResourceStatus.unread => (
        Colors.white,
        Icons.circle_outlined,
        NotedColors.inkMuted,
      ),
      ResourceStatus.inProgress => (
        NotedColors.yellow,
        Icons.trending_flat_rounded,
        NotedColors.ink,
      ),
      ResourceStatus.completed => (
        NotedColors.mint,
        Icons.check_rounded,
        NotedColors.ink,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NotedColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class LvThumb extends StatelessWidget {
  const LvThumb({super.key, required this.item, this.size = 48, this.radius});

  final ResourceItem item;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final bg = _thumbColor(item.accent);
    final fileIcon = _fileIcon(item.localFile?.fileExtension);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: item.fetching ? const Color(0xFFE5DFD1) : bg,
        borderRadius: BorderRadius.circular(radius ?? Radii.thumb),
        border: Border.all(color: NotedColors.border, width: 1.8),
      ),
      alignment: Alignment.center,
      child: item.fetching
          ? null
          : Icon(
              fileIcon ?? item.kind.icon,
              size: size * 0.46,
              color: NotedColors.ink,
            ),
    );
  }

  IconData? _fileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Icons.image_outlined;
      case 'doc':
      case 'docx':
      case 'rtf':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.play_circle_outline;
      default:
        return extension == null || extension.isEmpty
            ? null
            : Icons.insert_drive_file_outlined;
    }
  }

  Color _thumbColor(int i) {
    final list = [
      NotedColors.yellow,
      NotedColors.mint,
      NotedColors.pink,
      NotedColors.yellowLight,
      NotedColors.mintLight,
      NotedColors.pinkLight,
    ];
    return list[i % list.length];
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: NotedColors.ink,
              ),
            ),
          ),
          if (actionLabel != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NotedColors.border, width: 1.6),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NotedColors.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FilterBadgeIcon extends StatelessWidget {
  const FilterBadgeIcon({
    super.key,
    required this.active,
    required this.onTap,
    this.tooltip = 'Filter',
  });

  final int active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LvIconBtn(icon: Icons.tune_rounded, onTap: onTap, tooltip: tooltip),
        if (active > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: NotedColors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: NotedColors.border, width: 1.5),
              ),
              child: Text(
                '$active',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: NotedColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ─── Resource tile (list card) ────────────────────────────────────────────

class ResourceTile extends StatelessWidget {
  const ResourceTile({
    super.key,
    required this.item,
    required this.onOpen,
    this.trailingFavorite = false,
    this.trailingMore = true,
    this.showStatus = true,
    this.subtitleOverride,
    this.selected,
    this.selectMode = false,
    this.onToggleSelect,
    this.trailingOverride,
    this.dimmed = false,
  });

  final ResourceItem item;
  final VoidCallback onOpen;
  final bool trailingFavorite;
  final bool trailingMore;
  final bool showStatus;
  final String? subtitleOverride;
  final bool? selected;
  final bool selectMode;
  final VoidCallback? onToggleSelect;
  final Widget? trailingOverride;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isFav = item.favorite;

    if (item.fetching) return const SkeletonTile();

    return Container(
      decoration: NotedBox.card(
        color: Colors.white,
        radius: 16,
        shadow: true,
        shadowOffset: const Offset(2.5, 3.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectMode ? onToggleSelect : onOpen,
          onLongPress: onToggleSelect != null && !selectMode
              ? onToggleSelect
              : null,
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (selectMode) ...[
                    NotedCheckbox(
                      state: (selected ?? false)
                          ? NotedCheckState.completed
                          : NotedCheckState.unchecked,
                      onChanged: (_) => onToggleSelect?.call(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  LvThumb(item: item, size: 44, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: NotedColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitleOverride ?? _metaLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: NotedColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (trailingOverride != null)
                    trailingOverride!
                  else if (showStatus)
                    StatusChip(status: item.status, compact: true),
                  if (trailingFavorite) ...[
                    const SizedBox(width: 4),
                    _StarIcon(
                      filled: isFav,
                      onTap: () => Vault.I.toggleFavorite(item.id),
                    ),
                  ],
                  if (trailingMore && !selectMode) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      color: NotedColors.ink,
                      tooltip: 'More',
                      onPressed: () =>
                          showCardMenuSheet(context, item, onOpen: onOpen),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _metaLine() {
    final src = item.source.isEmpty ? '${item.kind.label} note' : item.source;
    return '$src · ${_timeAgo(item.addedAt)}';
  }
}

class _StarIcon extends StatelessWidget {
  const _StarIcon({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded),
      color: filled ? const Color(0xFFE2A62D) : NotedColors.inkMuted,
      iconSize: 22,
      tooltip: filled ? 'Remove favorite' : 'Favorite',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

void showCardMenuSheet(
  BuildContext context,
  ResourceItem item, {
  VoidCallback? onOpen,
}) {
  LvSheet.show(
    context,
    title: item.title,
    subtitle: item.source.isEmpty ? item.kind.label : item.source,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LvSheetAction(
          icon: Icons.open_in_new_rounded,
          label: 'Open',
          onTap: () {
            Navigator.pop(ctx);
            onOpen?.call();
          },
        ),
        LvSheetAction(
          icon: item.favorite ? Icons.star_outline_rounded : Icons.star_rounded,
          label: item.favorite ? 'Remove favorite' : 'Favorite',
          onTap: () {
            Vault.I.toggleFavorite(item.id);
            Navigator.pop(ctx);
          },
        ),
        LvSheetAction(
          icon: Icons.drive_file_move_outline,
          label: 'Move to collection…',
          onTap: () {
            Navigator.pop(ctx);
            showMoveSheet(context, item);
          },
        ),
        LvSheetAction(
          icon: Icons.sell_outlined,
          label: 'Tags…',
          onTap: () {
            Navigator.pop(ctx);
            showTagsSheet(context, item);
          },
        ),
        LvSheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          foreground: const Color(0xFFD94838),
          onTap: () {
            Navigator.pop(ctx);
            confirmDelete(context, item);
          },
        ),
      ],
    ),
  );
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'just now';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

/// ─── Continue Learning card ───────────────────────────────────────────────

class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.item, required this.onOpen});

  final ResourceItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (item.fetching) return const SkeletonContinueCard();
    final cardColor = switch (item.accent % 3) {
      0 => NotedColors.yellowLight,
      1 => NotedColors.mintLight,
      _ => NotedColors.pinkLight,
    };

    return Container(
      width: 270,
      decoration: NotedBox.card(color: cardColor, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    LvThumb(item: item, size: 40, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.25,
                          color: NotedColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _StarIcon(
                      filled: item.favorite,
                      onTap: () => Vault.I.toggleFavorite(item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.source.isEmpty ? item.kind.label : item.source,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: NotedColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: NotedColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _progressOf(item),
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation(
                              NotedColors.mint,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_progressOf(item) * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: NotedColors.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      color: NotedColors.ink,
                      tooltip: 'More',
                      onPressed: () =>
                          showCardMenuSheet(context, item, onOpen: onOpen),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _progressOf(ResourceItem e) {
    switch (e.status) {
      case ResourceStatus.completed:
        return 1;
      case ResourceStatus.inProgress:
        return ((e.openCount + 1) / 5).clamp(0.2, 0.9);
      case ResourceStatus.unread:
        return 0;
    }
  }
}

/// ─── Collection card ──────────────────────────────────────────────────────

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onOpen,
    required this.onMore,
  });

  final CollectionModel collection;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = Vault.I.byCollection(collection.id);
    final done = items
        .where((e) => e.status == ResourceStatus.completed)
        .length;
    final progress = items.isEmpty ? 0.0 : done / items.length;

    final cardColor = switch (collection.accent % 6) {
      0 => NotedColors.yellowLight,
      1 => NotedColors.mintLight,
      2 => NotedColors.pinkLight,
      3 => NotedColors.purpleLight,
      4 => NotedColors.blueLight,
      _ => const Color(0xFFFDEED8),
    };

    return Container(
      decoration: NotedBox.card(color: cardColor, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Radii.thumb),
                        border: Border.all(color: NotedColors.border, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        collection.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      color: NotedColors.ink,
                      tooltip: 'Collection options',
                      onPressed: onMore,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: NotedColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: NotedColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: NotedColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation(
                              NotedColors.mint,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: NotedColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── States: skeleton / empty / offline ───────────────────────────────────

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 48, height: 48, radius: Radii.thumb),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 200),
                SizedBox(height: 8),
                SkeletonBox(height: 11, width: 130),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonContinueCard extends StatelessWidget {
  const SkeletonContinueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 40, height: 40, radius: 10),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 13),
                    SizedBox(height: 6),
                    SkeletonBox(height: 13, width: 140),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          SkeletonBox(height: 10, width: 180),
          SizedBox(height: 10),
          SkeletonBox(height: 5, radius: 3),
        ],
      ),
    );
  }
}

List<Widget> skeletonList(BuildContext context, {int count = 4}) =>
    List.generate(
      count,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SkeletonTile(),
      ),
    );

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Radii.sheet),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\u2019re offline. Saves are queued and will sync when you reconnect.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Bottom sheet + dialog + snackbar helpers ─────────────────────────────

class LvSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    required WidgetBuilder builder,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    );
  }
}

class LvSheetAction extends StatelessWidget {
  const LvSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foreground;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = foreground ?? scheme.onSurface;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
    );
  }
}

class LvDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    Color? iconColor,
    String? confirmLabel,
    VoidCallback? onConfirm,
    String cancelLabel = 'Cancel',
    Color? confirmColor,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon != null
            ? Icon(icon, color: iconColor ?? scheme.primary, size: 26)
            : null,
        title: Text(
          title,
          textAlign: icon != null ? TextAlign.center : TextAlign.start,
        ),
        content: message != null
            ? Text(
                message,
                textAlign: icon != null ? TextAlign.center : TextAlign.start,
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          if (confirmLabel != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: confirmColor ?? scheme.primary,
                foregroundColor: confirmColor != null
                    ? scheme.onError
                    : scheme.onPrimary,
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
                onConfirm?.call();
              },
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
  }

  /// Convenience: dialog with Confirm/Cancel returning a bool.
  static Future<bool> showAsBool(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    Color? iconColor,
    String confirmLabel = 'Confirm',
    Color? confirmColor,
  }) async {
    final result = await show(
      context,
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    );
    return result ?? false;
  }

  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? hint,
    String initial = '',
    String confirmLabel = 'Save',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PromptDialog(
        title: title,
        hint: hint,
        initial: initial,
        confirmLabel: confirmLabel,
      ),
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    this.hint,
    this.initial = '',
    this.confirmLabel = 'Save',
  });

  final String title;
  final String? hint;
  final String initial;
  final String confirmLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: NotedColors.ink,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: NotedColors.inkMuted,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NotedColors.yellow,
            foregroundColor: NotedColors.ink,
          ),
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class LvSnackbar {
  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = Icons.check_circle_rounded,
  }) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, size: 18, color: scheme.inversePrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  onPressed: () => onAction?.call(),
                )
              : null,
        ),
      );
  }
}

/// ─── Shared flows: move / tags / delete ───────────────────────────────────

Future<void> showMoveSheet(
  BuildContext context,
  ResourceItem item, {
  List<String>? ids,
}) async {
  final vault = Vault.I;
  final picked = await LvSheet.show<String>(
    context,
    title: 'Move to collection',
    subtitle: ids == null ? item.title : '${ids.length} items',
    builder: (ctx) => ListenableBuilder(
      listenable: vault,
      builder: (ctx, _) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...vault.collections.map(
              (c) => ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: (ids == null ? item.collectionId : null) == c.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text(
                'No collection',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text(
                'New collection',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final name = await LvDialog.prompt(
                  ctx,
                  title: 'New collection',
                  hint: 'e.g. Frontend',
                );
                if (name != null && name.isNotEmpty) {
                  final c = await vault.addCollection(name);
                  if (ctx.mounted) Navigator.pop(ctx, c.id);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final target = picked.isEmpty ? null : picked;
  if (ids == null) {
    vault.moveTo(item.id, target);
  } else {
    for (final id in ids) {
      vault.moveTo(id, target);
    }
  }
  final name = target == null
      ? 'No collection'
      : vault.collections.where((c) => c.id == target).first.name;
  LvSnackbar.show(
    context,
    ids == null ? 'Moved to $name' : 'Moved ${ids.length} items to $name',
  );
}

Future<void> showTagsSheet(
  BuildContext context,
  ResourceItem item, {
  List<String>? ids,
}) async {
  final vault = Vault.I;
  final targets = ids ?? [item.id];
  await LvSheet.show<void>(
    context,
    title: 'Tags',
    subtitle: ids == null ? item.title : '${ids.length} items',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateSheet) {
        final all = vault.allTags.toList()..sort();
        final current = targets
            .map((id) => vault.find(id))
            .whereType<ResourceItem>()
            .map((e) => e.tags)
            .toList();
        final shared = current.isEmpty
            ? <String>{}
            : current.reduce((a, b) => a.intersection(b));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (all.isEmpty)
                Text(
                  'No tags yet. Add one to group related resources.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: all.map((t) {
                    final on = shared.contains(t);
                    return FilterChip(
                      label: Text(t),
                      selected: on,
                      onSelected: (v) {
                        setStateSheet(() {});
                        for (final id in targets) {
                          v ? vault.addTag(id, t) : vault.removeTag(id, t);
                        }
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final tag = await LvDialog.prompt(
                    ctx,
                    title: 'Add tag',
                    hint: 'e.g. fundamentals',
                  );
                  if (tag != null && tag.isNotEmpty) {
                    for (final id in targets) {
                      vault.addTag(id, tag);
                    }
                    setStateSheet(() {});
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add new tag'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> confirmDelete(
  BuildContext context,
  ResourceItem item, {
  VoidCallback? onDeleted,
}) async {
  final scheme = Theme.of(context).colorScheme;
  await LvDialog.show(
    context,
    icon: Icons.delete_outline_rounded,
    iconColor: scheme.error,
    title: 'Move to Trash?',
    message:
        '\u201C${item.title}\u201D will stay in Trash for 30 days before it\u2019s permanently deleted.',
    confirmLabel: 'Delete',
    confirmColor: scheme.error,
    onConfirm: () {
      Vault.I.delete(item.id);
      onDeleted?.call();
      if (context.mounted) {
        LvSnackbar.show(
          context,
          'Moved to Trash',
          actionLabel: 'Undo',
          onAction: () => Vault.I.restore(item.id),
          icon: Icons.delete_outline_rounded,
        );
      }
    },
  );
}

/// ─── Progress ring (Home) ─────────────────────────────────────────────────

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 6,
  });

  final double value;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(value * 100).round()}',
            style: TextStyle(
              fontSize: size * 0.24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
