import 'dart:math';

import 'package:flutter/material.dart';

/// Vertical bar chart — activity over time.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 140});

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final maxV = values.fold(1, max);
          final h = values[i] / maxV;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      values[i] == 0 ? '' : '${values[i]}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: max(4.0, (height - 46) * h),
                    decoration: BoxDecoration(
                      color: values[i] == 0
                          ? scheme.surfaceContainerHighest
                          : scheme.primary.withValues(alpha: 0.35 + 0.65 * h),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Grouped 2-series bars — Saved vs Completed.
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.saved,
    required this.completed,
    required this.labels,
    this.height = 140,
  });

  final List<int> saved;
  final List<int> completed;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = [...saved, ...completed, 1].fold(1, max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(saved[i] / maxV, scheme.primary, height - 46),
                          const SizedBox(width: 2),
                          _bar(completed[i] / maxV, scheme.tertiary, height - 46),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(scheme.primary, 'Saved'),
            const SizedBox(width: 16),
            _legend(scheme.tertiary, 'Completed'),
          ],
        ),
      ],
    );
  }

  Widget _bar(double v, Color color, double maxHeight) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: 5.5,
      height: max(4.0, maxHeight * v),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, color: c)),
      ],
    );
  }
}

/// Donut chart — share by source.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 132});

  final Map<String, int> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      Color(0xFFE2A62D),
      Color(0xFF9C6ADE),
      scheme.outline,
    ];
    final entries = slices.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (a, b) => a + b.value);

    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              entries: entries,
              palette: palette,
              track: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.take(6).toList().asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      total == 0 ? '0' : '${(entry.value / total * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.entries, required this.palette, required this.track});

  final List<MapEntry<String, int>> entries;
  final List<Color> palette;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold(0, (a, b) => a + b.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.16;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius - stroke / 2, trackPaint);

    if (total == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    double start = -pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * 2 * pi;
      paint.color = palette[i % palette.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        max(sweep - 0.04, 0.01),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.track != track;
}
