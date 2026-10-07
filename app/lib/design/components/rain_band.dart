import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../departure.dart';
import '../../models.dart';
import '../../time_th.dart';
import '../theme.dart';
import '../tokens.dart';

/// Rain intensity along the route over time, with a draggable departure
/// marker. The bracket under the bars is the time you would spend on the road.
class RainBand extends StatelessWidget {
  const RainBand({
    super.key,
    required this.points,
    required this.departAt,
    required this.earliest,
    required this.etaMin,
    this.now,
    this.onChanged,
    this.onChangeEnd,
    this.barHeight = 56,
  });

  final List<RainPoint> points;
  final DateTime departAt;

  /// The marker cannot go before this (usually "now").
  final DateTime earliest;
  final int etaMin;
  final DateTime? now;
  final ValueChanged<DateTime>? onChanged;
  final ValueChanged<DateTime>? onChangeEnd;
  final double barHeight;

  static const _bucket = Duration(minutes: 15);
  static const _bubble = 32.0;
  static const _axis = 26.0;
  static const _bracket = 10.0;

  DateTime get _start => points.first.time;
  DateTime get _end => points.last.time.add(_bucket);

  double _x(DateTime t, double width) {
    final span = _end.difference(_start).inSeconds;
    return (t.difference(_start).inSeconds / span * width).clamp(0.0, width);
  }

  DateTime _timeAt(double x, double width) {
    final span = _end.difference(_start).inSeconds;
    return _start.add(Duration(seconds: (x / width * span).round()));
  }

  DateTime _snap(DateTime t) => snapDeparture(t, earliest.isAfter(_start) ? earliest : _start, _end);

  void _set(DateTime t, ValueChanged<DateTime>? cb) {
    final s = _snap(t);
    if (s != departAt) HapticFeedback.selectionClick();
    cb?.call(s);
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final interactive = onChanged != null || onChangeEnd != null;
    final label = 'ออก ${hhmm(departAt)}';
    const step = Duration(minutes: 15);
    // The band's geometry is fixed; its labels grow only so far.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final mx = _x(departAt, w);
      final bubbleStyle = tabular(t.labelLarge!).copyWith(color: c.paper);
      final bubbleW = (TextPainter(
                text: TextSpan(text: label, style: bubbleStyle),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout())
              .width +
          Space.x5;
      final height = _bubble + Space.x1 + barHeight + _bracket + _axis;

      Widget band = SizedBox(
        height: height,
        width: w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RainBandPainter(
                  points: points,
                  x: (d) => _x(d, w),
                  departAt: departAt,
                  arriveAt: departAt.add(Duration(minutes: etaMin)),
                  now: now,
                  top: _bubble + Space.x1,
                  barHeight: barHeight,
                  colors: c,
                  axisStyle: tabular(t.labelSmall!).copyWith(color: c.paperMuted),
                  textScaler: scaler,
                ),
              ),
            ),
            Positioned(
              left: (mx - bubbleW / 2).clamp(0.0, math.max(0.0, w - bubbleW)),
              top: 0,
              height: _bubble,
              child: Container(
                key: const ValueKey('rain-band-bubble'),
                padding: const EdgeInsets.symmetric(horizontal: Space.x5 / 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.marker,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(label, style: bubbleStyle, maxLines: 1, softWrap: false, textScaler: scaler),
              ),
            ),
          ],
        ),
      );

      if (!interactive) return band;

      band = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _set(_timeAt(d.localPosition.dx, w), onChanged),
        onHorizontalDragUpdate: (d) => _set(_timeAt(d.localPosition.dx, w), onChanged),
        onHorizontalDragEnd: (_) => onChangeEnd?.call(departAt),
        onTapUp: (d) {
          final s = _snap(_timeAt(d.localPosition.dx, w));
          onChanged?.call(s);
          onChangeEnd?.call(s);
        },
        child: band,
      );

      return Semantics(
        slider: true,
        label: 'เวลาออกเดินทาง ลากเพื่อลองเวลาอื่น',
        value: label,
        increasedValue: 'ออก ${hhmm(_snap(departAt.add(step)))}',
        decreasedValue: 'ออก ${hhmm(_snap(departAt.subtract(step)))}',
        onIncrease: () => onChangeEnd?.call(_snap(departAt.add(step))),
        onDecrease: () => onChangeEnd?.call(_snap(departAt.subtract(step))),
        child: band,
      );
    });
  }
}

class _RainBandPainter extends CustomPainter {
  _RainBandPainter({
    required this.points,
    required this.x,
    required this.departAt,
    required this.arriveAt,
    required this.now,
    required this.top,
    required this.barHeight,
    required this.colors,
    required this.axisStyle,
    required this.textScaler,
  });

  final List<RainPoint> points;
  final double Function(DateTime) x;
  final DateTime departAt;
  final DateTime arriveAt;
  final DateTime? now;
  final double top;
  final double barHeight;
  final FonColors colors;
  final TextStyle axisStyle;
  final TextScaler textScaler;

  /// Bars use a soft power curve so drizzle stays visible next to 16 mm/hr.
  double _h(double mm) => 4 + math.pow((mm / 18).clamp(0.0, 1.0), .6) * (barHeight - 4);

  @override
  void paint(Canvas canvas, Size size) {
    final base = top + barHeight;
    const gap = 2.0;
    for (final p in points) {
      final x0 = x(p.time);
      final x1 = x(p.time.add(const Duration(minutes: 15)));
      final h = _h(p.mmPerHr);
      final past = now != null && p.time.add(const Duration(minutes: 15)).isBefore(now!);
      final color = colors.rain[rainLevel(p.mmPerHr)];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x0 + gap / 2, base - h, x1 - gap / 2, base),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = past ? color.withValues(alpha: .35) : color,
      );
    }

    // Time on the road.
    final ax = x(departAt), bx = math.max(x(arriveAt), ax + 4);
    canvas.drawRRect(
      RRect.fromLTRBR(ax, base + 4, bx, base + 8, const Radius.circular(2)),
      Paint()..color = colors.marker.withValues(alpha: .55),
    );

    // Now tick.
    if (now != null && !now!.isBefore(points.first.time)) {
      final nx = x(now!);
      final p = Paint()
        ..color = colors.paperMuted
        ..strokeWidth = 1;
      for (var y = top; y < base; y += 6) {
        canvas.drawLine(Offset(nx, y), Offset(nx, math.min(y + 3, base)), p);
      }
    }

    // Departure marker: a rule through the bars and a grip at the base.
    canvas.drawLine(
      Offset(ax, top - 4),
      Offset(ax, base + 8),
      Paint()
        ..color = colors.marker
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(ax, base + 6), 7, Paint()..color = colors.marker);
    canvas.drawCircle(Offset(ax, base + 6), 3, Paint()..color = colors.paper);

    // Hour axis.
    for (final p in points) {
      final b = toBangkok(p.time);
      if (b.minute != 0) continue;
      final tp = TextPainter(
        text: TextSpan(text: '${b.hour}:00', style: axisStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final px = (x(p.time) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(px, base + 12));
    }
  }

  @override
  bool shouldRepaint(_RainBandPainter old) =>
      old.departAt != departAt ||
      old.arriveAt != arriveAt ||
      old.points != points ||
      old.colors != colors ||
      old.now != now;
}
