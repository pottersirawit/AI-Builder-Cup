// The user's events as the two tabs show them: what is coming up, which one
// is next, and how they fall into Bangkok days.

import 'departure.dart';
import 'models.dart';
import 'time_th.dart';

/// An event that started this recently still counts as coming up: the user
/// may be running late to it.
const startedGrace = Duration(minutes: 10);

/// How far before an event the app starts planning the departure. Nearer
/// than this, the plan starts from now.
const planningWindow = Duration(hours: 3);

/// Calendar and Gmail events not yet over, earliest first; untimed last.
List<Trip> upcoming(List<Trip> trips, DateTime now) {
  final cutoff = now.subtract(startedGrace);
  // An all-day event stays on the list until its day is over.
  bool ahead(Trip t) => t.allDay
      ? (t.endsAt ?? t.arriveBy!.add(const Duration(days: 1))).isAfter(now)
      : t.arriveBy!.isAfter(cutoff);
  final timed =
      trips.where((t) => _isEvent(t) && t.arriveBy != null && ahead(t)).toList()
        ..sort((a, b) => a.arriveBy!.compareTo(b.arriveBy!));
  return [...timed, ...trips.where((t) => _isEvent(t) && t.arriveBy == null)];
}

/// The event the summary is about: the first one coming up that means
/// going somewhere. Online and all-day events need no departure.
Trip? nextEvent(List<Trip> trips, DateTime now) =>
    upcoming(trips, now).where((t) => t.travels).firstOrNull;

/// The preceding event on the same Bangkok day with a resolved destination
/// that can serve as the starting point for [current].
Trip? previousEventFor(List<Trip> trips, Trip current) {
  if (current.arriveBy == null) return null;
  final currentDay = bangkokDay(current.arriveBy!);
  final candidates = trips.where((t) {
    if (t.id == current.id || t.virtual || t.allDay || !t.destination.resolved) {
      return false;
    }
    if (t.arriveBy == null) return false;
    if (bangkokDay(t.arriveBy!) != currentDay) return false;
    return t.arriveBy!.isBefore(current.arriveBy!);
  }).toList();

  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final aEnd = a.endsAt ?? a.arriveBy!;
    final bEnd = b.endsAt ?? b.arriveBy!;
    return aEnd.compareTo(bEnd);
  });
  return candidates.last;
}

/// One Bangkok calendar day of events; [day] is null for untimed events.
typedef DayGroup = ({DateTime? day, List<Trip> trips});

/// Splits already-sorted [trips] into Bangkok days, keeping their order.
List<DayGroup> groupByDay(List<Trip> trips) {
  final groups = <DayGroup>[];
  for (final t in trips) {
    final day = t.arriveBy == null ? null : bangkokDay(t.arriveBy!);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.trips.add(t);
    } else {
      groups.add((day: day, trips: [t]));
    }
  }
  return groups;
}

/// The Bangkok date of [t] as a UTC midnight, for comparing days.
DateTime bangkokDay(DateTime t) {
  final b = toBangkok(t);
  return DateTime.utc(b.year, b.month, b.day);
}

/// The departure to ask the agent about for [trip]: now, or the start of
/// the planning window when the event is further off.
DateTime planDepartFor(Trip trip, DateTime now) {
  if (trip.allDay && trip.arriveBy != null) {
    final today = bangkokDay(now);
    final eventDay = bangkokDay(trip.arriveBy!);
    if (eventDay == today || eventDay.isBefore(today)) {
      return now;
    }
    final b = toBangkok(trip.arriveBy!);
    return DateTime.parse(
      '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}T08:00:00+07:00',
    );
  }
  final start = trip.arriveBy?.subtract(planningWindow);
  return start == null || start.isBefore(now) ? now : start;
}

bool _isEvent(Trip t) => t.source == 'calendar' || t.source == 'gmail';

/// How the hero states the departure.
enum LeaveKind {
  /// Go any time before [LeavePlan.time].
  before,

  /// Wait, then leave at [LeavePlan.time].
  at,

  /// Go now; the agent gave no deadline.
  now,

  /// The leave-by time has passed but the event has not.
  overdue,

  /// The agent advises against travelling.
  avoid,
}

/// The one answer the summary shows: when to leave, how, and when you'd
/// arrive. [best] is the top of the ranked board.
typedef LeavePlan = ({
  LeaveKind kind,
  DateTime? time,
  Departure? best,
  DateTime arriveAt,
});

/// No departure is planned this long before an event.
const staleLead = Duration(hours: 6);

/// Time to spare when backing a departure off an event's start.
const arrivalSlack = Duration(minutes: 10);

LeavePlan leavePlan(
  Decision d,
  List<Departure> board,
  DateTime now, {
  DateTime? deadline,
}) {
  final best = board.firstOrNull;
  final eta = Duration(minutes: best?.etaMin ?? 0);
  final planned = best?.departAt;
  // An answer about an earlier departure than the one planned, or hours
  // before the event, is not about this trip: back off the event's start
  // instead, else leave at the planned time.
  final lb = d.leaveBy;
  final stale =
      lb != null &&
      ((planned != null && planned.isAfter(now) && lb.isBefore(planned)) ||
          (deadline != null && lb.isBefore(deadline.subtract(staleLead))));
  final time = !stale
      ? lb
      : (deadline?.subtract(eta + arrivalSlack) ?? planned);
  final kind = switch (d.verdict) {
    Verdict.dontGo => LeaveKind.avoid,
    _ when time == null => LeaveKind.now,
    Verdict.wait => LeaveKind.at,
    _ when time.isBefore(now) => LeaveKind.overdue,
    _ => LeaveKind.before,
  };
  final from = switch (kind) {
    LeaveKind.before || LeaveKind.at => time!,
    _ => now,
  };
  return (kind: kind, time: time, best: best, arriveAt: from.add(eta));
}
