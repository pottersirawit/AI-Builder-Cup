import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/carry.dart';
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
}
