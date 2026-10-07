import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> pumpApp(WidgetTester tester, String clock) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final state = AppState(demoClock: clock);
  final api = FonTokMaiApi(
    baseUrl: 'http://offline.test',
    demoClock: () => state.demoClock,
    client: MockClient((_) => throw http.ClientException('offline')),
    bundle: _DiskBundle(),
  );
  await tester.pumpWidget(FonTokMaiApp(state: state, api: api, useGoogleFonts: false));
  await settle(tester);
}

/// Serves assets straight from disk so fixture loads finish inside fake async.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Scrolls the visible list until [f] is built; lists build lazily.
Future<void> reveal(WidgetTester tester, Finder f) async {
  final list = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .last;
  for (final dy in [-200.0, 200.0]) {
    for (var i = 0; i < 15 && f.evaluate().isEmpty; i++) {
      await tester.drag(list, Offset(0, dy));
      await tester.pump();
    }
  }
  await tester.ensureVisible(f);
  await tester.pump();
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await settle(tester);
}

void main() {
  testWidgets('Home renders the verdict headline from fixtures when offline', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');

    expect(find.text('สวัสดีพลอย'), findsOneWidget);
    expect(find.text('ออกก่อน 16:45'), findsOneWidget);
    expect(find.text('มั่นใจ 78%'), findsOneWidget);
    expect(find.text('ข้อมูลตัวอย่าง'), findsOneWidget);
    // Simulated 16:10 push banner.
    expect(find.text('ออกก่อน 16:45 · กินข้าวเย็นกับที่บ้าน'), findsOneWidget);
  });

  testWidgets('21:40 demo clock shows the flood alert on Home', (tester) async {
    await pumpApp(tester, '2026-09-29T21:40:00+07:00');

    expect(find.text('21:40'), findsOneWidget);
    expect(find.text('น้ำจะถึงหน้าบ้านใน 40 นาที'), findsWidgets);
  });

  testWidgets('verdict detail shows reasoning and reacts to the mode toggle', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    await tapAndSettle(tester, find.text('ดูเหตุผล / เลื่อนเวลา'));

    expect(find.text('ออกก่อน 16:45'), findsOneWidget);

    await tapAndSettle(tester, find.text('BTS / MRT'));
    expect(find.text('ไปได้เลย'), findsOneWidget);

    await reveal(tester, find.text('Gemini คิดแบบนี้'));
    expect(find.text('get_route'), findsOneWidget);
  });

  testWidgets('ask, report, flood and settings screens open without errors', (tester) async {
    await pumpApp(tester, '2026-09-29T16:10:00+07:00');

    await tapAndSettle(tester, find.text('ถามต่อ').first);
    await tapAndSettle(tester, find.text('ถ้ารอถึงสองทุ่มค่อยกลับล่ะ'));
    expect(find.text('ออกสองทุ่มได้ แต่เลยนัด'), findsOneWidget);
    await tapAndSettle(tester, find.text('‹ กลับ'));

    await tapAndSettle(tester, find.text('📷 เจอน้ำท่วม? ถ่ายรูปบอกเพื่อนร่วมทาง'));
    expect(find.text('ถ่ายรูป'), findsOneWidget);
    await tapAndSettle(tester, find.text('‹ กลับ'));

    await tapAndSettle(tester, find.text('คืนนี้เสี่ยงน้ำท่วม: ปานกลาง'));
    expect(find.text('โหมดน้ำท่วม'), findsOneWidget);
    await tapAndSettle(tester, find.text('‹ กลับ'));

    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    expect(find.text('Google Calendar'), findsOneWidget);
  });
}
