import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/screens/activity_cards.dart';

import 'helpers.dart';

const _clock = '2026-09-29T16:10:00+07:00';

Map<String, dynamic> _plan({bool asks = true}) => {
  'kind': 'climbing',
  'name_th': 'ปีนผา',
  if (!asks) 'day': '2026-10-03',
  'headline_th': 'เตรียมตัวไปปีนผา',
  'checklist': [
    {'item_th': 'รองเท้าปีนผา', 'why_th': 'ยึดเกาะหินได้ดี'},
    {'item_th': 'ถุงชอล์ก', 'why_th': 'มือไม่ลื่น'},
  ],
  'weather_notes_th': asks
      ? <String>[]
      : ['ฝนตกกระจาย 23–33° โอกาสฝน 60%', 'โอกาสฝน 60% หินเปียกจะลื่น'],
  if (!asks)
    'forecast': {
      'day': '2026-10-03T00:00:00+07:00',
      'max_c': 33,
      'min_c': 23,
      'feels_max_c': 38,
      'feels_min_c': 25,
      'rain_prob_pct': 60,
    },
  if (!asks) 'place_th': 'หินเหล็กไฟ',
  if (asks) 'ask_th': 'ไปปีนผาที่ไหน วันไหน?',
  if (asks) 'suggestions_th': ['หินเหล็กไฟ ราชบุรี', 'ไร่เลย์ กระบี่'],
  'generated_by': 'gemini',
};

Map<String, dynamic> _decision() =>
    (jsonDecode(File('assets/fixtures/decide_car.json').readAsStringSync())
          as Map<String, dynamic>)
      ..['activity'] = _plan(asks: false);

void main() {
  test('an activity answer without a verdict asks where', () {
    final d = Decision.fromJson({'activity': _plan()});
    expect(d.asksWhere, isTrue);
    expect(d.activity!.checklist.first.itemTh, 'รองเท้าปีนผา');
    expect(d.activity!.suggestionsTh, hasLength(2));
    final at = Decision.fromJson(_decision());
    expect(at.asksWhere, isFalse);
    expect(at.activity!.forecast!.rainProbPct, 60);
    expect(at.activity!.activity.day, '2026-10-03');
  });

  test('the days offered are today, tomorrow and the coming weekend', () {
    final days = activityDays(DateTime.parse(_clock));
    expect(days.map((d) => d.toUtc().add(const Duration(hours: 7)).day), [
      29,
      30,
      3,
      4,
    ]);
  });

  testWidgets('climbing: a checklist and "where?", then the trip there '
      'with that day\'s weather', (tester) async {
    final log = <String>[];
    await pumpApp(
      tester,
      _clock,
      height: 2400,
      decideLog: log,
      respond: (req) {
        if (req.url.path == '/v1/decide') {
          return jsonResponse(
            req.body.contains('"destination"')
                ? _decision()
                : {'activity': _plan()},
          );
        }
        if (req.url.path == '/v1/places/search') {
          return jsonResponse({
            'places': [
              {
                'name_th': 'หินเหล็กไฟ',
                'address_th': 'ราชบุรี',
                'lat': 13.65,
                'lng': 99.53,
                'source': 'geocoder',
              },
            ],
          });
        }
        return null;
      },
    );

    await tapAndSettle(tester, find.byTooltip('ถามเส้นทาง'));
    await tester.enterText(
      find.byType(TextField).first,
      'ไปปีนผาต้องเตรียมอะไรบ้าง',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);

    expect(find.byType(ActivityAskPass), findsOneWidget);
    expect(find.text('Question unrelated to trip'), findsNothing);
    expect(find.text('รองเท้าปีนผา'), findsOneWidget);
    expect(find.text('ไปปีนผาที่ไหน วันไหน?'), findsOneWidget);

    await tapAndSettle(tester, find.text('รองเท้าปีนผา'));
    expect(find.text('1/2 ชิ้น'), findsOneWidget, reason: 'ticked off');

    await tapAndSettle(
      tester,
      find.byKey(const ValueKey('activity-day-2026-10-03')),
    );
    await tapAndSettle(
      tester,
      find.byKey(const ValueKey('activity-place-หินเหล็กไฟ ราชบุรี')),
    );
    await tapAndSettle(tester, find.text('หินเหล็กไฟ').last);

    final body = jsonDecode(log.last) as Map<String, dynamic>;
    expect(body['destination']['name_th'], 'หินเหล็กไฟ');
    expect(body['origin'], isNotNull);
    expect(body['depart_at'], '2026-10-03T07:00:00+07:00');
    expect(body['activity'], {
      'kind': 'climbing',
      'name_th': 'ปีนผา',
      'day': '2026-10-03',
    });

    expect(find.byType(ActivityAskPass), findsNothing);
    await reveal(tester, find.byKey(const ValueKey('activity-section')));
    expect(find.text('ฝนตกกระจาย 23–33° โอกาสฝน 60%'), findsOneWidget);
    expect(find.textContaining('หินเปียกจะลื่น'), findsOneWidget);
    expect(find.byKey(const ValueKey('gear-section')), findsNothing);
  });

  testWidgets('in the chat, the answer to "where?" carries the activity', (
    tester,
  ) async {
    final log = <String>[];
    await pumpApp(
      tester,
      _clock,
      height: 1600,
      decideLog: log,
      respond: (req) =>
          req.url.path == '/v1/decide' && req.body.contains('question_th')
          ? jsonResponse({'activity': _plan()})
          : null,
    );
    await openHero(tester);
    await tapAndSettle(tester, find.text('ถามต่อ'));
    await tester.enterText(
      find.byType(TextField).last,
      'ไปปีนผาต้องเตรียมอะไร',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(find.byType(ActivityAskPass), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'หินเหล็กไฟ เสาร์นี้');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    final body = jsonDecode(log.last) as Map<String, dynamic>;
    expect(body['question_th'], 'หินเหล็กไฟ เสาร์นี้');
    expect(body['activity']['kind'], 'climbing');
  });

  testWidgets('an answer the app cannot read is an error, not an empty pass', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _clock,
      height: 1600,
      respond: (req) => req.url.path == '/v1/decide'
          ? jsonResponse({'something_new': true})
          : null,
    );
    await tapAndSettle(tester, find.byTooltip('ถามเส้นทาง'));
    await tester.enterText(find.byType(TextField).first, 'ไปตั้งแคมป์');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);

    expect(find.text('ยังตัดสินไม่ได้'), findsOneWidget);
    expect(find.text('เทียบวิธีเดินทาง'), findsNothing);
  });
}
