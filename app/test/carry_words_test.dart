import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/carry.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/l10n/app_localizations.dart';
import 'package:fontokmai/screens/weather_cards.dart';

void main() {
  final from = DateTime.parse('2026-09-29T14:00:00+07:00');
  final to = DateTime.parse('2026-09-29T16:00:00+07:00');
  final spare = (kind: CarryKind.spareUmbrella, from: from, to: to, value: 55);

  test('the spare umbrella reads its chance and hours in order', () {
    final th = lookupAppLocalizations(const Locale('th'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(carryLook(th, spare).why, 'อาจมีฝน 55% · 14:00–16:00');
    expect(carryLook(en, spare).why, 'Maybe rain, 55% · 14:00–16:00');
  });

  test('a rider\'s raincoat is for riding in rain, not a downpour', () {
    final th = lookupAppLocalizations(const Locale('th'));
    final coat = (kind: CarryKind.raincoat, from: from, to: to, value: 80);
    expect(
      carryLook(th, coat, moto: true).why,
      th.carryWhyMoto('14:00', '16:00'),
    );
    expect(carryLook(th, coat).why, th.carryWhyHeavy('14:00', '16:00'));
    final spare = (
      kind: CarryKind.spareRaincoat,
      from: from,
      to: to,
      value: 45,
    );
    expect(carryLook(th, spare, moto: true).why, 'อาจมีฝน 45% · 14:00–16:00');
  });

  test('a wet hour now is never "no rain for 12 hours"', () {
    final th = lookupAppLocalizations(const Locale('th'));
    WeatherHour h(int hour, int prob, double mm) => WeatherHour(
      time: DateTime.parse(
        '2026-09-29T00:00:00+07:00',
      ).add(Duration(hours: hour)),
      tempC: 30,
      feelsLikeC: 34,
      uvIndex: 0,
      rainProbPct: prob,
      rainMmPerHr: mm,
    );
    final o = Outlook(
      now: h(16, 85, 0.3),
      hours: [h(16, 85, 0.3), h(17, 10, 0)],
    );
    final line = weatherHeadline(
      th,
      o,
      DateTime.parse('2026-09-29T16:10:00+07:00'),
    );
    expect(line, isNot(contains(th.wxDryAhead)));
    expect(line, contains(th.wxMaybeRainNow));
  });
}
