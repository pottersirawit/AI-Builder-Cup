import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clock = '2026-09-29T16:10:00+07:00';

  test('decide posts the contract body with X-Demo-Clock and parses the reply', () async {
    late http.Request sent;
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      demoClock: () => clock,
      client: MockClient((req) async {
        sent = req;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'verdict': 'dont_go', 'headline_th': 'อย่าออก', 'confidence': 0.9})),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final r = await api.decide(const DecideRequest(tripId: 'cal-dinner', mode: TravelMode.transit));

    expect(r.isSample, isFalse);
    expect(r.data.verdict, Verdict.dontGo);
    expect(r.data.headlineTh, 'อย่าออก');
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/v1/decide');
    expect(sent.headers['X-Demo-Clock'], clock);
    expect(jsonDecode(sent.body), {'trip_id': 'cal-dinner', 'mode': 'transit'});
  });

  test('falls back to bundled fixtures when the backend is unreachable', () async {
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) => throw http.ClientException('connection refused')),
    );

    final trips = await api.trips();
    expect(trips.isSample, isTrue);
    expect(trips.data.first.id, 'cal-dinner');

    final d = await api.decide(const DecideRequest(tripId: 'cal-dinner'));
    expect(d.isSample, isTrue);
    expect(d.data.headlineTh, 'ออกก่อน 16:45');
  });

  test('falls back on a server error too', () async {
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      demoClock: () => '2026-09-29T21:40:00+07:00',
      client: MockClient((_) async => http.Response('boom', 500)),
    );
    final s = await api.homeStatus();
    expect(s.isSample, isTrue);
    expect(s.data.level, HomeLevel.danger);
  });

  test('sample decision follows mode, departure time and question', () {
    String pick(DecideRequest r) => sampleDecisionName(r);
    expect(pick(const DecideRequest(tripId: 'x', departAt: '2026-09-29T16:15:00+07:00')), 'decide_car');
    expect(pick(const DecideRequest(tripId: 'x', departAt: '2026-09-29T18:00:00+07:00')), 'decide_car_storm');
    expect(
      pick(const DecideRequest(tripId: 'x', departAt: '2026-09-29T18:00:00+07:00', mode: TravelMode.moto)),
      'decide_moto_storm',
    );
    expect(pick(const DecideRequest(tripId: 'x', mode: TravelMode.transit)), 'decide_transit');
    expect(pick(const DecideRequest(questionTh: 'ไป BTS แทนดีไหม')), 'decide_transit');
    expect(pick(const DecideRequest(questionTh: 'ถ้ารอถึงสองทุ่มค่อยกลับล่ะ')), 'decide_question');
  });

  test('sample home status switches to danger at the 21:40 preset', () {
    expect(sampleHomeStatusName('2026-09-29T16:10:00+07:00'), 'home_status_watch');
    expect(sampleHomeStatusName('2026-09-29T21:40:00+07:00'), 'home_status_danger');
    expect(sampleHomeStatusName(null), 'home_status_watch');
  });
}
