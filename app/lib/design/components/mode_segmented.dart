import 'package:flutter/material.dart';

import '../../models.dart';
import '../labels.dart';
import '../theme.dart';
import '../tokens.dart';

/// Per-mode status shown under each segment.
class ModeStatus {
  const ModeStatus({required this.risk, required this.text});
  final Risk risk;
  final String text;
}

/// Car / BTS-MRT / motorbike picker that also shows each mode's verdict.
class ModeSegmented extends StatelessWidget {
  const ModeSegmented({
    super.key,
    required this.selected,
    required this.onChanged,
    this.status = const {},
  });

  final TravelMode selected;
  final ValueChanged<TravelMode> onChanged;
  final Map<TravelMode, ModeStatus> status;

  static const _pad = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final motion = Motion.of(context);
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.md + _pad),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in TravelMode.values)
              Expanded(
                child: Semantics(
                  selected: m == selected,
                  button: true,
                  label: '${m.labelTh}${status[m] == null ? '' : ' ${status[m]!.text}'}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onChanged(m),
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: AnimatedContainer(
                      duration: motion.d(Motion.tap),
                      curve: Motion.standard,
                      constraints: const BoxConstraints(minHeight: 64),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: Space.x2),
                      decoration: BoxDecoration(
                        color: m == selected ? scheme.secondaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(m.icon,
                              size: 22,
                              fill: m == selected ? 1 : 0,
                              color: m == selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant),
                          const SizedBox(height: 2),
                          Text(m.shortTh,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelLarge!.copyWith(
                                color: m == selected ? scheme.onSecondaryContainer : scheme.onSurface,
                              )),
                          if (status[m] != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(status[m]!.risk.icon,
                                    size: 12, fill: 1, color: c.riskInk(status[m]!.risk)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(status[m]!.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tabular(t.labelSmall!)
                                          .copyWith(color: c.riskInk(status[m]!.risk))),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
