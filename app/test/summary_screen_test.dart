import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/l10n/l10n.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/screens/event_cards.dart';
import 'package:fontokmai/screens/plan_cards.dart';
import 'package:fontokmai/screens/summary_screen.dart';
import 'package:fontokmai/screens/weather_cards.dart';

import 'helpers.dart';

void main() {
  testWidgets('the summary is the day\'s plan, with weather kept small', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T13:10:00+07:00', height: 2400);

    expect(find.text('วันนี้อีก 3 นัด'), findsOneWidget);
    expect(find.text('ประชุมลูกค้า Q4'), findsOneWidget, reason: 'the hero');
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.byKey(const ValueKey('next-cal-dinner')), findsOneWidget);
    expect(find.byKey(const ValueKey('next-cal-gym')), findsOneWidget);
    expect(find.text('ภาพรวมวันนี้'), findsOneWidget);
    expect(find.text('ต้องรู้ก่อนออก'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('alert-wetReturn-cal-gym')),
      findsOneWidget,
      reason: 'heavy rain at 21:30 on the way back from the gym',
    );
    expect(find.text('พกไปด้วย'), findsOneWidget);
    expect(find.byType(WeatherPeek), findsOneWidget);
    expect(find.byType(WeatherHeroCard), findsNothing, reason: 'on tap only');
    expect(find.byType(CrystalBackdrop), findsOneWidget);

    await tapAndSettle(tester, find.byType(WeatherPeek));
    expect(find.byType(WeatherHeroCard), findsOneWidget);
    expect(find.text('10 สูงมาก'), findsOneWidget, reason: 'UV in the sheet');
  });

  testWidgets('tomorrow: an online meeting and a hop that cannot be made', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-30T08:00:00+07:00', height: 2400);

    expect(
      find.byKey(const ValueKey('alert-shortConnection-cal-review')),
      findsOneWidget,
      reason: 'lunch at Siam ends 12:45, review at Thonglor starts 13:00',
    );
    expect(find.text('ไป รีวิวงานที่ทองหล่อ ไม่ทัน'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('alert-needsPlace-cal-dentist')),
      findsOneWidget,
    );
    expect(find.text('ออนไลน์ · ไม่ต้องเดินทาง'), findsOneWidget);
    expect(
      find.text('Daily standup ที่ออฟฟิศ'),
      findsOneWidget,
      reason: 'hero',
    );
  });

  testWidgets('a hot afternoon before a storm: bring rain gear', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', height: 2400);
    expect(find.text('ต้องออกใน'), findsOneWidget, reason: 'countdown ring');
    expect(find.text('35'), findsOneWidget, reason: '16:10 to 16:45');
    for (final kind in ['raincoat', 'umbrella']) {
      expect(find.byKey(ValueKey('bring-$kind')), findsOneWidget);
    }
  });

  testWidgets('then the next event and when to leave for it', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', height: 2400);

    expect(find.text('กินข้าวเย็นกับที่บ้าน'), findsOneWidget);
    expect(find.text('อีก 2 ชม. 20 นาที'), findsOneWidget);
    expect(find.text('ควรออกก่อน'), findsOneWidget);
    expect(find.text('16:45'), findsOneWidget);
    expect(find.text('BTS / MRT'), findsOneWidget, reason: 'best-ranked mode');
    expect(find.text('17:25'), findsOneWidget, reason: '16:45 + 40 min');
    expect(find.text('ข้อมูลตัวอย่าง'), findsWidgets);
    expect(find.byType(GlassNavBar), findsOneWidget);
  });

  testWidgets('waiting past the event start says how late you would be', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T17:40:00+07:00', height: 2400);

    expect(find.text('ออกได้ตอน'), findsOneWidget);
    expect(find.text('19:15'), findsOneWidget);
    expect(find.text('ถึงหลังเวลานัด 1 ชม. 35 นาที'), findsOneWidget);
  });

  testWidgets('the hero opens the detail, where the rain band still drags', (
    tester,
  ) async {
    final log = <String>[];
    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      decideLog: log,
      height: 1600,
    );
    await openHero(tester);
    expect(
      find.text('ไปได้เลย'),
      findsWidgets,
      reason: 'opens on BTS, the hero\'s mode',
    );
    await tapAndSettle(tester, find.text('รถยนต์'));
    expect(find.text('ออกก่อน 16:45'), findsOneWidget);

    final band = find.byKey(const ValueKey('rain-band'));
    await reveal(tester, band);
    expect(bubbleText(tester), 'ออก 16:10');
    final rect = tester.getRect(band);
    double xAt(int minutesAfter16) =>
        rect.left + rect.width * minutesAfter16 / 300;
    final y = rect.top + 60;
    final gesture = await tester.startGesture(Offset(xAt(10), y));
    for (var m = 20; m <= 100; m += 10) {
      await gesture.moveTo(Offset(xAt(m), y));
      await tester.pump();
    }
    expect(bubbleText(tester), 'ออก 17:40');
    final calls = log.length;
    await gesture.up();
    await settle(tester);
    expect(log.length, calls + 1);
    expect(log.last, contains('"depart_at":"2026-09-29T17:40:00+07:00"'));
    expect(find.text('อย่าเพิ่งออก'), findsOneWidget);
  });

  testWidgets('verdict detail shows reasoning and reacts to the mode toggle', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    await openHero(tester);

    await tapAndSettle(tester, find.text('รถไฟฟ้า'));
    await reveal(tester, find.text('ไปได้เลย'));
    expect(find.text('ไปได้เลย'), findsOneWidget);
    await reveal(tester, find.text('หาเส้นทาง'));
    expect(find.text('เหตุผลที่แนะนำแบบนี้'), findsOneWidget);
    expect(find.text('AI วิเคราะห์ให้'), findsWidgets);
  });

  testWidgets('the events tab lists everything coming up by day', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    await tapAndSettle(tester, find.text('อีเวนต์'));

    expect(find.text('วันนี้'), findsWidgets, reason: 'chip and header');
    expect(find.text('29 ก.ย.'), findsOneWidget);
    expect(find.text('ส 3 ต.ค.'), findsOneWidget, reason: 'filter chip');
    expect(
      find.text('กันยายน 2026'),
      findsNothing,
      reason: 'calendar on demand',
    );
    expect(
      find.text('ออก 16:45 · BTS / MRT'),
      findsOneWidget,
      reason: 'the hero decision is reused for today',
    );
    await reveal(tester, find.byKey(const ValueKey('event-gmail-concert')));
    expect(find.text('ตั๋วคอนเสิร์ต อิมแพ็ค'), findsOneWidget);

    await tapAndSettle(
      tester,
      find.byKey(const ValueKey('event-gmail-concert')),
    );
    expect(find.text('ถึงก่อน 19:00'), findsOneWidget);
    await reveal(tester, find.text('เทียบวิธีเดินทาง'));
    expect(find.text('เทียบวิธีเดินทาง'), findsOneWidget);
  });

  testWidgets('21:40 switches the whole app to flood mode', (tester) async {
    await pumpApp(tester, '2026-09-29T21:40:00+07:00');

    expect(find.text('น้ำท่วมใกล้บ้าน'), findsOneWidget);
    expect(find.textContaining('น้ำจะถึงหน้าบ้านใน'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('น้ำท่วมใกล้บ้าน'))).brightness,
      Brightness.dark,
    );

    await tapAndSettle(tester, find.text('ดูสิ่งที่ต้องทำ'));
    expect(
      find.text('ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.'),
      findsOneWidget,
    );
  });

  testWidgets('ask, settings and design gallery open without errors', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');

    await tapAndSettle(tester, find.byTooltip('ถามเส้นทาง'));
    expect(find.text('อยากไปไหน'), findsOneWidget);
    await tapAndSettle(tester, find.text('กลับบ้านตอนนี้'));
    expect(find.byType(RainBand), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('กลับ'));

    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    expect(find.text('บ้านลาดพร้าว'), findsOneWidget);
    await reveal(tester, find.text('Google Calendar'));
    expect(find.text('Google Calendar'), findsOneWidget);
    await tapAndSettle(tester, find.text('ระบบดีไซน์'));
    expect(find.text('พื้นท้องฟ้า'), findsOneWidget);
  });

  testWidgets('both tabs fit at 2x text without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');

    Future<void> scrollThrough() async {
      final list = find.byType(Scrollable).hitTestable().first;
      for (var i = 0; i < 25; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }

    expect(find.byKey(const ValueKey('hero-cal-dinner')), findsOneWidget);
    await scrollThrough();
    await tapAndSettle(tester, find.byTooltip('อีเวนต์'));
    await scrollThrough();
  });

  testWidgets('while loading, the whole page is a skeleton that fades out', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-29T13:10:00+07:00',
      height: 2400,
      latency: (_) => const Duration(seconds: 4),
    );

    expect(find.byKey(const ValueKey('summary-skeleton')), findsOneWidget);
    expect(find.byKey(const ValueKey('skeleton-up-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('skeleton-weather')), findsOneWidget);
    expect(find.byType(UpNextCard), findsNothing);
    expect(find.byType(WeatherPeek), findsNothing);
    expect(find.text('วันนี้ไม่มีนัดแล้ว'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(LargeTitleHeader),
      findsOneWidget,
      reason: 'the title stays put while the page fades in under it',
    );
    double shown(String text) => find
        .text(text)
        .evaluate()
        .map(
          (e) => tester
              .widgetList<FadeTransition>(
                find.ancestor(
                  of: find.byWidget(e.widget),
                  matching: find.byType(FadeTransition),
                ),
              )
              .fold(1.0, (o, f) => o * f.opacity.value),
        )
        .fold(0.0, (a, b) => a + b);
    expect(
      shown('สรุป') == 0 || shown('วันนี้อีก 3 นัด') == 0,
      isTrue,
      reason: 'the old title fades out before the new one fades in',
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('summary-skeleton')), findsNothing);
    expect(find.byType(UpNextCard), findsWidgets);
    expect(find.byType(WeatherPeek), findsOneWidget);
    expect(find.text('วันนี้อีก 3 นัด'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the hero keeps its height when the answer lands', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
      latency: (req) => req.url.path == '/v1/decide'
          ? const Duration(seconds: 4)
          : Duration.zero,
    );
    final hero = find.byKey(const ValueKey('hero-cal-dinner'));
    expect(find.text('16:45'), findsNothing, reason: 'still deciding');
    final pending = tester.getSize(hero).height;

    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.text('16:45'), findsOneWidget);
    expect(tester.getSize(hero).height, closeTo(pending, 6));
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('a real account whose events fail keeps the weather', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-29T13:10:00+07:00',
      height: 2400,
      places: (await emptyStore())..connectGoogle('owner@example.com'),
      respond: (req) => req.url.path == '/v1/outlook'
          ? jsonResponse(
              jsonDecode(
                File('assets/fixtures/outlook.json').readAsStringSync(),
              ),
            )
          : null,
    );

    expect(find.text('โหลดอีเวนต์ไม่ได้'), findsOneWidget);
    expect(find.text('วันนี้ไม่มีนัดแล้ว'), findsNothing);
    expect(find.byType(WeatherPeek), findsOneWidget);
  });

  testWidgets('a real account whose plan fails never shows มิว\'s reasoning', (
    tester,
  ) async {
    Map<String, Object> trip(String id, String title, String at) => {
      'id': id,
      'title_th': title,
      'source': 'calendar',
      'origin': {'name_th': 'Condo Ari', 'lat': 13.7797, 'lng': 100.5446},
      'destination': {
        'name_th': 'Samyan Mitrtown',
        'lat': 13.7337,
        'lng': 100.5288,
      },
      'arrive_by': at,
      'mode': 'car',
    };
    await pumpApp(
      tester,
      '2026-09-30T08:00:00+07:00',
      height: 2400,
      places: (await emptyStore())..connectGoogle('owner.real@gmail.com'),
      respond: (req) => switch (req.url.path) {
        '/v1/decide' => http.Response('decide failed', 502),
        final p when p.startsWith('/v1/trips') => jsonResponse({
          'trips': [
            trip(
              'cal-team',
              'AI Cup team meeting',
              '2026-09-30T10:00:00+07:00',
            ),
            trip(
              'cal-lunch',
              'Lunch with the team',
              '2026-09-30T12:00:00+07:00',
            ),
          ],
        }),
        _ => null,
      },
    );

    expect(find.text('AI Cup team meeting'), findsWidgets);
    expect(find.text('ยังคำนวณเวลาออกไม่ได้'), findsOneWidget);
    expect(find.textContaining('พระราม 4'), findsNothing);
    expect(find.textContaining('18:30'), findsNothing);
    expect(find.byType(SampleBadge), findsNothing);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('an online meeting left today is not "nothing else today"', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-30T10:00:00+07:00',
      height: 2400,
      places: (await emptyStore())..connectGoogle('owner@example.com'),
      respond: (req) => req.url.path.startsWith('/v1/trips')
          ? jsonResponse({
              'trips': [
                {
                  'id': 'cal-sync',
                  'title_th': 'Team sync',
                  'source': 'calendar',
                  'origin': {'name_th': 'Home', 'lat': 13.72, 'lng': 100.53},
                  'destination': {'name_th': 'Online'},
                  'arrive_by': '2026-09-30T11:00:00+07:00',
                  'ends_at': '2026-09-30T11:30:00+07:00',
                  'mode': 'transit',
                  'virtual': true,
                },
              ],
            })
          : null,
    );

    expect(find.text('Team sync'), findsWidgets);
    expect(find.text('วันนี้ไม่มีนัดแล้ว'), findsNothing);
    expect(find.text('วันนี้อีก 1 นัด'), findsOneWidget);
  });

  testWidgets('the events tab loads as the tickets it will show', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      latency: (_) => const Duration(seconds: 10),
    );
    await tapAndSettle(tester, find.text('อีเวนต์'));

    final skeleton = find.byKey(const ValueKey('events-skeleton'));
    expect(skeleton, findsOneWidget);
    expect(
      find.descendant(of: skeleton, matching: find.byType(GlassTicket)),
      findsNWidgets(3),
    );

    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    expect(find.byKey(const ValueKey('events-skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('event-cal-dinner')), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('an event ticket keeps its height when its leave time lands', (
    tester,
  ) async {
    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      height: 2400,
      latency: (req) => req.url.path == '/v1/decide'
          ? const Duration(seconds: 10)
          : Duration.zero,
    );
    await tapAndSettle(tester, find.text('อีเวนต์'));
    final ticket = find.byKey(const ValueKey('event-cal-gym'));
    final leave = find.descendant(
      of: ticket,
      matching: find.textContaining('ออก '),
    );
    expect(leave, findsNothing, reason: 'still deciding');
    final pending = tester.getSize(ticket).height;

    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(leave, findsOneWidget);
    expect(tester.getSize(ticket).height, pending);
  });

  testWidgets('summary screen header has a refresh button that calls sync', (
    tester,
  ) async {
    var syncCalled = 0;
    await pumpApp(
      tester,
      '2026-09-29T13:10:00+07:00',
      respond: (req) {
        if (req.url.path == '/v1/trips/sync') {
          syncCalled++;
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );

    final refreshBtn = find.byTooltip('รีเฟรช');
    expect(refreshBtn, findsOneWidget);
    await tapAndSettle(tester, refreshBtn);
    expect(syncCalled, greaterThanOrEqualTo(1));
  });

  testWidgets('shell triggers sync on resume when calendar is connected', (
    tester,
  ) async {
    var syncCount = 0;
    await pumpApp(
      tester,
      '2026-09-30T08:00:00+07:00',
      places: (await emptyStore())..connectGoogle('owner.real@gmail.com'),
      respond: (req) {
        if (req.url.path == '/v1/trips/sync') {
          syncCount++;
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );

    final before = syncCount;
    await tester.pump(const Duration(seconds: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(syncCount, greaterThan(before));
  });

  testWidgets('all-day events with resolved venue can be opened into VerdictScreen', (
    tester,
  ) async {
    final allDayTrip = {
      'id': 'cal-allday-bitec',
      'title_th': 'งานสถาปนิก 2026',
      'source': 'calendar',
      'origin': {'name_th': 'บ้าน', 'lat': 13.72, 'lng': 100.52},
      'destination': {'name_th': 'ไบเทค บางนา', 'lat': 13.67, 'lng': 100.61},
      'arrive_by': '2026-09-30T00:00:00+07:00',
      'ends_at': '2026-10-01T00:00:00+07:00',
      'mode': 'car',
      'all_day': true,
    };
    final allDayHoliday = {
      'id': 'cal-holiday',
      'title_th': 'วันหยุดประจำปี',
      'source': 'calendar',
      'origin': {'name_th': 'บ้าน', 'lat': 13.72, 'lng': 100.52},
      'destination': {'name_th': '', 'lat': 0, 'lng': 0},
      'arrive_by': '2026-09-30T00:00:00+07:00',
      'ends_at': '2026-10-01T00:00:00+07:00',
      'mode': 'car',
      'all_day': true,
    };

    await pumpApp(
      tester,
      '2026-09-30T08:00:00+07:00',
      respond: (req) {
        if (req.url.path == '/v1/trips' || req.url.path == '/v1/trips/sync') {
          return jsonResponse({'trips': [allDayTrip, allDayHoliday]});
        }
        return null;
      },
    );

    await tapAndSettle(tester, find.text('อีเวนต์'));
    expect(find.text('งานสถาปนิก 2026'), findsOneWidget);
    expect(find.text('ไบเทค บางนา'), findsOneWidget);
    expect(find.text('วันหยุดประจำปี'), findsOneWidget);

    // Tap on the all-day event with location: opens verdict screen
    await tapAndSettle(tester, find.byKey(const ValueKey('event-cal-allday-bitec')));
    expect(find.text('งานสถาปนิก 2026'), findsWidgets);
  });

  testWidgets('days with multiple events base next event on previous event location and allow switching origin', (
    tester,
  ) async {
    final dentistTrip = {
      'id': 'cal-dentist',
      'title_th': 'ทำฟัน',
      'source': 'calendar',
      'origin': {'name_th': 'บ้าน', 'lat': 13.72, 'lng': 100.52},
      'destination': {'name_th': 'โรงพยาบาลธนบุรี', 'lat': 13.75, 'lng': 100.48},
      'arrive_by': '2026-09-30T10:00:00+07:00',
      'ends_at': '2026-09-30T11:30:00+07:00',
      'mode': 'car',
    };
    final dinnerTrip = {
      'id': 'cal-dinner',
      'title_th': 'ดินเนอร์',
      'source': 'calendar',
      'origin': {'name_th': 'สีลม', 'lat': 13.7279, 'lng': 100.5281},
      'destination': {'name_th': 'ร้านอาหารสยาม', 'lat': 13.74, 'lng': 100.53},
      'arrive_by': '2026-09-30T18:00:00+07:00',
      'ends_at': '2026-09-30T20:00:00+07:00',
      'mode': 'car',
    };

    final decideRequests = <Map<String, dynamic>>[];

    await pumpApp(
      tester,
      '2026-09-30T08:00:00+07:00',
      respond: (req) {
        if (req.url.path == '/v1/trips' || req.url.path == '/v1/trips/sync') {
          return jsonResponse({'trips': [dentistTrip, dinnerTrip]});
        }
        if (req.url.path == '/v1/decide') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          decideRequests.add(body);
          final origin = body['origin'] as Map<String, dynamic>?;
          final originName = origin?['name_th'] ?? 'ต้นทาง';
          return jsonResponse({
            'verdict': 'leave_now',
            'headline_th': 'ออกได้เลย',
            'summary_th': 'จาก $originName ไป ร้านอาหารสยาม',
            'trip': {
              'id': body['trip_id'] ?? 'cal-dinner',
              'title_th': 'ดินเนอร์',
              'source': 'calendar',
              'origin': origin ?? {'name_th': 'โรงพยาบาลธนบุรี', 'lat': 13.75, 'lng': 100.48},
              'destination': {'name_th': 'ร้านอาหารสยาม', 'lat': 13.74, 'lng': 100.53},
              'mode': 'car',
            },
            'mode_options': [
              {
                'mode': 'car',
                'verdict': 'leave_now',
                'risk': 'low',
                'eta_min': 25,
                'via_th': [originName, 'ถนนพระราม 1', 'ร้านอาหารสยาม'],
              }
            ],
            'reasoning': [],
            'flood_spots': [],
            'rain_timeline': [],
            'confidence': 0.9,
          });
        }
        return null;
      },
    );

    // Go to Events tab
    await tapAndSettle(tester, find.text('อีเวนต์'));
    expect(find.text('ทำฟัน'), findsOneWidget);
    expect(find.text('ดินเนอร์'), findsOneWidget);

    // Tap on dinner event
    await tapAndSettle(tester, find.byKey(const ValueKey('event-cal-dinner')));

    // VerdictScreen should show route starting from โรงพยาบาลธนบุรี (Dentist event)
    expect(find.textContaining('โรงพยาบาลธนบุรี → ร้านอาหารสยาม'), findsWidgets);
    expect(find.text('เปลี่ยนจุดเริ่มต้น'), findsWidgets);

    // Tap "เปลี่ยนจุดเริ่มต้น" to open the Origin Picker bottom sheet
    await tapAndSettle(tester, find.text('เปลี่ยนจุดเริ่มต้น').first);

    // Bottom sheet is displayed with options
    expect(find.text('เลือกจุดเริ่มต้นการเดินทาง'), findsOneWidget);
    expect(find.text('งานก่อนหน้า · ทำฟัน'), findsOneWidget);
    expect(find.text('บ้าน'), findsWidgets);

    // Switch starting point to "บ้าน" (Home)
    await tapAndSettle(tester, find.text('บ้าน').first);

    // Should recalculate with home origin
    expect(find.textContaining('บ้าน → ร้านอาหารสยาม'), findsWidgets);
  });

  test('summaryHeaderTitle produces context-aware titles based on next event day', () {
    final lEn = lookupAppLocalizations(const Locale('en'));
    final lTh = lookupAppLocalizations(const Locale('th'));
    final now = DateTime.parse('2026-10-17T15:00:00+07:00');
    final todayTrip = Trip(
      id: 'today-trip',
      titleTh: 'นัดวันนี้',
      source: 'calendar',
      mode: TravelMode.car,
      origin: const Place(nameTh: 'บ้าน', lat: 13.8, lng: 100.5),
      destination: const Place(nameTh: 'ที่ทำงาน', lat: 13.7, lng: 100.5),
      arriveBy: DateTime.parse('2026-10-17T18:00:00+07:00'),
    );
    final tomorrowTrip = Trip(
      id: 'tomorrow-trip',
      titleTh: 'นัดพรุ่งนี้',
      source: 'calendar',
      mode: TravelMode.car,
      origin: const Place(nameTh: 'บ้าน', lat: 13.8, lng: 100.5),
      destination: const Place(nameTh: 'บางนา', lat: 13.6, lng: 100.6),
      arriveBy: DateTime.parse('2026-10-18T13:30:00+07:00'),
    );
    final futureTrip = Trip(
      id: 'future-trip',
      titleTh: 'นัดสัปดาห์หน้า',
      source: 'calendar',
      mode: TravelMode.car,
      origin: const Place(nameTh: 'บ้าน', lat: 13.8, lng: 100.5),
      destination: const Place(nameTh: 'สยาม', lat: 13.7, lng: 100.5),
      arriveBy: DateTime.parse('2026-10-21T10:00:00+07:00'),
    );

    // Case 1: Next event is tomorrow and no events left today
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: tomorrowTrip,
        now: now,
      ),
      "Tomorrow's plan",
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: tomorrowTrip,
        now: now,
      ),
      'นัดหมายพรุ่งนี้',
    );

    // Case 2: Next travel event is tomorrow, but there is 1 non-travel/online event today
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 1,
        next: tomorrowTrip,
        now: now,
      ),
      'Next trip tomorrow',
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 1,
        next: tomorrowTrip,
        now: now,
      ),
      'เดินทางพรุ่งนี้',
    );

    // Case 3: Next event is 2+ days away
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: futureTrip,
        now: now,
      ),
      'Upcoming trip',
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: futureTrip,
        now: now,
      ),
      'นัดหมายถัดไป',
    );

    // Case 4: Next event is today (1 left)
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 1,
        next: todayTrip,
        now: now,
      ),
      '1 more today',
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 1,
        next: todayTrip,
        now: now,
      ),
      'วันนี้อีก 1 นัด',
    );

    // Case 5: Next event is today (2+ left)
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 2,
        next: todayTrip,
        now: now,
      ),
      '2 more today',
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 2,
        next: todayTrip,
        now: now,
      ),
      'วันนี้อีก 2 นัด',
    );

    // Case 6: No events left today and no next event
    expect(
      summaryHeaderTitle(
        l: lEn,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: null,
        now: now,
      ),
      'Nothing else today',
    );
    expect(
      summaryHeaderTitle(
        l: lTh,
        connected: true,
        pending: false,
        todayLeft: 0,
        next: null,
        now: now,
      ),
      'วันนี้ไม่มีนัดแล้ว',
    );
  });
}


