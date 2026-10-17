import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../carry.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../plan.dart';
import '../time_th.dart';
import 'event_cards.dart';
import 'weather_cards.dart';

/// "อีก 35 นาที": time to the departure, as a ring that fills while the
/// planning window runs out, like an activity ring.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.leaveAt,
    required this.now,
    this.size = 84,
  });
  final DateTime leaveAt;
  final DateTime now;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final left = leaveAt.difference(now);
    final due = left.inMinutes <= 0;
    final progress = due
        ? 1.0
        : (1 - left.inMinutes / planningWindow.inMinutes).clamp(.04, 1.0);
    final color = due
        ? c.warning
        : left.inMinutes <= 15
        ? c.riskMedium
        : const Color(0xFF4FC3F7);
    final (String big, String unit) = due
        ? ('0', l.unitMin)
        : left.inMinutes < 100
        ? ('${left.inMinutes}', l.unitMin)
        : ('${(left.inMinutes / 60).round()}', l.unitHour);
    return Semantics(
      label: due ? l.leaveDue : '${l.leaveIn} $big $unit',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _Ring(progress: progress.toDouble(), color: color),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(Space.x3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      due ? l.leaveDue : l.leaveIn,
                      style: t.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (!due) ...[
                      Text(
                        big,
                        style: tabular(
                          t.headlineSmall!,
                        ).copyWith(color: color, height: 1.1),
                      ),
                      Text(
                        unit,
                        style: t.labelSmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  const _Ring({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .10),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress || old.color != color;
}

/// The departure a plan names, if it names one.
DateTime? leaveTimeOf(LeavePlan? p) => p == null
    ? null
    : switch (p.kind) {
        LeaveKind.before || LeaveKind.at => p.time,
        _ => null,
      };

/// A small card in the "ถัดไป" row: when, what, and when to leave.
class UpNextCard extends StatelessWidget {
  const UpNextCard({
    super.key,
    required this.trip,
    required this.now,
    this.plan,
    this.weather,
    this.onTap,
  });
  final Trip trip;
  final DateTime now;
  final LeavePlan? plan;
  final Outlook? weather;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final at = trip.arriveBy!;
    final today = bangkokDay(now);
    final day = bangkokDay(at);
    final when = trip.allDay
        ? allDayLabel(l, trip)
        : day == today
        ? hhmm(at)
        : '${dayChipLabel(l, day, today)} · ${hhmm(at)}';
    final p = plan;
    final leave = leaveTimeOf(p);
    final w = weather == null || !trip.travels
        ? null
        : hourAt(weather!, leave ?? at);

    final Widget detail;
    if (trip.virtual) {
      detail = _line(
        t,
        Symbols.videocam_rounded,
        l.online,
        scheme.onSurfaceVariant,
      );
    } else if (trip.allDay) {
      detail = _line(
        t,
        Symbols.event_rounded,
        l.allDay,
        scheme.onSurfaceVariant,
      );
    } else if (trip.unresolved) {
      detail = _line(t, Symbols.help_rounded, l.summarySetPlace, c.warning);
    } else if (p != null && p.best != null) {
      detail = Wrap(
        spacing: Space.x2,
        runSpacing: Space.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            p.kind == LeaveKind.avoid
                ? l.eventsAvoid
                : l.eventsLeaveAt(
                    leave == null ? l.summaryLeaveNow : hhmm(leave),
                    p.best!.mode.shortLabel(l),
                  ),
            style: tabular(t.labelMedium!),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.riskInk(p.best!.risk),
            ),
          ),
        ],
      );
    } else {
      detail = _line(
        t,
        Symbols.location_on_rounded,
        trip.destination.nameTh,
        scheme.onSurfaceVariant,
      );
    }

    return SizedBox(
      width: 184,
      child: GlassSurface(
        radius: Radii.lg,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        when,
                        style: tabular(
                          t.labelLarge!,
                        ).copyWith(color: const Color(0xFF8AB4FF)),
                      ),
                      if (w != null) WeatherTag(hour: w),
                    ],
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    trip.titleTh,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall,
                  ),
                  const SizedBox(height: Space.x2),
                  detail,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _line(TextTheme t, IconData icon, String text, Color color) =>
      Row(
        children: [
          Icon(icon, size: 14, fill: 1, color: color),
          const SizedBox(width: Space.x1),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelMedium!.copyWith(color: color),
            ),
          ),
        ],
      );
}

/// "ต้องรู้ก่อนออก": only what changes the plan; hidden when nothing does.
class AlertsCard extends StatelessWidget {
  const AlertsCard({super.key, required this.alerts, required this.onTap});
  final List<PlanAlert> alerts;
  final ValueChanged<PlanAlert> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    return GlassSurface(
      radius: Radii.lg,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, a) in alerts.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Colors.white.withValues(alpha: .10),
                ),
              Builder(
                builder: (context) {
                  final look = _look(l, c, a);
                  return InkWell(
                    key: ValueKey('alert-${a.kind.name}-${a.trip.id}'),
                    onTap: () => onTap(a),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.x4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: look.color.withValues(alpha: .18),
                            ),
                            child: Icon(
                              look.icon,
                              size: 16,
                              fill: 1,
                              color: look.color,
                            ),
                          ),
                          const SizedBox(width: Space.x3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(look.title, style: t.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  look.body,
                                  style: tabular(
                                    t.bodySmall!,
                                  ).copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.chevron_right_rounded,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static ({IconData icon, Color color, String title, String body}) _look(
    AppLocalizations l,
    FonColors c,
    PlanAlert a,
  ) {
    final to = a.trip.titleTh;
    final when = a.at == null ? '' : hhmm(a.at!);
    switch (a.kind) {
      case AlertKind.shortConnection:
        final from = a.other!.titleTh;
        final overlap = a.gap!.isNegative || a.gap == Duration.zero;
        return (
          icon: Symbols.timer_off_rounded,
          color: c.riskHigh,
          title: overlap ? l.alertOverlap(from, to) : l.alertShort(to),
          body: l.alertShortBody(
            from,
            when,
            durationText(l, a.need!),
            overlap ? l.durationM('0') : durationText(l, a.gap!),
          ),
        );
      case AlertKind.tightConnection:
        return (
          icon: Symbols.timer_rounded,
          color: c.riskMedium,
          title: l.alertTight(to),
          body: l.alertTightBody(
            durationText(l, a.need!),
            durationText(l, a.gap!),
            a.other!.titleTh,
          ),
        );
      case AlertKind.wetLeave:
        return (
          icon: Symbols.rainy_rounded,
          color: const Color(0xFF6EA8FF),
          title: l.alertWetLeave('${a.value}', to),
          body: a.trip.mode == TravelMode.moto
              ? l.alertWetLeaveMoto(when)
              : l.alertWetLeaveBody(when),
        );
      case AlertKind.wetReturn:
        return (
          icon: Symbols.umbrella_rounded,
          color: const Color(0xFF6EA8FF),
          title: l.alertWetReturn(to, '${a.value}'),
          body: a.trip.mode == TravelMode.moto
              ? l.alertWetReturnMoto(when)
              : l.alertWetReturnBody(when),
        );
      case AlertKind.needsPlace:
        final at = a.trip.arriveBy;
        return (
          icon: Symbols.add_location_alt_rounded,
          color: c.warning,
          title: l.alertNeedsPlace(to),
          body: l.alertNeedsPlaceBody(at == null ? '' : dayDate(l, at)),
        );
    }
  }
}

/// Now until midnight on one bar: rain behind, events and the travel to
/// them in front, so a ride through a downpour is seen at a glance.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.trips,
    required this.now,
    required this.leaveAt,
    this.outlook,
  });
  final List<Trip> trips;
  final DateTime now;
  final DateTime? Function(Trip) leaveAt;
  final Outlook? outlook;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final start = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch - now.millisecondsSinceEpoch % 3600000,
    );
    final end = bangkokDay(
      now,
    ).add(const Duration(days: 1)).subtract(const Duration(hours: 7));
    final span = end.difference(start).inMinutes.toDouble();
    double x(DateTime d) =>
        (d.difference(start).inMinutes / span).clamp(0.0, 1.0);
    final today = trips
        .where(
          (tr) => tr.travels && bangkokDay(tr.arriveBy!) == bangkokDay(now),
        )
        .toList();
    final ticks = [
      for (var h = start; h.isBefore(end); h = h.add(const Duration(hours: 3)))
        h,
    ];

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: Space.x1),
        Text(
          label,
          style: t.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );

    return GlassSurface(
      radius: Radii.lg,
      padding: const EdgeInsets.all(Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _StripPainter(
                rain: [
                  if (outlook != null)
                    for (final h in outlook!.hours)
                      if (h.time.add(const Duration(hours: 1)).isAfter(start) &&
                          h.time.isBefore(end))
                        (
                          a: x(h.time),
                          b: x(h.time.add(const Duration(hours: 1))),
                          level: isRaining(h)
                              ? (h.rainMmPerHr >= 7.6
                                    ? 3
                                    : h.rainMmPerHr >= 2.5
                                    ? 2
                                    : 1)
                              : 0,
                        ),
                ],
                events: [
                  for (final tr in today) (a: x(tr.arriveBy!), b: x(endOf(tr))),
                ],
                travel: [
                  for (final tr in today)
                    if (leaveAt(tr) case final d?)
                      (a: x(d), b: x(tr.arriveBy!)),
                ],
                rainColors: c.rain,
              ),
            ),
          ),
          const SizedBox(height: Space.x1),
          SizedBox(
            height: 16,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final h in ticks)
                    Positioned(
                      left: x(h) * box.maxWidth,
                      child: Text(
                        h == start ? l.wxNow : hhmm(h),
                        style: tabular(
                          t.labelSmall!,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.x3),
          Wrap(
            spacing: Space.x4,
            runSpacing: Space.x1,
            children: [
              legend(const Color(0xFF2E6BFF), l.stripEvent),
              legend(const Color(0xFFFFC34D), l.stripTravel),
              legend(c.rain[2], l.stripRain),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _Span = ({double a, double b});

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.rain,
    required this.events,
    required this.travel,
    required this.rainColors,
  });
  final List<({double a, double b, int level})> rain;
  final List<_Span> events;
  final List<_Span> travel;
  final List<Color> rainColors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = Colors.white.withValues(alpha: .05),
    );
    for (final r in rain) {
      if (r.level == 0) continue;
      final rh = h * (.35 + .2 * r.level);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.a * w + 1, h - rh, (r.b - r.a) * w - 2, rh),
          const Radius.circular(4),
        ),
        Paint()..color = rainColors[r.level].withValues(alpha: .55),
      );
    }
    void bar(_Span s, Color color, double top, double height) {
      final width = math.max((s.b - s.a) * w, 6.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.a * w, top, width, height),
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );
    }

    for (final s in travel) {
      bar(s, const Color(0xFFFFC34D), h * .18, h * .26);
    }
    for (final s in events) {
      bar(s, const Color(0xFF2E6BFF), h * .14, h * .34);
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => true;
}
