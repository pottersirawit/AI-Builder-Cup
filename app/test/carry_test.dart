import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/carry.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/time_th.dart';

final _day = DateTime.parse('2026-09-29T00:00:00+07:00');

WeatherHour _h(
  int hour, {
  double temp = 31,
  double feels = 35,
  int uv = 0,
  int prob = 0,
  double mm = 0,
}) => WeatherHour(
  time: _day.add(Duration(hours: hour)),
  tempC: temp,
  feelsLikeC: feels,
  uvIndex: uv,
  rainProbPct: prob,
  rainMmPerHr: mm,
);

/// Hot sunny afternoon, storm 17:00-19:00: the demo day.
final _storm = Outlook(
  now: _h(13, uv: 9, feels: 41),
  hours: [
    _h(13, uv: 9, feels: 41),
    _h(14, uv: 9, feels: 42),
    _h(15, uv: 7, feels: 40),
    _h(16, uv: 4, prob: 30),
    _h(17, uv: 1, prob: 85, mm: 4),
    _h(18, prob: 100, mm: 12),
    _h(19, prob: 90, mm: 3),
    _h(20, prob: 30),
  ],
);

List<CarryKind> _kinds(List<CarryItem> items) => [
  for (final i in items) i.kind,
];

void main() {
  final at = (int h, [int m = 0]) => _day.add(Duration(hours: h, minutes: m));

  test('a hot afternoon before a storm: rain gear first, then sun', () {
    final items = whatToCarry(_storm, now: at(13, 30));
    expect(_kinds(items), [
      CarryKind.raincoat,
      CarryKind.umbrella,
      CarryKind.sunscreen,
      CarryKind.water,
      CarryKind.shoes,
    ]);
    final umbrella = items[1];
    expect(hhmm(umbrella.from!), '17:00');
    expect(hhmm(umbrella.to!), '20:00', reason: 'end of the last wet hour');
    expect(umbrella.value, 100, reason: 'peak rain chance');
    expect(items[2].value, 9, reason: 'peak UV');
    expect(items[3].value, 42, reason: 'peak feels-like');
  });

  test('a strong sun with no rain offers an umbrella for shade', () {
    final items = whatToCarry(_storm, now: at(13), until: at(16));
    expect(_kinds(items), [
      CarryKind.sunUmbrella,
      CarryKind.sunscreen,
      CarryKind.water,
    ]);
  });

  test('riding a motorbike, any rain means a raincoat, not an umbrella', () {
    final light = Outlook(now: _h(9), hours: [_h(9), _h(10, prob: 60, mm: 1)]);
    expect(_kinds(whatToCarry(light, now: at(9), mode: TravelMode.moto)), [
      CarryKind.raincoat,
    ]);
    expect(_kinds(whatToCarry(light, now: at(9))), [CarryKind.umbrella]);
  });

  test('the evening after the storm needs nothing', () {
    expect(whatToCarry(_storm, now: at(20)), isEmpty);
  });

  test('the next wet hour and whether it is raining now', () {
    expect(hhmm(nextRain(_storm, now: at(13, 30))!.time), '17:00');
    expect(nextRain(_storm, now: at(20)), isNull);
    expect(isRaining(_storm.hours[5]), isTrue);
    expect(isRaining(_storm.hours[3]), isFalse, reason: '30% is not rain');
  });
}
