// What to take out of the house today: rain gear, sun protection, water,
// decided from the next hours of weather.

import 'departure.dart';
import 'models.dart';

/// Rain this likely counts as "it will rain" for packing.
const wetChancePct = 40;

/// Strong enough sun to protect skin (WHO "high").
const highUv = 6;

/// Sun strong enough to want shade from an umbrella (WHO "very high").
const veryHighUv = 8;

/// Feels-like heat where water stops being optional.
const hotFeelsLikeC = 40.0;

/// How far ahead packing looks when no event bounds the day.
const carryHorizon = Duration(hours: 12);

enum CarryKind { raincoat, umbrella, sunUmbrella, sunscreen, water, shoes }

/// One thing to take, the hours it is for, and the peak that earned it:
/// rain chance %, UV index, or feels-like °C.
typedef CarryItem = ({CarryKind kind, DateTime? from, DateTime? to, num value});

bool isRaining(WeatherHour h) =>
    h.rainProbPct >= wetChancePct || h.rainMmPerHr >= lightRain;

/// Hours from the one containing [now] up to [until].
List<WeatherHour> hoursAhead(
  Outlook o, {
  required DateTime now,
  DateTime? until,
}) {
  final end = until ?? now.add(carryHorizon);
  return [
    for (final h in o.hours)
      if (h.time.add(const Duration(hours: 1)).isAfter(now) &&
          h.time.isBefore(end))
        h,
  ];
}

/// The first wet hour ahead, or null when it stays dry.
WeatherHour? nextRain(Outlook o, {required DateTime now, DateTime? until}) =>
    hoursAhead(o, now: now, until: until).where(isRaining).firstOrNull;

List<CarryItem> whatToCarry(
  Outlook o, {
  required DateTime now,
  DateTime? until,
  TravelMode? mode,
}) {
  final hours = hoursAhead(o, now: now, until: until);
  if (hours.isEmpty) return const [];
  const hour = Duration(hours: 1);
  CarryItem span(CarryKind k, List<WeatherHour> hs, num value) =>
      (kind: k, from: hs.first.time, to: hs.last.time.add(hour), value: value);

  final wet = hours.where(isRaining).toList();
  final sunny = hours.where((h) => h.uvIndex >= highUv).toList();
  final peakProb = wet.fold(0, (m, h) => h.rainProbPct > m ? h.rainProbPct : m);
  final peakUv = sunny.fold(0, (m, h) => h.uvIndex > m ? h.uvIndex : m);
  final hot = hours.where((h) => h.feelsLikeC >= hotFeelsLikeC).toList();
  final peakFeels = hot.fold(
    0.0,
    (m, h) => h.feelsLikeC > m ? h.feelsLikeC : m,
  );
  final heavy = wet.any((h) => h.rainMmPerHr >= heavyRain);
  final soaking = wet.where((h) => h.rainMmPerHr >= moderateRain).length >= 2;
  final moto = mode == TravelMode.moto;

  return [
    if (wet.isNotEmpty && (heavy || moto))
      span(CarryKind.raincoat, wet, peakProb),
    if (wet.isNotEmpty && !moto) span(CarryKind.umbrella, wet, peakProb),
    if (wet.isEmpty && peakUv >= veryHighUv && !moto)
      span(CarryKind.sunUmbrella, sunny, peakUv),
    if (sunny.isNotEmpty) span(CarryKind.sunscreen, sunny, peakUv),
    if (hot.isNotEmpty) span(CarryKind.water, hot, peakFeels.round()),
    if (soaking) span(CarryKind.shoes, wet, peakProb),
  ];
}

/// The hour of [o] containing [t], if the outlook reaches it.
WeatherHour? hourAt(Outlook o, DateTime t) => o.hours
    .where(
      (h) =>
          !t.isBefore(h.time) &&
          t.isBefore(h.time.add(const Duration(hours: 1))),
    )
    .firstOrNull;
