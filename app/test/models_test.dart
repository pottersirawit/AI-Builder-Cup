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
    expect(trips, hasLength(13));
    final dinner = trips.first;
    expect(dinner.id, 'cal-dinner');
    expect(dinner.source, 'calendar');
    expect(dinner.destination.nameTh, 'บ้านลาดพร้าว');
    expect(dinner.origin.lat, closeTo(13.7263, 1e-6));
    expect(hhmm(dinner.arriveBy!), '18:30');
    expect(dinner.mode, TravelMode.car);
    expect(trips[1].source, 'gmail');
    expect(trips.where((t) => t.unresolved).single.id, 'cal-dentist');
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
    expect(d.modeOptions.first.viaTh, ['พระราม 4', 'อโศก', 'รัชดาภิเษก']);
    final transit = d.modeOptions.firstWhere(
      (o) => o.mode == TravelMode.transit,
    );
    expect(transit.viaTh, ['MRT สีลม', 'MRT สุขุมวิท', 'MRT ลาดพร้าว']);
    expect(transit.transitLegs, hasLength(1));
    expect(transit.transitLegs.first.lineTh, 'MRT สายสีน้ำเงิน');
    expect(transit.transitLegs.first.fromStationTh, 'MRT สีลม');
    expect(transit.transitLegs.first.toStationTh, 'MRT ลาดพร้าว');
    expect(transit.transitLegs.first.stopCount, 11);
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
    expect(d.refused, isFalse);
  });

  test('decision parses refused true when request was blocked by guardrails', () {
    final json = {
      'verdict': 'wait',
      'headline_th': 'คำถามไม่เกี่ยวข้องกับทริป',
      'summary_th': 'ขออภัยด้วยครับ มิวสามารถช่วยตอบได้เฉพาะเรื่องการเดินทาง',
      'confidence': 0.0,
      'rain_timeline': <Map<String, dynamic>>[],
      'mode_options': <Map<String, dynamic>>[],
      'flood_spots': <Map<String, dynamic>>[],
      'reasoning': <Map<String, dynamic>>[],
      'sources': ['Fontokmai Trip Guardrail'],
      'generated_by': 'fallback',
      'refused': true,
    };
    final d = Decision.fromJson(json);
    expect(d.refused, isTrue);
    expect(d.summaryTh, contains('ขออภัยด้วยครับ'));
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

  test('a flood report says whether Gemini analysed the photo', () {
    final base = {
      'id': 'r1',
      'depth_cm_min': 20,
      'depth_cm_max': 25,
      'confidence': 0.8,
      'description_th': '',
      'passable': {'car': 'slow'},
      'notified_users': 3,
      'corroborating_reports': 0,
    };
    expect(
      FloodReport.fromJson({
        ...base,
        'generated_by': 'gemini',
      }).analysedByGemini,
      isTrue,
    );
    expect(
      FloodReport.fromJson({
        ...base,
        'generated_by': 'fallback',
      }).analysedByGemini,
      isFalse,
    );
    expect(FloodReport.fromJson(base).analysedByGemini, isFalse);
    expect(
      FloodReport.fromJson({...base, 'generated_by': 'rejected'}).rejected,
      isTrue,
    );
  });

  group('real Calendar and Gmail events', () {
    Json trip(Map<String, Object?> extra) => {
      'id': 'x',
      'title_th': 'นัด',
      'source': 'calendar',
      'origin': {'name_th': 'บ้าน', 'lat': 13.8, 'lng': 100.5},
      'arrive_by': '2026-09-30T11:00:00+07:00',
      'mode': 'transit',
      ...extra,
    };

    test('reads the end time, online and all-day flags', () {
      final t = Trip.fromJson(
        trip({
          'destination': {'name_th': 'ออนไลน์'},
          'ends_at': '2026-09-30T11:30:00+07:00',
          'virtual': true,
        }),
      );
      expect(hhmm(t.endsAt!), '11:30');
      expect(t.virtual, isTrue);
      expect(t.unresolved, isFalse, reason: 'online needs no place');
      expect(t.travels, isFalse);
      expect(
        Trip.fromJson(trip({'all_day': true, 'destination': {'name_th': 'วันหยุด'}})).travels,
        isFalse,
      );

      final allDayResolved = Trip.fromJson(
        trip({
          'all_day': true,
          'destination': {'name_th': 'ไบเทค บางนา', 'lat': 13.67, 'lng': 100.61},
        }),
      );
      expect(allDayResolved.allDay, isTrue);
      expect(allDayResolved.destination.resolved, isTrue);
      expect(allDayResolved.hasDestination, isTrue);
      expect(allDayResolved.unresolved, isFalse);
      expect(allDayResolved.travels, isFalse);

      final allDayUnresolved = Trip.fromJson(
        trip({
          'all_day': true,
          'location_text_th': 'เกาะร้าง',
          'destination': {'name_th': 'เกาะร้าง', 'lat': 0, 'lng': 0},
        }),
      );
      expect(allDayUnresolved.allDay, isTrue);
      expect(allDayUnresolved.destination.resolved, isFalse);
      expect(allDayUnresolved.hasDestination, isTrue);
      expect(allDayUnresolved.unresolved, isTrue);
      expect(allDayUnresolved.locationTextTh, 'เกาะร้าง');

      final allDayNoLocation = Trip.fromJson(
        trip({
          'all_day': true,
          'destination': {'name_th': '', 'lat': 0, 'lng': 0},
        }),
      );
      expect(allDayNoLocation.allDay, isTrue);
      expect(allDayNoLocation.destination.resolved, isFalse);
      expect(allDayNoLocation.hasDestination, isFalse);
      expect(allDayNoLocation.unresolved, isFalse);
      expect(allDayNoLocation.locationTextTh, isNull);
    });

    test('an unplaced event stays unplaced through the device cache', () {
      final t = Trip.fromJson(
        trip({'location_text_th': 'คลินิกอารีย์', 'destination': {'name_th': 'คลินิกอารีย์'}}),
      );
      expect(t.unresolved, isTrue);
      final again = Trip.fromJson(t.toJson());
      expect(again.unresolved, isTrue, reason: 'not a trip to (0, 0)');
      expect(again.locationTextTh, 'คลินิกอารีย์');
    });

    test('round-trips the new fields', () {
      final t = Trip.fromJson(
        trip({
          'destination': {'name_th': 'สยาม', 'lat': 13.74, 'lng': 100.53},
          'ends_at': '2026-09-30T12:45:00+07:00',
        }),
      );
      final again = Trip.fromJson(t.toJson());
      expect(again.endsAt, t.endsAt);
      expect(again.travels, isTrue);
    });
  });
}
