// The departure board's domain: what each way of travelling looks like if you
// leave at a given minute. While the user drags the departure marker the app
// shows a local preview from the rain timeline it already has; on release the
// agent's real verdict replaces it.

import 'package:flutter/widgets.dart' show Locale;

import 'l10n/l10n.dart';
import 'models.dart';

AppLocalizations _thai() => lookupAppLocalizations(const Locale('th'));

/// The sky the user is travelling under; it drives the colour of the ground.
enum SkyState { clear, storm, flood }

const _bucket = Duration(minutes: 15);

/// Rain thresholds in mm/hr (Thai Meteorological Department bands).
const lightRain = 0.5;
const moderateRain = 2.5;
const heavyRain = 7.6;

/// 0 none, 1 light, 2 moderate, 3 heavy.
int rainLevel(double mmPerHr) => mmPerHr < lightRain
    ? 0
    : mmPerHr < moderateRain
    ? 1
    : mmPerHr < heavyRain
    ? 2
    : 3;

/// Rain in the 15-minute bucket containing [t]; 0 outside the timeline.
double rainAt(List<RainPoint> points, DateTime t) {
  for (final p in points) {
    if (!t.isBefore(p.time) && t.isBefore(p.time.add(_bucket)))
      return p.mmPerHr;
  }
  return 0;
}

/// Heaviest rain in any bucket overlapping [from, to).
double peakRain(List<RainPoint> points, DateTime from, DateTime to) {
  var peak = 0.0;
  for (final p in points) {
    if (p.time.isBefore(to) &&
        p.time.add(_bucket).isAfter(from) &&
        p.mmPerHr > peak) {
      peak = p.mmPerHr;
    }
  }
  return peak;
}

/// Highest rain probability in the samples overlapping [from]..[to].
int peakRainProb(List<RainPoint> samples, DateTime from, DateTime to) {
  var peak = 0;
  for (final s in samples) {
    if (s.time.isAfter(to)) break;
    if (s.time.isBefore(from)) continue;
    if (s.probPct > peak) peak = s.probPct;
  }
  return peak;
}

/// One way to make the trip if you leave at [departAt].
class Departure {
  const Departure({
    required this.mode,
    required this.verdict,
    required this.risk,
    required this.etaMin,
    required this.departAt,
    required this.noteTh,
    required this.isPreview,
    this.rainProbPct = 0,
    this.viaTh = const [],
    this.transitLegs = const [],
  });

  final TravelMode mode;
  final Verdict verdict;
  final Risk risk;
  final int etaMin;
  final DateTime departAt;
  final String noteTh;

  /// True when computed on the device during a drag, before the agent answers.
  final bool isPreview;
  final int rainProbPct;

  final List<String> viaTh;
  final List<TransitLeg> transitLegs;

  DateTime get arriveAt => departAt.add(Duration(minutes: etaMin));
}

/// Car trips through heavy rain on this route take roughly twice as long.
const _stormSlowdown = 1.9;

/// Local estimate of every mode in [d] for a departure at [departAt]. The
/// notes are written in [l]'s language (Thai when omitted).
List<Departure> previewOptions(
  Decision d,
  DateTime departAt, [
  AppLocalizations? l,
]) => [
  for (final o in d.modeOptions)
    _preview(d.rainTimeline, o, departAt, l ?? _thai()),
];

Departure _preview(
  List<RainPoint> rain,
  ModeOption o,
  DateTime departAt,
  AppLocalizations l,
) {
  // The agent's car ETA already includes storm traffic when it judged high risk.
  final calmEta = o.mode == TravelMode.car && o.risk == Risk.high
      ? (o.etaMin / _stormSlowdown).round()
      : o.etaMin;
  final calmArrive = departAt.add(Duration(minutes: calmEta));
  final peak = peakRain(rain, departAt, calmArrive);
  final peakProb = peakRainProb(rain, departAt, calmArrive);
  // Rain that starts within the hour after arriving: beaten, or nearly.
  final soon = peakRain(
    rain,
    departAt,
    calmArrive.add(const Duration(hours: 1)),
  );
  final dryNote = soon >= lightRain ? l.boardNoteBeatRain : l.boardNoteDry;

  Departure make(Verdict v, Risk r, String note, [int? eta]) => Departure(
    mode: o.mode,
    verdict: v,
    risk: r,
    etaMin: eta ?? calmEta,
    departAt: departAt,
    noteTh: note,
    isPreview: true,
    rainProbPct: peakProb > 0 ? peakProb : o.rainProbPct,
    viaTh: o.viaTh,
    transitLegs: o.transitLegs,
  );

  switch (o.mode) {
    case TravelMode.transit:
      return peak >= heavyRain
          ? make(Verdict.leaveNow, Risk.medium, l.boardNoteTransitCrowded)
          : peak >= lightRain
          ? make(Verdict.leaveNow, Risk.low, l.boardNoteTransitWalk)
          : make(Verdict.leaveNow, Risk.low, l.boardNoteDry);
    case TravelMode.car:
      if (peak >= heavyRain) {
        return make(
          Verdict.wait,
          Risk.high,
          l.boardNoteCarHeavy,
          (calmEta * _stormSlowdown).round(),
        );
      }
      return peak >= lightRain
          ? make(Verdict.leaveNow, Risk.medium, l.boardNoteCarDrizzle)
          : make(Verdict.leaveNow, Risk.low, dryNote);
    case TravelMode.moto:
      if (peak >= moderateRain) {
        return make(Verdict.dontGo, Risk.high, l.boardNoteMotoHeavy);
      }
      // Riders get caught by rain that starts soon after they arrive too.
      if (peak >= lightRain || soon >= lightRain) {
        return make(Verdict.leaveNow, Risk.medium, l.boardNoteMotoTight);
      }
      if (peakProb >= 60) {
        return make(
          Verdict.leaveNow,
          Risk.medium,
          l.isThai
              ? 'โอกาสฝนตก $peakProb% ควรเตรียมเสื้อกันฝน'
              : '$peakProb% chance of rain — pack rain gear',
        );
      }
      return make(Verdict.leaveNow, Risk.low, l.boardNoteDry);
  }
}

/// The agent's own per-mode answers, as departures at [departAt].
List<Departure> serverOptions(Decision d, DateTime departAt) => [
  for (final o in d.modeOptions)
    Departure(
      mode: o.mode,
      verdict: o.verdict,
      risk: o.risk,
      etaMin: o.etaMin,
      departAt: departAt,
      noteTh: o.noteTh,
      isPreview: false,
      rainProbPct: o.rainProbPct,
      viaTh: o.viaTh,
      transitLegs: o.transitLegs,
    ),
];

/// The first five-minute departure after [from], within the rain timeline,
/// at which [mode] can go by the on-device estimate, arriving by [deadline]
/// when there is one. Null when waiting does not help.
Departure? nextGoodDeparture(
  Decision d,
  TravelMode mode,
  DateTime from, {
  DateTime? deadline,
  AppLocalizations? l,
}) {
  final points = d.rainTimeline;
  if (points.isEmpty) return null;
  final end = points.last.time.add(_bucket);
  for (
    var t = snapDeparture(from.add(_step), from, end);
    t.isBefore(end) && t.isAfter(from);
    t = t.add(_step)
  ) {
    final o = previewOptions(d, t, l).where((o) => o.mode == mode).firstOrNull;
    if (o == null) return null;
    if (deadline != null && o.arriveAt.isAfter(deadline)) return null;
    if (o.verdict == Verdict.leaveNow) return o;
  }
  return null;
}

/// The best other way to go at the same departure: one that can go and,
/// with a [deadline], gets there in time. [board] is ranked best first.
Departure? otherModeThatGoes(
  List<Departure> board,
  TravelMode mode, {
  DateTime? deadline,
}) => board
    .where(
      (o) =>
          o.mode != mode &&
          o.verdict == Verdict.leaveNow &&
          (deadline == null || !o.arriveAt.isAfter(deadline)),
    )
    .firstOrNull;

int _verdictRank(Verdict v) => switch (v) {
  Verdict.leaveNow => 0,
  Verdict.switchMode => 1,
  Verdict.wait => 2,
  Verdict.dontGo => 3,
};

/// Board order: go-able first, then lower risk, then earlier arrival.
List<Departure> rankOptions(List<Departure> options) =>
    [...options]..sort((a, b) {
      final v = _verdictRank(a.verdict).compareTo(_verdictRank(b.verdict));
      if (v != 0) return v;
      final r = a.risk.index.compareTo(b.risk.index);
      if (r != 0) return r;
      return a.arriveAt.compareTo(b.arriveAt);
    });

String _hhmm(DateTime t) {
  final b = t.toUtc().add(const Duration(hours: 7));
  return '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
}

/// Verdict line for [mode] while previewing, in the agent's voice.
String previewHeadline(
  List<Departure> options,
  TravelMode mode, [
  AppLocalizations? l10n,
]) {
  final l = l10n ?? _thai();
  final mine = options.where((o) => o.mode == mode).firstOrNull;
  if (mine == null) return '';
  switch (mine.verdict) {
    case Verdict.leaveNow:
      return l.boardHeadlineLeave(_hhmm(mine.departAt));
    case Verdict.wait:
      return l.boardHeadlineWait;
    case Verdict.switchMode:
    case Verdict.dontGo:
      final transitOk = options.any(
        (o) =>
            o.mode == TravelMode.transit &&
            o.mode != mode &&
            o.verdict == Verdict.leaveNow,
      );
      return transitOk ? l.boardHeadlineSwitchTransit : l.boardHeadlineWait;
  }
}

/// The ground colour for a trip leaving at [departAt] taking [etaMin].
SkyState skyFor(
  List<RainPoint> rain,
  DateTime departAt,
  int etaMin, {
  Verdict? verdict,
  HomeLevel? home,
}) {
  if (home == HomeLevel.danger) return SkyState.flood;
  if (verdict != null && verdict != Verdict.leaveNow) return SkyState.storm;
  final peak = peakRain(
    rain,
    departAt,
    departAt.add(Duration(minutes: etaMin)),
  );
  return peak >= moderateRain ? SkyState.storm : SkyState.clear;
}

const _step = Duration(minutes: 5);

DateTime _floor5(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
  t.millisecondsSinceEpoch - t.millisecondsSinceEpoch % _step.inMilliseconds,
  isUtc: true,
);

/// Nearest five-minute mark, kept within [start, end].
DateTime snapDeparture(DateTime t, DateTime start, DateTime end) {
  final ms = _step.inMilliseconds;
  final rounded = DateTime.fromMillisecondsSinceEpoch(
    ((t.millisecondsSinceEpoch + ms / 2) ~/ ms) * ms,
    isUtc: true,
  );
  final lo = _floor5(start).isBefore(start)
      ? _floor5(start).add(_step)
      : _floor5(start);
  final hi = _floor5(end);
  if (rounded.isBefore(lo)) return lo;
  if (rounded.isAfter(hi)) return hi;
  return rounded;
}
