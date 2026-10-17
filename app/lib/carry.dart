// What to take out of the house today: rain gear, sun protection, water, a
// jacket, decided from the next hours of weather.

import 'departure.dart';
import 'models.dart';

/// Rain this likely is worth packing for: a spare umbrella at least.
const wetChancePct = 40;

/// Rain this likely, or any measurable rain, is "it will rain": the umbrella
/// stops being just in case.
const likelyRainPct = 60;

/// Strong enough sun to protect skin (WHO "high").
const highUv = 6;

/// Sun strong enough to want shade from an umbrella (WHO "very high").
const veryHighUv = 8;

/// Feels-like heat where water stops being optional.
const hotFeelsLikeC = 40.0;

/// Feels-like cold where a jacket is worth taking: rare in Bangkok, common
/// up north in the cool season.
const coldFeelsLikeC = 20.0;

/// How far ahead packing looks when no event bounds the day.
const carryHorizon = Duration(hours: 12);

enum CarryKind {
  raincoat,
  umbrella,
  spareUmbrella,
  spareRaincoat,
  sunUmbrella,
  sunscreen,
  water,
  jacket,
  shoes,
}

/// One thing to take, the hours it is for, and the peak that earned it:
/// rain chance %, UV index, or feels-like °C.
typedef CarryItem = ({CarryKind kind, DateTime? from, DateTime? to, num value});

bool isRaining(WeatherHour h) =>
    h.rainProbPct >= wetChancePct || h.rainMmPerHr >= lightRain;

/// Rain worth calling rain, not just a chance of it.
bool likelyRain(WeatherHour h) =>
    h.rainProbPct >= likelyRainPct || h.rainMmPerHr >= lightRain;

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
  final likely = wet.where(likelyRain).toList();
  int peakChance(List<WeatherHour> hs) =>
      hs.fold(0, (m, h) => h.rainProbPct > m ? h.rainProbPct : m);
  final sunny = hours.where((h) => h.uvIndex >= highUv).toList();
  final peakProb = peakChance(wet);
  final peakUv = sunny.fold(0, (m, h) => h.uvIndex > m ? h.uvIndex : m);
  final hot = hours.where((h) => h.feelsLikeC >= hotFeelsLikeC).toList();
  final peakFeels = hot.fold(
    0.0,
    (m, h) => h.feelsLikeC > m ? h.feelsLikeC : m,
  );
  final cold = hours.where((h) => h.feelsLikeC <= coldFeelsLikeC).toList();
  final lowFeels = cold.fold(
    coldFeelsLikeC,
    (m, h) => h.feelsLikeC < m ? h.feelsLikeC : m,
  );
  final heavy = wet.any((h) => h.rainMmPerHr >= heavyRain);
  final soaking = wet.where((h) => h.rainMmPerHr >= moderateRain).length >= 2;
  final moto = mode == TravelMode.moto;

  return [
    if (moto && likely.isNotEmpty)
      span(CarryKind.raincoat, likely, peakChance(likely))
    else if (moto && wet.isNotEmpty)
      span(CarryKind.spareRaincoat, wet, peakProb)
    else if (heavy)
      span(CarryKind.raincoat, wet, peakProb),
    if (likely.isNotEmpty && !moto)
      span(CarryKind.umbrella, likely, peakChance(likely))
    else if (wet.isNotEmpty && !moto)
      span(CarryKind.spareUmbrella, wet, peakProb),
    if (wet.isEmpty && peakUv >= veryHighUv && !moto)
      span(CarryKind.sunUmbrella, sunny, peakUv),
    if (sunny.isNotEmpty) span(CarryKind.sunscreen, sunny, peakUv),
    if (hot.isNotEmpty) span(CarryKind.water, hot, peakFeels.round()),
    if (cold.isNotEmpty) span(CarryKind.jacket, cold, lowFeels.round()),
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
