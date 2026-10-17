import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/l10n/app_localizations_en.dart';
import 'package:fontokmai/l10n/app_localizations_th.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/location.dart';
import 'package:fontokmai/models.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers.dart';

const _reason = 'ออกก่อน 16:45 จะถึงบ้านก่อนฝนหนักบนพระราม 4';
const _factors = ['ฝนบนพระราม 4 เริ่มราว 17:30', 'แยกรัชดา-ลาดพร้าว ยังแห้ง'];
const _advice = 'ถ้าออกช้า ให้เลี่ยงรัชดาแล้วขึ้นทางด่วนแทน';

Map<String, dynamic> _decideWithExplanation() {
  final j =
      jsonDecode(File('assets/fixtures/decide_car.json').readAsStringSync())
          as Map<String, dynamic>;
  return j
    ..['explanation'] = {
      'reason_why_th': _reason,
      'factors_th': _factors,
      'route_advice_th': _advice,
      'avoid_spots_th': ['แยกรัชดา-ลาดพร้าว'],
    };
}

/// A GPS that never answers, like a phone indoors with no fix.
class _HangingLocator extends Locator {
  const _HangingLocator();
  @override
  Future<LocateResult> locate({
    required bool prompt,
    bool askedBefore = false,
  }) => Completer<LocateResult>().future;
}

void main() {
  group('verdict explanation', () {
    Future<void> openVerdict(WidgetTester tester, {double height = 874}) async {
      await pumpApp(
        tester,
        '2026-09-29T16:10:00+07:00',
        height: height,
        respond: (req) => req.url.path == '/v1/decide'
            ? jsonResponse(_decideWithExplanation())
            : null,
      );
      await openHero(tester);
    }

    testWidgets(
      'the reason comes right after the answer, before the mode comparison',
      (tester) async {
        // Tall enough that both sections are built at once.
        await openVerdict(tester, height: 2400);

        expect(find.text(_reason), findsOneWidget);
        expect(find.text(_advice), findsOneWidget);
        expect(find.text('เลี่ยง แยกรัชดา-ลาดพร้าว'), findsOneWidget);
        expect(find.byType(RiskChip), findsWidgets);
        expect(
          tester.getTopLeft(find.text('ทำไมถึงแนะนำแบบนี้')).dy,
          lessThan(tester.getTopLeft(find.text('เทียบวิธีเดินทาง')).dy),
        );
      },
    );

    testWidgets('factors stay folded until asked for', (tester) async {
      await openVerdict(tester);

      expect(find.text(_factors.first), findsNothing);
      await tapAndSettle(tester, find.text('ดูปัจจัยที่ใช้ตัดสิน (2)'));
      expect(find.text(_factors.first), findsOneWidget);
      expect(find.text(_factors.last), findsOneWidget);
      await tapAndSettle(tester, find.text('ซ่อนปัจจัย'));
      expect(find.text(_factors.first), findsNothing);
    });

    testWidgets(
      'the explanation names its real sources, not data the app does not have',
      (tester) async {
        await openVerdict(tester);

        await reveal(tester, find.text('ทำไมถึงแนะนำแบบนี้'));
        expect(
          find.textContaining('ข้อมูลระบายน้ำ'),
          findsNothing,
          reason: 'BMA drainage data has no public API',
        );
      },
    );

    testWidgets(
      'renders calculated route section with corridors, transit line, and get-on/get-off stations',
      (tester) async {
        await openVerdict(tester, height: 2400);
        await tapAndSettle(tester, find.text('รถยนต์'));

        expect(find.text('เส้นทางที่ใช้คำนวณ'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('เทียบวิธีเดินทาง')).dy,
          lessThan(tester.getTopLeft(find.text('เส้นทางที่ใช้คำนวณ')).dy),
        );
        await reveal(tester, find.text('จุดน้ำท่วมบนเส้นทาง'));
        expect(
          tester.getTopLeft(find.text('เส้นทางที่ใช้คำนวณ')).dy,
          lessThan(tester.getTopLeft(find.text('จุดน้ำท่วมบนเส้นทาง')).dy),
        );
        expect(find.text('พระราม 4'), findsWidgets);
        expect(find.text('อโศก'), findsWidgets);
        expect(find.text('รัชดาภิเษก'), findsWidgets);
        expect(find.text('MRT สายสีน้ำเงิน'), findsOneWidget);
        expect(find.textContaining('MRT สีลม'), findsWidgets);
        expect(find.textContaining('MRT ลาดพร้าว'), findsWidgets);
      },
    );

    testWidgets(
      'synced calendar trip replaces hardcoded Silom Soi 3 origin with saved home address',
      (tester) async {
        final store = await emptyStore();
        store.save(
          const SavedPlace(
            id: 'home',
            kind: PlaceKind.home,
            labelTh: 'บ้าน',
            nameTh: 'BTS อารีย์',
            lat: 13.7797,
            lng: 100.5446,
          ),
        );
        store.calendarForTest = LinkState.connected;
        final log = <String>[];

        await pumpApp(
          tester,
          '2026-09-29T16:10:00+07:00',
          places: store,
          decideLog: log,
          respond: (req) {
            if (req.url.path == '/v1/trips') {
              return jsonResponse({
                'trips': [
                  {
                    'id': 'cal-flight',
                    'title_th': 'Flight to Tokyo (XJ 606)',
                    'source': 'calendar',
                    'origin': {
                      'name_th': 'สีลม ซอย 3',
                      'lat': 13.7263,
                      'lng': 100.5293,
                    },
                    'destination': {
                      'name_th': 'Bangkok DMK',
                      'lat': 13.9126,
                      'lng': 100.6067,
                    },
                    'arrive_by': '2026-09-29T18:30:00+07:00',
                    'mode': 'car',
                  },
                ],
              });
            }
            return null;
          },
        );

        await tapAndSettle(tester, find.byKey(const ValueKey('hero-cal-flight')));
        expect(find.text('BTS อารีย์ → Bangkok DMK'), findsWidgets);
        expect(find.textContaining('สีลม ซอย 3'), findsNothing);
        expect(log, isNotEmpty);
        final sent = jsonDecode(log.last) as Map<String, dynamic>;
        expect((sent['origin'] as Map)['name_th'], 'BTS อารีย์');
      },
    );
  });

  group('current location', () {
    testWidgets('a slow GPS never holds back the verdict', (tester) async {
      await pumpApp(
        tester,
        '2026-09-29T16:10:00+07:00',
        locator: const _HangingLocator(),
      );

      expect(find.text('ควรออกก่อน'), findsOneWidget);
      expect(find.text('16:45'), findsOneWidget);
    });

    testWidgets('a coarse fix says how far off it may be, in plain units', (
      tester,
    ) async {
      await pumpApp(
        tester,
        '2026-09-29T16:10:00+07:00',
        locator: const StagedLocator(LocateStatus.ok, accuracyM: 1500),
      );

      await reveal(tester, find.text('ตำแหน่งอาจคลาดเคลื่อน ~1.5 กม.'));
      expect(find.text('ตำแหน่งอาจคลาดเคลื่อน ~1.5 กม.'), findsOneWidget);
      expect(find.text('ปักหมุดเอง'), findsOneWidget);
    });
  });

  test('approxDistance rounds like a person would say it', () {
    final th = AppLocalizationsTh();
    expect(approxDistance(th, 234), '~230 ม.');
    expect(approxDistance(th, 850), '~850 ม.');
    expect(approxDistance(th, 1000), '~1 กม.');
    expect(approxDistance(th, 1500), '~1.5 กม.');
    expect(approxDistance(th, 12400), '~12 กม.');
    expect(approxDistance(AppLocalizationsEn(), 1500), '~1.5 km');
  });
}
