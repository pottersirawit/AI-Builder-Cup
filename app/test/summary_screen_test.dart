import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/screens/plan_cards.dart';
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
    expect(find.text('ไปรีวิวงานที่ทองหล่อไม่ทัน'), findsOneWidget);
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
    );

    expect(find.text('โหลดอีเวนต์ไม่ได้'), findsOneWidget);
    expect(find.text('วันนี้ไม่มีนัดแล้ว'), findsNothing);
    expect(find.byType(WeatherPeek), findsOneWidget);
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
}
