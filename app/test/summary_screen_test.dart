import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/screens/weather_cards.dart';
import 'package:fontokmai/screens/event_cards.dart';

import 'helpers.dart';

void main() {
  testWidgets('the summary is the day\'s plan, with weather kept small', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T13:10:00+07:00', height: 2400);

    expect(find.text('วันนี้อีก 3 นัด'), findsOneWidget);
    expect(find.text('ประชุมลูกค้า Q4'), findsOneWidget, reason: 'the hero');
    expect(find.text('แผนต่อจากนี้'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-cal-dinner')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-cal-gym')), findsOneWidget);
    expect(find.text('พกไปด้วย'), findsOneWidget);
    expect(find.byType(WeatherPeek), findsOneWidget);
    expect(find.byType(WeatherHeroCard), findsNothing, reason: 'on tap only');
    expect(find.byType(CrystalBackdrop), findsOneWidget);

    await tapAndSettle(tester, find.byType(WeatherPeek));
    expect(find.byType(WeatherHeroCard), findsOneWidget);
    expect(find.text('10 สูงมาก'), findsOneWidget, reason: 'UV in the sheet');
  });

  testWidgets('a hot afternoon before a storm: bring rain gear', (
    tester,
  ) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', height: 2400);
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
    expect(find.text('กันยายน 2026'), findsNothing, reason: 'calendar on demand');
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
}
