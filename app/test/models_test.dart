import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/l10n/app_localizations_en.dart';
import 'package:fontokmai/l10n/app_localizations_th.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/time_th.dart';

Json fixture(String name) =>
    jsonDecode(File('assets/fixtures/$name.json').readAsStringSync()) as Json;

void main() {
  test('trips fixture parses calendar and gmail trips', () {
    final trips = Trip.listFromJson(fixture('trips'));
    expect(trips, hasLength(2));
    final dinner = trips.first;
    expect(dinner.id, 'cal-dinner');
    expect(dinner.source, 'calendar');
    expect(dinner.destination.nameTh, 'บ้านลาดพร้าว');
    expect(dinner.origin.lat, closeTo(13.7263, 1e-6));
    expect(hhmm(dinner.arriveBy!), '18:30');
    expect(dinner.mode, TravelMode.car);
    expect(trips[1].source, 'gmail');
  });

  test('car decision fixture parses every contract field', () {
    final d = Decision.fromJson(fixture('decide_car'));
    expect(d.verdict, Verdict.leaveNow);
    expect(d.headlineTh, 'ออกก่อน 16:45');
    expect(hhmm(d.leaveBy!), '16:45');
    expect(d.confidence, 0.78);
    expect(d.rainTimeline, hasLength(20));
    expect(
      d.rainTimeline.map((r) => r.mmPerHr).reduce((a, b) => a > b ? a : b),
      16.5,
    );
    expect(d.modeOptions.map((o) => o.mode), TravelMode.values);
    expect(d.modeOptions.last.risk, Risk.medium);
    expect(d.floodSpots.first.id, 'BKK-FL-012');
    expect(d.reasoning.first.tool, 'get_trip');
    expect(d.sources, contains('Google Weather API'));
    expect(d.generatedBy, 'gemini');
  });

  test('decision parses explanation with factors and route advice', () {
    final json = {
      'verdict': 'switch_mode',
      'headline_th': 'เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า',
      'summary_th': 'น้ำท่วม 25 ซม.',
      'confidence': 0.85,
      'rain_timeline': <Map<String, dynamic>>[],
      'mode_options': <Map<String, dynamic>>[],
      'flood_spots': <Map<String, dynamic>>[],
      'reasoning': <Map<String, dynamic>>[],
      'sources': ['BMA'],
      'generated_by': 'gemini',
      'explanation': {
        'reason_why_th': 'แยกรัชดาน้ำท่วม 25 ซม. เกินระยะพ้นน้ำรถเก๋ง',
        'factors_th': ['ระดับน้ำท่วม 25 ซม.', 'ฝนตกหนัก 35 มม./ชม.'],
        'route_advice_th': 'เลี่ยงถนนรัชดาภิเษก ใช้ทางด่วนหรือรถไฟฟ้าแทน',
        'avoid_spots_th': ['แยกรัชดาภิเษก-ลาดพร้าว'],
      },
    };
    final d = Decision.fromJson(json);
    expect(d.explanation, isNotNull);
    expect(d.explanation!.reasonWhyTh, contains('เกินระยะพ้นน้ำ'));
    expect(d.explanation!.factorsTh, hasLength(2));
    expect(d.explanation!.routeAdviceTh, contains('เลี่ยงถนนรัชดาภิเษก'));
    expect(d.explanation!.avoidSpotsTh, ['แยกรัชดาภิเษก-ลาดพร้าว']);
    expect(d.explanation!.isEmpty, isFalse);
  });

  test('every decision fixture parses with a known verdict', () {
    final verdicts = {
      'decide_car': Verdict.leaveNow,
      'decide_car_storm': Verdict.wait,
      'decide_transit': Verdict.leaveNow,
      'decide_moto': Verdict.leaveNow,
      'decide_moto_storm': Verdict.switchMode,
      'decide_question': Verdict.wait,
    };
    verdicts.forEach((name, verdict) {
      final d = Decision.fromJson(fixture(name));
      expect(d.verdict, verdict, reason: name);
      expect(d.headlineTh, isNotEmpty, reason: name);
      expect(d.reasoning, isNotEmpty, reason: name);
    });
  });

  test('report fixture parses depth, confidence and passability', () {
    final r = FloodReport.fromJson(fixture('report'));
    expect((r.depthCmMin, r.depthCmMax), (20, 25));
    expect(r.confidence, 0.84);
    expect(r.passable, {
      TravelMode.car: 'slow',
      TravelMode.transit: 'yes',
      TravelMode.moto: 'no',
    });
    expect(r.notifiedUsers, 27);
    expect(r.corroboratingReports, 2);
    expect(FloodReport.listFromJson(fixture('reports')), hasLength(1));
  });

  test('home status fixtures parse with ordered actions', () {
    final watch = HomeStatus.fromJson(fixture('home_status_watch'));
    expect(watch.level, HomeLevel.watch);
    expect(watch.canal!.fill, closeTo(1.4 / 1.8, 1e-9));

    final danger = HomeStatus.fromJson(fixture('home_status_danger'));
    expect(danger.level, HomeLevel.danger);
    expect(danger.headlineTh, 'น้ำจะถึงหน้าบ้านใน 40 นาที');
    expect(danger.canal!.fill, 1.0);
    expect(danger.actions.map((a) => a.order), [1, 2, 3]);
  });

  test('unknown enum values fall back instead of throwing', () {
    expect(Verdict.parse('maybe'), Verdict.wait);
    expect(TravelMode.parse(null), TravelMode.car);
    expect(HomeLevel.parse('x'), HomeLevel.normal);
  });

  test('DecideRequest only sends the fields that are set', () {
    expect(
      const DecideRequest(
        tripId: 'cal-dinner',
        departAt: '2026-09-29T16:15:00+07:00',
        mode: TravelMode.moto,
      ).toJson(),
      {
        'trip_id': 'cal-dinner',
        'depart_at': '2026-09-29T16:15:00+07:00',
        'mode': 'moto',
      },
    );
    expect(const DecideRequest(questionTh: 'ถ้ารอถึงสองทุ่ม').toJson(), {
      'question_th': 'ถ้ารอถึงสองทุ่ม',
    });
  });

  test('Bangkok time helpers ignore the device time zone', () {
    final t = DateTime.parse('2026-09-29T16:10:00+07:00');
    expect(hhmm(t), '16:10');
    expect(isoBangkok(t), '2026-09-29T16:10:00+07:00');
    expect(
      dayTime(
        AppLocalizationsTh(),
        DateTime.parse('2026-10-03T19:00:00+07:00'),
      ),
      'เสาร์ 3 ต.ค. 19:00',
    );
    expect(
      dayTime(
        AppLocalizationsEn(),
        DateTime.parse('2026-10-03T19:00:00+07:00'),
      ),
      'Sat 3 Oct 19:00',
    );
  });
}
