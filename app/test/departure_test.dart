import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/departure.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/time_th.dart';

Decision decision(String name) => Decision.fromJson(
    jsonDecode(File('assets/fixtures/$name.json').readAsStringSync()) as Json);

DateTime bkk(String hhmm) => DateTime.parse('2026-09-29T$hhmm:00+07:00');

void main() {
  final calm = decision('decide_car');

  test('rainAt reads the 15-minute bucket that contains the time', () {
    expect(rainAt(calm.rainTimeline, bkk('18:20')), 16.5);
    expect(rainAt(calm.rainTimeline, bkk('16:05')), 0);
    expect(rainAt(calm.rainTimeline, bkk('23:00')), 0);
  });

  test('peakRain covers every bucket the trip overlaps', () {
    expect(peakRain(calm.rainTimeline, bkk('16:10'), bkk('17:00')), 0.1);
    expect(peakRain(calm.rainTimeline, bkk('16:10'), bkk('17:05')), 0.3);
    expect(peakRain(calm.rainTimeline, bkk('17:40'), bkk('18:20')), 16.5);
  });

  test('preview before the storm keeps every mode open', () {
    final options = previewOptions(calm, bkk('16:15'));
    expect(options.map((o) => o.verdict).toSet(), {Verdict.leaveNow});
    final car = options.firstWhere((o) => o.mode == TravelMode.car);
    expect(hhmm(car.arriveAt), '17:05');
    expect(car.isPreview, isTrue);
  });

  test('preview inside the storm holds the car, stops the motorbike, keeps BTS', () {
    final options = previewOptions(calm, bkk('17:45'));
    Verdict of(TravelMode m) => options.firstWhere((o) => o.mode == m).verdict;
    expect(of(TravelMode.car), Verdict.wait);
    expect(of(TravelMode.moto), Verdict.dontGo);
    expect(of(TravelMode.transit), Verdict.leaveNow);
    final car = options.firstWhere((o) => o.mode == TravelMode.car);
    expect(car.etaMin, greaterThan(50));
  });

  test('the notes say what the rain is, not what it might have been', () {
    String note(String hhmm, TravelMode m) =>
        previewOptions(calm, bkk(hhmm)).firstWhere((o) => o.mode == m).noteTh;
    expect(
      note('17:00', TravelMode.transit),
      'ฝนตกช่วงเดินไปสถานี',
      reason: '5.4 mm/h on the way is not "no rain"',
    );
    expect(note('20:15', TravelMode.car), 'ไม่โดนฝนระหว่างทาง',
        reason: 'the storm is over: nothing to beat');
    expect(note('20:15', TravelMode.moto), 'ไม่โดนฝนระหว่างทาง');
    expect(note('16:15', TravelMode.car), 'ถึงก่อนฝน',
        reason: 'rain starts within the hour after arriving');
  });

  test('ranking puts the open, low-risk, earliest arrival first', () {
    final ranked = rankOptions(previewOptions(calm, bkk('17:45')));
    expect(ranked.first.mode, TravelMode.transit);
    expect(ranked.last.mode, TravelMode.moto);

    final calmRank = rankOptions(previewOptions(calm, bkk('16:15')));
    expect(calmRank.first.mode, TravelMode.transit);
    expect(calmRank.last.mode, TravelMode.moto, reason: 'medium risk sorts after low risk');
  });

  test('preview headline re-letters with the departure', () {
    expect(previewHeadline(previewOptions(calm, bkk('16:30')), TravelMode.car), 'ออก 16:30 ได้');
    expect(previewHeadline(previewOptions(calm, bkk('17:45')), TravelMode.car), 'อย่าเพิ่งออก');
    expect(previewHeadline(previewOptions(calm, bkk('17:45')), TravelMode.moto), 'เปลี่ยนเป็น BTS ดีกว่า');
  });

  test('server options become departures without the preview flag', () {
    final storm = decision('decide_car_storm');
    final options = serverOptions(storm, bkk('18:52'));
    expect(options, hasLength(3));
    expect(options.every((o) => !o.isPreview), isTrue);
    expect(options.firstWhere((o) => o.mode == TravelMode.car).etaMin, 95);
  });

  test('sky state follows the trip, and flood at home overrides it', () {
    expect(skyFor(calm.rainTimeline, bkk('16:10'), 50), SkyState.clear);
    expect(skyFor(calm.rainTimeline, bkk('17:45'), 50), SkyState.storm);
    expect(skyFor(calm.rainTimeline, bkk('16:10'), 50, verdict: Verdict.wait), SkyState.storm);
    expect(skyFor(calm.rainTimeline, bkk('16:10'), 50, home: HomeLevel.danger), SkyState.flood);
  });

  test('snapDeparture rounds to five minutes inside the band', () {
    final start = bkk('16:10');
    final end = bkk('20:45');
    expect(hhmm(snapDeparture(bkk('17:32'), start, end)), '17:30');
    expect(hhmm(snapDeparture(bkk('15:00'), start, end)), '16:10');
    expect(hhmm(snapDeparture(bkk('22:00'), start, end)), '20:45');
  });

  test('peakRainProb reads the maximum probability in the window', () {
    final rain = [
      RainPoint(bkk('16:00'), 0, 20),
      RainPoint(bkk('16:15'), 0, 70),
      RainPoint(bkk('16:30'), 0, 40),
    ];
    expect(peakRainProb(rain, bkk('16:00'), bkk('16:10')), 20);
    expect(peakRainProb(rain, bkk('16:00'), bkk('16:30')), 70);
  });

  test('preview with high rain probability (>=60%) elevates motorcycle to medium risk with rain gear advice', () {
    final rain = [
      RainPoint(bkk('16:00'), 0, 75),
      RainPoint(bkk('16:15'), 0, 75),
      RainPoint(bkk('16:30'), 0, 75),
    ];
    final d = Decision(
      verdict: Verdict.leaveNow,
      leaveBy: bkk('17:00'),
      headlineTh: 'ออกได้เลย',
      summaryTh: 'ไม่มีฝน',
      confidence: 0.9,
      rainTimeline: rain,
      floodSpots: const [],
      reasoning: const [],
      sources: const [],
      generatedBy: 'deterministic',
      modeOptions: [
        const ModeOption(
          mode: TravelMode.car,
          verdict: Verdict.leaveNow,
          etaMin: 50,
          risk: Risk.low,
          noteTh: 'ไม่เจอฝน',
          rainProbPct: 75,
        ),
        const ModeOption(
          mode: TravelMode.transit,
          verdict: Verdict.leaveNow,
          etaMin: 45,
          risk: Risk.low,
          noteTh: 'ขบวนไม่กระทบ',
          rainProbPct: 75,
        ),
        const ModeOption(
          mode: TravelMode.moto,
          verdict: Verdict.leaveNow,
          etaMin: 25,
          risk: Risk.medium,
          noteTh: 'โอกาสฝนตก 75% ควรเตรียมเสื้อกันฝน',
          rainProbPct: 75,
        ),
      ],
    );
    final options = previewOptions(d, bkk('16:00'));
    final car = options.firstWhere((o) => o.mode == TravelMode.car);
    final moto = options.firstWhere((o) => o.mode == TravelMode.moto);
    expect(car.risk, Risk.low);
    expect(car.rainProbPct, 75);
    expect(moto.risk, Risk.medium);
    expect(moto.rainProbPct, 75);
    expect(moto.noteTh, contains('เสื้อกันฝน'));
  });
}
