import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/l10n.dart';
import '../../models.dart';
import '../theme.dart';
import '../tokens.dart';
import 'states.dart';

/// A static pin on a plain grid: where a place is, without a map SDK.
/// The grid shifts with the coordinates so two places never look identical;
/// the ring is the GPS accuracy radius when there is one.
class PinPreview extends StatelessWidget {
  const PinPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.height = 132,
  });
  final double lat;
  final double lng;
  final double? accuracyM;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: context.l10n.placesPinLabel(
        lat.toStringAsFixed(4),
        lng.toStringAsFixed(4),
      ),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    ground: scheme.surfaceContainerHigh,
                    line: c.perforation,
                    road: scheme.surfaceContainerLowest,
                    ring: scheme.primary,
                    phase: Offset((lng * 1e4) % 28, (lat * 1e4) % 28),
                    ringRadius: accuracyM == null
                        ? null
                        : (accuracyM! / 4).clamp(14.0, height * .45),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: Icon(
                    Symbols.location_on_rounded,
                    size: 36,
                    fill: 1,
                    color: scheme.primary,
                  ),
                ),
              ),
              Positioned(
                left: Space.x3,
                bottom: Space.x2,
                child: Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: tabular(
                    t.labelSmall!,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.ground,
    required this.line,
    required this.road,
    required this.ring,
    required this.phase,
    this.ringRadius,
  });
  final Color ground;
  final Color line;
  final Color road;
  final Color ring;
  final Offset phase;
  final double? ringRadius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final thin = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var x = -phase.dx; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thin);
    }
    for (var y = -phase.dy; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thin);
    }
    final wide = Paint()
      ..color = road
      ..strokeWidth = 7;
    canvas.drawLine(
      Offset(0, size.height * .62),
      Offset(size.width, size.height * .48),
      wide,
    );
    canvas.drawLine(
      Offset(size.width * .36, 0),
      Offset(size.width * .44, size.height),
      wide,
    );
    final r = ringRadius;
    if (r != null) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        center,
        r,
        Paint()..color = ring.withValues(alpha: .12),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = ring.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.phase != phase ||
      old.ringRadius != ringRadius ||
      old.ground != ground;
}

enum NoticeTone { info, warning }

/// A one-line hint on the page surface: what is missing or off, and the one
/// action that fixes it. Dismissible when [onDismiss] is set.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onDismiss,
    this.tone = NoticeTone.info,
  });
  final IconData icon;
  final String text;
  final Widget? action;
  final VoidCallback? onDismiss;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final warn = tone == NoticeTone.warning;
    final bg = warn ? c.riskMediumContainer : scheme.secondaryContainer;
    final ink = warn ? c.riskMedium : scheme.onSecondaryContainer;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.x3,
          Space.x2,
          onDismiss == null ? Space.x3 : 0,
          Space.x2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x1),
                child: Text(
                  text,
                  style: t.bodyMedium!.copyWith(
                    color: warn ? scheme.onSurface : ink,
                  ),
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(width: Space.x1), action!],
            if (onDismiss != null)
              IconButton(
                tooltip: context.l10n.placesDismiss,
                onPressed: onDismiss,
                icon: Icon(Symbols.close_rounded, size: 18, color: ink),
              ),
          ],
        ),
      ),
    );
  }
}

/// A connected account row: not connected, connecting, connected, failed.
class ConnectRow extends StatelessWidget {
  const ConnectRow({
    super.key,
    required this.icon,
    required this.title,
    required this.state,
    this.detail,
    this.account,
    this.onConnect,
    this.onDisconnect,
    this.comingSoon = false,
  });
  final IconData icon;
  final String title;
  final LinkState state;

  /// What connecting gives, under "ยังไม่เชื่อมต่อ".
  final String? detail;
  final String? account;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  /// Connecting is not built yet: the button says so instead.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final subtitle = switch (state) {
      LinkState.notConnected =>
        detail == null
            ? l.placesNotConnected
            : l.placesNotConnectedDetail(detail!),
      LinkState.connecting => l.placesConnecting,
      LinkState.connected => account ?? l.placesConnected,
      LinkState.error => l.placesConnectFailed,
    };
    final Widget trailing = switch (state) {
      LinkState.notConnected =>
        comingSoon
            ? OutlinedButton(onPressed: null, child: Text(l.placesComingSoon))
            : FilledButton.tonal(
                onPressed: onConnect,
                child: Text(l.placesConnect),
              ),
      LinkState.connecting => const SizedBox.square(
        dimension: Space.target,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      LinkState.connected => TextButton(
        onPressed: onDisconnect,
        child: Text(l.placesDisconnect),
      ),
      LinkState.error => FilledButton.tonal(
        onPressed: onConnect,
        child: Text(l.placesRetry),
      ),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: state == LinkState.error ? TextStyle(color: scheme.error) : null,
      ),
      trailing: trailing,
      iconColor: state == LinkState.connected ? c.riskLow : null,
    );
  }
}

/// Search results while they load: icon and two lines per row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4});
  final int rows;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.placesSearching,
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              children: [
                const Skeleton(width: 24, height: 24, radius: Radii.pill),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 120.0 + 40 * (i % 3)),
                      const SizedBox(height: Space.x2),
                      Skeleton(width: 200.0 - 30 * (i % 2), height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
