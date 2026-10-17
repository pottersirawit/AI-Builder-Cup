import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/location.dart';

import 'helpers.dart';

const clock = '2026-09-29T16:10:00+07:00';

/// Opens the Ask sheet from the nav bar's round button.
Future<void> openAsk(WidgetTester tester) =>
    tapAndSettle(tester, find.byTooltip('ถามเส้นทาง'));

/// Types into the picker's search field and waits out the debounce.
Future<void> search(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).last, q);
  await settle(tester);
}

void main() {
  testWidgets('first launch shows the one optional onboarding screen', (
    tester,
  ) async {
    final store = await freshStore();
    await pumpApp(tester, clock, places: store);

    expect(find.text('ให้แอปเตือนก่อนกลับบ้าน'), findsOneWidget);
    expect(
      find.text('ใช้ตำแหน่งตอนนี้'),
      findsNWidgets(2),
      reason: 'บ้าน and ที่ทำงาน rows',
    );
    expect(find.text('ค้นหา'), findsNWidgets(2));
    expect(find.text('เริ่มใช้'), findsOneWidget);
    expect(find.text('ใช้โปรไฟล์เดโม (มิว)'), findsOneWidget);

    await tapAndSettle(tester, find.text('ใช้โปรไฟล์เดโม (มิว)'));
    expect(find.text('ควรออกก่อน'), findsOneWidget);
    expect(
      find.text('เดโม'),
      findsOneWidget,
      reason: 'demo badge in the header',
    );
  });

  testWidgets('skip leads to a summary that asks for the calendar first', (
    tester,
  ) async {
    final store = await freshStore();
    await pumpApp(tester, clock, places: store);
    await tapAndSettle(tester, find.text('ข้ามไปก่อน'));

    expect(store.onboarded, isTrue);
    expect(find.text('เชื่อมปฏิทินก่อน'), findsOneWidget);
    expect(find.text('เชื่อม Google Calendar'), findsOneWidget);

    await tapAndSettle(tester, find.text('ถามเส้นทางเอง'));
    expect(find.text('อยากไปไหน'), findsOneWidget, reason: 'the ask sheet');
    expect(
      find.text('กลับบ้านตอนนี้'),
      findsNothing,
      reason: 'no home saved yet',
    );
    await tester.tapAt(const Offset(200, 40));
    await settle(tester);

    await tapAndSettle(tester, find.text('อีเวนต์'));
    expect(
      find.text('เชื่อมปฏิทินก่อน'),
      findsOneWidget,
      reason: 'events tab says the same',
    );
  });

  testWidgets('home is set from settings, with an offline search', (
    tester,
  ) async {
    final store = await emptyStore();
    await pumpApp(tester, clock, places: store);
    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    await tapAndSettle(tester, find.text('ตั้งบ้าน'));
    await search(tester, 'อารีย์');
    expect(find.text('BTS อารีย์'), findsOneWidget);
    expect(find.text('ค้นออนไลน์ไม่ได้ แสดงข้อมูลในเครื่อง'), findsOneWidget);
    await tapAndSettle(tester, find.text('BTS อารีย์'));
    expect(find.text('ยืนยันบ้าน'), findsOneWidget);
    await tapAndSettle(tester, find.text('บันทึก'));

    expect(store.home!.nameTh, 'BTS อารีย์');
  });

  testWidgets('search with no results offers tips and the GPS instead', (
    tester,
  ) async {
    await pumpApp(tester, clock, places: await emptyStore());
    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    await tapAndSettle(tester, find.text('ตั้งบ้าน'));
    await search(tester, 'ร้านที่ไม่มีจริง');
    expect(find.text('ไม่พบ “ร้านที่ไม่มีจริง”'), findsOneWidget);
    expect(
      find.textContaining('ลองพิมพ์ชื่อสถานี BTS หรือห้าง'),
      findsOneWidget,
    );
  });

  testWidgets(
    'asking "กลับบ้าน" with no home asks where, then re-runs the question',
    (tester) async {
      final log = <String>[];
      final store = await emptyStore();
      await pumpApp(tester, clock, places: store, decideLog: log);

      await openAsk(tester);
      await tester.enterText(find.byType(TextField).first, 'กลับบ้านตอนนี้');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(find.text('ยังไม่รู้ว่า บ้าน อยู่ไหน'), findsOneWidget);
      expect(log, isEmpty, reason: 'known without asking the server');

      await tapAndSettle(tester, find.text('ใช้ตำแหน่งตอนนี้'));
      expect(
        find.text('ยืนยันบ้าน'),
        findsOneWidget,
        reason: 'GPS fix, named offline',
      );
      await tapAndSettle(tester, find.text('บันทึก'));

      expect(store.home, isNotNull);
      expect(find.text('ยังไม่รู้ว่า บ้าน อยู่ไหน'), findsNothing);
      expect(log, hasLength(1));
      final body = jsonDecode(log.single) as Map<String, dynamic>;
      expect(body['question_th'], 'กลับบ้านตอนนี้');
      expect((body['places'] as List).single['kind'], 'home');
    },
  );

  testWidgets('a place the server cannot resolve offers its candidates', (
    tester,
  ) async {
    final log = <String>[];
    await pumpApp(
      tester,
      clock,
      places: await emptyStore(),
      decideLog: log,
      respond: (req) => req.url.path == '/v1/decide' && log.length == 1
          ? jsonResponse(
              jsonDecode(
                    File(
                      'assets/fixtures/decide_needs_place.json',
                    ).readAsStringSync(),
                  )
                  as Object,
            )
          : null,
    );

    await openAsk(tester);
    await tester.enterText(find.byType(TextField).first, 'ไปเซ็นทรัล');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(find.text('หมายถึงที่ไหน'), findsOneWidget);
    expect(find.text('ไม่ใช่ทั้งหมด · ค้นหาเอง'), findsOneWidget);

    await tapAndSettle(tester, find.text('เซ็นทรัล ลาดพร้าว'));
    expect(log, hasLength(2));
    final places =
        (jsonDecode(log.last) as Map<String, dynamic>)['places'] as List;
    expect(places.last['label_th'], 'เซ็นทรัล');
    expect(places.last['name_th'], 'เซ็นทรัล ลาดพร้าว');
  });

  testWidgets(
    'location denied forever: explain, open settings, or search instead',
    (tester) async {
      await pumpApp(
        tester,
        clock,
        places: await freshStore(),
        locator: const StagedLocator(LocateStatus.deniedForever),
      );
      await tapAndSettle(tester, find.text('ใช้ตำแหน่งตอนนี้').first);

      expect(find.text('ไม่ได้รับสิทธิ์ตำแหน่ง'), findsOneWidget);
      expect(find.text('เปิดการตั้งค่า'), findsOneWidget);
      await tapAndSettle(tester, find.text('ค้นหาแทน'));
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'search field focused',
      );
    },
  );

  testWidgets(
    'first location use explains before the OS prompt, and never loops it',
    (tester) async {
      final store = await freshStore();
      await pumpApp(
        tester,
        clock,
        places: store,
        locator: const StagedLocator(LocateStatus.notAsked),
      );
      await tapAndSettle(tester, find.text('ใช้ตำแหน่งตอนนี้').first);

      expect(find.text('ขอใช้ตำแหน่งครั้งนี้'), findsOneWidget);
      await tapAndSettle(tester, find.text('อนุญาตตำแหน่ง'));
      expect(store.locationAsked, isTrue);
      expect(find.text('ไม่ได้รับสิทธิ์ตำแหน่ง'), findsOneWidget);
    },
  );

  testWidgets('settings lists real places; deleting home offers undo', (
    tester,
  ) async {
    final store = await demoStore();
    await pumpApp(tester, clock, places: store);
    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));

    expect(find.text('บ้านลาดพร้าว'), findsOneWidget);
    expect(find.textContaining('จ–ศ ออก 18:00'), findsOneWidget);
    await tapAndSettle(tester, find.text('บ้านลาดพร้าว'));
    await tapAndSettle(tester, find.text('ลบบ้าน'));
    expect(store.home, isNull);
    expect(find.text('ตั้งบ้าน'), findsOneWidget);

    await tester.tap(find.text('เลิกทำ'));
    await settle(tester);
    expect(store.home?.nameTh, 'บ้านลาดพร้าว');
  });
}
