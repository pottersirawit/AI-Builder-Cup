import 'dart:ui';

import 'package:flutter/material.dart' show Text;

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  testWidgets('switching language reloads home data in that language', (
    tester,
  ) async {
    final langs = <String>[];
    final state = await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      respond: (req) {
        if (req.url.path == '/v1/home-status') {
          langs.add(req.headers['Accept-Language'] ?? '');
        }
        return null;
      },
    );
    expect(langs, ['th']);

    state.locale = const Locale('en');
    await settle(tester);
    expect(langs, ['th', 'en']);
  });

  testWidgets('Summary and Events read in English', (tester) async {
    final state = await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
    );
    state.locale = const Locale('en');
    await settle(tester);

    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Leave before'), findsOneWidget);
    expect(find.text('16:45'), findsOneWidget);
    expect(find.text('in 2 h 20 min'), findsOneWidget);
    expect(find.text('2 more today'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Before you go'), findsOneWidget);
    expect(find.text('Weather now'), findsOneWidget);
    expect(find.text('Go by'), findsOneWidget);
    expect(find.text('Arrive about'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);

    // Whatever Thai remains must be server data, never app chrome.
    const chrome = {
      'สรุป',
      'อีเวนต์',
      'อีเวนต์ถัดไป',
      'ควรออกก่อน',
      'ไปด้วย',
      'ถึงราว',
      'ฝนระหว่างทาง',
      'ฝนช่วงนี้',
      'ต่อจากนี้',
      'ตอนนี้',
    };
    Set<String> shown() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toSet();
    expect(shown().intersection(chrome), isEmpty);

    await tapAndSettle(tester, find.text('Events'));
    expect(find.text('All days'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Sa 3 Oct'), findsOneWidget);
    expect(find.text('Leave 16:45 · BTS / MRT'), findsOneWidget);
    expect(shown().intersection(chrome), isEmpty);
  });

  testWidgets('Ask sheet and the follow-up screen read in English', (
    tester,
  ) async {
    final state = await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
    );
    state.locale = const Locale('en');
    await settle(tester);

    await tapAndSettle(tester, find.byTooltip('Ask about a trip'));
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Go home now'), findsOneWidget);
    expect(find.text('Go to Siam now'), findsOneWidget);
    expect(find.text('Rain tomorrow morning?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Go home now'));

    await reveal(tester, find.text('Ask a follow-up'));
    await tapAndSettle(tester, find.text('Ask a follow-up'));
    expect(find.text('Should I take the BTS instead?'), findsOneWidget);
    expect(find.text('What if I wait until 8 pm?'), findsOneWidget);
  });

  test('strings follow the language and pluralize', () {
    final th = lookupAppLocalizations(const Locale('th'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(th.boardHeadlineLeave('16:30'), 'ออก 16:30 ได้');
    expect(en.boardHeadlineLeave('16:30'), 'Leave at 16:30');
    expect(en.homeModeEta('Car', 1), 'Car · 1 min');
    expect(en.homeModeEta('Car', 5), 'Car · 5 min');
    expect(th.homeModeEta('รถยนต์', 5), 'รถยนต์ · 5 นาที');
  });

  test('a fresh install speaks English; a saved choice still wins', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = AppState();
    await fresh.restoreLocale();
    expect(fresh.locale, const Locale('en'));

    SharedPreferences.setMockInitialValues({'language': 'th'});
    final returning = AppState();
    await returning.restoreLocale();
    expect(returning.locale, const Locale('th'));
  });
}
