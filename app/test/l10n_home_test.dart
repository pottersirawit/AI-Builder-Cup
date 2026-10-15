import 'dart:ui';

import 'package:flutter/material.dart' show Text;

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/l10n/l10n.dart';

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

  testWidgets('Home, board and quick asks read in English', (tester) async {
    final state = await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
    );
    state.locale = const Locale('en');
    await settle(tester);

    expect(find.text('Hi Miw'), findsOneWidget);
    expect(find.text('Go home now'), findsOneWidget);
    expect(find.text('Go to Siam now'), findsOneWidget);
    expect(find.text('Ask more'), findsOneWidget);
    expect(
      find.text('Dismiss notification'),
      findsNothing,
      reason: 'tooltip, not text',
    );
    expect(find.byTooltip('Dismiss notification'), findsOneWidget);
    expect(find.textContaining('Fon Tok Mai ·'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Report flood'), findsOneWidget);
    expect(find.text('Quick ask'), findsOneWidget);
    expect(find.textContaining(RegExp(r'· \d+ min')), findsWidgets);

    // Whatever Thai remains must be server data, never app chrome.
    const chrome = {
      'ถามเร็ว',
      'ตั้งค่า',
      'ถามต่อ',
      'ทริปถัดไป',
      'ที่บ้านคืนนี้',
      'ถึง',
      'รอวัน',
      'กลับบ้านตอนนี้',
      'ไปสยามตอนนี้',
      'เดินทาง',
      'บ้าน',
    };
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toSet();
    expect(shown.intersection(chrome), isEmpty);
    expect(
      shown.where((s) => RegExp(r'^(ออก|พรีวิว) |นาที$|^ทางกลับ').hasMatch(s)),
      isEmpty,
    );
  });

  testWidgets('Ask screen reads in English', (tester) async {
    final state = await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
    );
    state.locale = const Locale('en');
    await settle(tester);

    await tapAndSettle(tester, find.text('Ask more'));
    expect(find.text('Ask more'), findsOneWidget);
    expect(find.textContaining('Right now I suggest'), findsOneWidget);
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
}
