// What could go wrong with the day's plan: hops between events that the
// gap cannot cover, rain on a departure or on the way back, and events the
// app cannot plan because it does not know where they are.

import 'carry.dart';
import 'departure.dart';
import 'events.dart';
import 'models.dart';
import 'places.dart';

/// Straight lines become roads about a third longer in Bangkok.
const _roadFactor = 1.35;

/// Closer than this, the next event is effectively in the same building.
const _sameSpotM = 400.0;

/// Door-to-door speeds in town, km/h, and fixed overhead (parking, the walk
/// to the station and the wait).
const _speed = {
  TravelMode.car: 12.0,
  TravelMode.moto: 20.0,
  TravelMode.transit: 20.0,
};
const _overhead = {
  TravelMode.car: Duration(minutes: 5),
  TravelMode.moto: Duration(minutes: 3),
  TravelMode.transit: Duration(minutes: 12),
};

/// An event with no end time is taken to last this long.
const assumedLength = Duration(hours: 1);

/// Spare time under which a hop counts as tight.
const tightSpare = Duration(minutes: 15);

/// Rough door-to-door time from [a] to [b]; no routing call needed.
Duration travelEstimate(Place a, Place b, TravelMode mode) {
  final m = distanceM(a.lat, a.lng, b.lat, b.lng);
  if (m < _sameSpotM) return Duration.zero;
  final km = m * _roadFactor / 1000;
  final minutes = (km / _speed[mode]! * 60).round();
  return Duration(minutes: minutes) + _overhead[mode]!;
}

enum ConnectionFit { ok, tight, short }

/// Going straight from one event to the next.
class Connection {
  const Connection({
    required this.from,
    required this.to,
    required this.gap,
    required this.need,
  });
  final Trip from;
  final Trip to;

  /// From the end of [from] to the start of [to]; negative when they overlap.
  final Duration gap;
  final Duration need;

  ConnectionFit get fit => gap < need
      ? ConnectionFit.short
      : gap < need + tightSpare
      ? ConnectionFit.tight
      : ConnectionFit.ok;
}

DateTime endOf(Trip t) => t.endsAt ?? t.arriveBy!.add(assumedLength);

/// Back-to-back hops between placed, in-person events on the same day.
List<Connection> connections(List<Trip> trips) {
  final placed = trips.where((t) => t.travels && !t.unresolved).toList()
    ..sort((a, b) => a.arriveBy!.compareTo(b.arriveBy!));
  return [
    for (var i = 1; i < placed.length; i++)
      if (bangkokDay(placed[i - 1].arriveBy!) ==
          bangkokDay(placed[i].arriveBy!))
        Connection(
          from: placed[i - 1],
          to: placed[i],
          gap: placed[i].arriveBy!.difference(endOf(placed[i - 1])),
          need: travelEstimate(
            placed[i - 1].destination,
            placed[i].destination,
            placed[i].mode,
          ),
        ),
  ];
}

/// Most serious first.
enum AlertKind {
  shortConnection,
  wetLeave,
  wetReturn,
  tightConnection,
  needsPlace,
}

/// One thing the user should know before leaving.
class PlanAlert {
  const PlanAlert({
    required this.kind,
    required this.trip,
    this.other,
    this.at,
    this.value = 0,
    this.gap,
    this.need,
  });
  final AlertKind kind;

  /// The event it is about (for a connection, the one being travelled to).
  final Trip trip;

  /// For a connection, the event before.
  final Trip? other;
  final DateTime? at;

  /// Rain chance % for weather alerts.
  final num value;
  final Duration? gap;
  final Duration? need;
}

/// Rain heavy or likely enough to change how one travels.
bool _soaking(WeatherHour h) =>
    isRaining(h) && (h.rainProbPct >= 60 || h.rainMmPerHr >= moderateRain);

/// The card stays a glance, not a list.
const maxAlerts = 3;

/// How far ahead alerts look.
const alertHorizon = Duration(hours: 36);

/// Without an answer from the agent, a departure is assumed this early.
const _assumedLead = Duration(minutes: 45);

List<PlanAlert> planAlerts({
  required List<Trip> trips,
  required DateTime now,
  required DateTime? Function(Trip) leaveAt,
  Outlook? outlook,
}) {
  final soon = upcoming(trips, now)
      .where(
        (t) =>
            t.arriveBy != null && t.arriveBy!.difference(now) <= alertHorizon,
      )
      .toList();
  final today = bangkokDay(now);
  final out = <PlanAlert>[];

  for (final c in connections(soon)) {
    if (c.to.arriveBy!.isBefore(now) || c.fit == ConnectionFit.ok) continue;
    out.add(
      PlanAlert(
        kind: c.fit == ConnectionFit.short
            ? AlertKind.shortConnection
            : AlertKind.tightConnection,
        trip: c.to,
        other: c.from,
        at: endOf(c.from),
        gap: c.gap,
        need: c.need,
      ),
    );
  }

  final placedToday = soon
      .where(
        (t) => t.travels && !t.unresolved && bangkokDay(t.arriveBy!) == today,
      )
      .toList();
  if (outlook != null) {
    for (final t in placedToday.where((t) => t.arriveBy!.isAfter(now))) {
      final planned = leaveAt(t) ?? t.arriveBy!.subtract(_assumedLead);
      final leave = planned.isBefore(now) ? now : planned;
      final h = hourAt(outlook, leave);
      if (h != null && _soaking(h)) {
        out.add(
          PlanAlert(
            kind: AlertKind.wetLeave,
            trip: t,
            at: leave,
            value: h.rainProbPct,
          ),
        );
      }
    }
    if (placedToday.isNotEmpty) {
      final last = placedToday.last;
      final back = endOf(last);
      final h = hourAt(outlook, back);
      if (h != null && _soaking(h)) {
        out.add(
          PlanAlert(
            kind: AlertKind.wetReturn,
            trip: last,
            at: back,
            value: h.rainProbPct,
          ),
        );
      }
    }
  }

  for (final t in soon.where((t) => t.unresolved && !t.virtual && !t.allDay)) {
    out.add(PlanAlert(kind: AlertKind.needsPlace, trip: t, at: t.arriveBy));
  }

  bool isToday(PlanAlert a) => bangkokDay(a.trip.arriveBy!) == today;
  out.sort((a, b) {
    final d = (isToday(a) ? 0 : 1).compareTo(isToday(b) ? 0 : 1);
    return d != 0 ? d : a.kind.index.compareTo(b.kind.index);
  });
  return out.take(maxAlerts).toList();
}
