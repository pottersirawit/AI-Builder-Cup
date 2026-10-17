import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/screens/weather_cards.dart';

import 'helpers.dart';

void main() {
  testWidgets('the weather sheet fits its card and fills it with the day', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T13:10:00+07:00', height: 2400);
    await tapAndSettle(tester, find.byType(WeatherPeek));

    final card = find.byType(WeatherHeroCard);
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    expect(
      tester.getSize(card).height,
      lessThan(700),
      reason: 'the card hugs its content instead of filling the sheet',
    );
    expect(inCard('อาจมีฝนราว 16:00'), findsOneWidget);
    expect(inCard('ความชื้น'), findsOneWidget);
    expect(inCard('60%'), findsWidgets, reason: 'humidity, and 20:00 rain');
    expect(inCard('ลม'), findsOneWidget);
    expect(inCard('10 กม./ชม.'), findsOneWidget);
    expect(inCard('อาทิตย์ตก'), findsOneWidget);
    expect(inCard('18:10'), findsOneWidget);
    expect(
      inCard('25%'),
      findsOneWidget,
      reason: 'a dry hour still shows its rain chance',
    );
    expect(inCard('Google Weather API (scenario)'), findsOneWidget);
  });

  testWidgets('a wet chance this hour points the line at the next hour', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', height: 2400);
    await tapAndSettle(tester, find.byType(WeatherPeek));
    final card = find.byType(WeatherHeroCard);
    expect(
      find.descendant(of: card, matching: find.text('ฝนมาราว 17:00')),
      findsOneWidget,
    );
  });

  testWidgets('the one-line headline never names a past or unlikely hour', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', height: 2400);
    final peek = find.byType(WeatherPeek);
    String line() => tester
        .widgetList<Text>(
          find.descendant(of: peek, matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.contains('ฝน'));
    expect(
      line(),
      contains('ฝนมาราว 17:00'),
      reason: 'not 16:00, already here',
    );
  });
}
