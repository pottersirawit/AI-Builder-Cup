import 'dart:math' as math;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../theme.dart';
import '../tokens.dart';
import 'marks.dart';

/// One line on the departure board: when, how, where, and its status.
class BoardRow extends StatelessWidget {
  const BoardRow({
    super.key,
    required this.time,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.status,
    this.timeCaption,
    this.selected = false,
    this.onTap,
  });

  /// Departure time, e.g. "16:45", or a short day label.
  final String time;
  final String? timeCaption;
  final IconData icon;
  final String title;
  final String subtitle;
  final Risk risk;
  final String status;
  final bool selected;
  final VoidCallback? onTap;

  /// Fixed row height for [scaler], so the board can rerank by position.
  static double heightFor(TextScaler scaler) =>
      math.max(76, scaler.scale(20) * 1.4 + scaler.scale(12) * 1.55 + 30);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: onTap != null,
      label: '$time $title $status',
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(time, style: tabular(t.titleLarge!)),
                      ),
                      if (timeCaption != null)
                        Text(timeCaption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tabular(t.bodySmall!).copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                RiskChip(risk: risk, label: status, dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows that slide to their new rank instead of jumping when the order changes.
class DepartureBoard extends StatelessWidget {
  const DepartureBoard({super.key, required this.rows});

  /// Keyed rows in rank order; keys must be stable across reranks.
  final List<BoardRow> rows;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final h = BoardRow.heightFor(MediaQuery.textScalerOf(context));
    final byKey = [...rows]..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return SizedBox(
      height: h * rows.length,
      child: Stack(
        children: [
          for (final r in byKey)
            AnimatedPositioned(
              key: r.key,
              duration: motion.d(Motion.rerank),
              curve: Motion.standard,
              left: 0,
              right: 0,
              top: rows.indexOf(r) * h,
              height: h,
              child: Semantics(sortKey: OrdinalSortKey(rows.indexOf(r).toDouble()), child: r),
            ),
        ],
      ),
    );
  }
}
