import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<AppState> pumpApp(WidgetTester tester, String clock,
    {List<String>? decideLog, double height = 874}) async {
  tester.view.physicalSize = Size(402 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final state = AppState(demoClock: clock);
  final api = FonTokMaiApi(
    baseUrl: 'http://offline.test',
    demoClock: () => state.demoClock,
    client: MockClient((req) {
      if (req.url.path == '/v1/decide') decideLog?.add(req.body);
      throw http.ClientException('offline');
    }),
    bundle: _DiskBundle(),
  );
  await tester.pumpWidget(FonTokMaiApp(state: state, api: api));
  await settle(tester);
  return state;
}

/// Serves assets straight from disk so fixture loads finish inside fake async.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async => File(key).readAsStringSync();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Scrolls the visible vertical list until [f] is built; lists build lazily.
Future<void> reveal(WidgetTester tester, Finder f) async {
  final list = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .hitTestable()
      .first;
  for (final dy in [-250.0, 250.0]) {
    for (var i = 0; i < 15 && f.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(list, Offset(0, dy));
      await tester.pump();
    }
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f.hitTestable().first);
  await tester.pump();
  await settle(tester);
}

String bubbleText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: find.byKey(const ValueKey('rain-band-bubble')), matching: find.byType(Text)).first)
    .data!;

void main() {
  testWidgets('Home prints the top trip as a pass from fixtures when offline', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');

    expect(find.text('สวัสดีมิว'), findsOneWidget);
    expect(find.text('ออกก่อน 16:45'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('ข้อมูลตัวอย่าง'), findsWidgets);
    expect(find.text('ออกก่อน 16:45 · กินข้าวเย็นกับที่บ้าน'), findsOneWidget, reason: '16:10 push banner');
    expect(find.byType(RainBand), findsOneWidget);
    expect(Theme.of(tester.element(find.text('สวัสดีมิว'))).brightness, Brightness.light);
  });

  testWidgets('dragging the rain-band marker re-letters the verdict and reranks the board',
      (tester) async {
    final log = <String>[];
    // Tall enough that the board below the pass is built while dragging.
    await pumpApp(tester, '2026-09-29T16:10:00+07:00', decideLog: log, height: 1600);
    await tester.tap(find.byTooltip('ปิดแจ้งเตือน'));
    await tester.pump();

    final band = find.byKey(const ValueKey('rain-band'));
    await reveal(tester, band);
    expect(bubbleText(tester), 'ออก 16:10');

    final rect = tester.getRect(band);
    double xAt(int minutesAfter16) => rect.left + rect.width * minutesAfter16 / 300;
    final y = rect.top + 60;

    final gesture = await tester.startGesture(Offset(xAt(10), y));
    for (var m = 20; m <= 100; m += 10) {
      await gesture.moveTo(Offset(xAt(m), y));
      await tester.pump();
    }
    // Mid-drag: the on-device preview, before the agent is asked.
    expect(bubbleText(tester), 'ออก 17:40');
    expect(find.text('อย่าเพิ่งออก'), findsOneWidget);
    final boardTop = find.byKey(const ValueKey('mode-transit')).first;
    final carRow = find.byKey(const ValueKey('mode-car')).first;
    expect(tester.getTopLeft(boardTop).dy, lessThan(tester.getTopLeft(carRow).dy),
        reason: 'BTS outranks the car once the departure is inside the storm');
    final callsBeforeRelease = log.length;

    await gesture.up();
    await settle(tester);
    expect(log.length, callsBeforeRelease + 1);
    expect(log.last, contains('"depart_at":"2026-09-29T17:40:00+07:00"'));
    expect(find.text('อย่าเพิ่งออก'), findsOneWidget, reason: 'agent verdict for 17:40 (storm fixture)');
  });

  testWidgets('21:40 switches the whole app to flood mode', (tester) async {
    await pumpApp(tester, '2026-09-29T21:40:00+07:00');

    expect(find.textContaining('น้ำจะถึงหน้าบ้านใน'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('สวัสดีมิว'))).brightness, Brightness.dark);

    await tapAndSettle(tester, find.text('ดูสิ่งที่ต้องทำตอนนี้'));
    expect(find.text('โหมดน้ำท่วม'), findsOneWidget);
    expect(find.text('ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.'), findsOneWidget);
  });

  testWidgets('verdict detail shows reasoning and reacts to the mode toggle', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    await tester.tap(find.byTooltip('ปิดแจ้งเตือน'));
    await tester.pump();
    await tapAndSettle(tester, find.text('ดูเหตุผลและทางเลือก'));

    expect(find.text('ออกก่อน 16:45'), findsOneWidget);

    await tapAndSettle(tester, find.text('รถไฟฟ้า'));
    await reveal(tester, find.text('ไปได้เลย'));
    expect(find.text('ไปได้เลย'), findsOneWidget);

    await reveal(tester, find.text('get_route'));
    expect(find.text('Gemini คิดแบบนี้'), findsOneWidget);
    expect(find.text('ตัดสินโดย Gemini'), findsWidgets);
  });

  testWidgets('ask, report, home, settings and design gallery open without errors', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    await tester.tap(find.byTooltip('ปิดแจ้งเตือน'));
    await tester.pump();

    await tapAndSettle(tester, find.text('ถามต่อ'));
    await tapAndSettle(tester, find.text('ถ้ารอถึงสองทุ่มค่อยกลับล่ะ'));
    expect(find.text('ออกสองทุ่มได้ แต่เลยนัด'), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('กลับ'));

    await tapAndSettle(tester, find.text('แจ้งน้ำท่วม'));
    expect(find.text('ถ่ายรูป'), findsOneWidget);
    // No location plugin in tests: the service check times out to the fallback.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32'), findsOneWidget, reason: 'GPS fallback');

    await tapAndSettle(tester, find.text('บ้าน'));
    expect(find.text('คืนนี้เสี่ยงน้ำท่วม: ปานกลาง'), findsOneWidget);

    await tapAndSettle(tester, find.text('เดินทาง'));
    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    expect(find.text('Google Calendar'), findsOneWidget);
    await tapAndSettle(tester, find.text('ระบบดีไซน์'));
    expect(find.text('พื้นท้องฟ้า'), findsOneWidget);
    await tapAndSettle(tester, find.text('น้ำท่วม'));
    expect(find.text('พื้นท้องฟ้า'), findsOneWidget);
  });
}
