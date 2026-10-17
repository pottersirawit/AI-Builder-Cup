import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clock = '2026-09-29T16:10:00+07:00';

  test(
    'decide posts the contract body with X-Demo-Clock and parses the reply',
    () async {
      late http.Request sent;
      final api = FonTokMaiApi(
        baseUrl: 'http://api.test',
        demoClock: () => clock,
        client: MockClient((req) async {
          sent = req;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'verdict': 'dont_go',
                'headline_th': 'อย่าออก',
                'confidence': 0.9,
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final r = await api.decide(
        const DecideRequest(tripId: 'cal-dinner', mode: TravelMode.transit),
      );

      expect(r.isSample, isFalse);
      expect(r.data.verdict, Verdict.dontGo);
      expect(r.data.headlineTh, 'อย่าออก');
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://api.test/v1/decide');
      expect(sent.headers['X-Demo-Clock'], clock);
      expect(jsonDecode(sent.body), {
        'trip_id': 'cal-dinner',
        'mode': 'transit',
      });
    },
  );

  test(
    'falls back to bundled fixtures when the backend is unreachable',
    () async {
      final api = FonTokMaiApi(
        baseUrl: 'http://api.test',
        client: MockClient(
          (_) => throw http.ClientException('connection refused'),
        ),
      );

      final trips = await api.trips();
      expect(trips.isSample, isTrue);
      expect(trips.data.first.id, 'cal-dinner');

      final d = await api.decide(const DecideRequest(tripId: 'cal-dinner'));
      expect(d.isSample, isTrue);
      expect(d.data.headlineTh, 'ออกก่อน 16:45');
    },
  );

  test(
    'a real account\'s plan and weather never fall back to มิว\'s',
    () async {
      final api = FonTokMaiApi(
        baseUrl: 'http://api.test',
        allowSample: () => false,
        client: MockClient((_) async => http.Response('decide failed', 502)),
      );

      await expectLater(
        api.decide(const DecideRequest(tripId: 'cal-owner')),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        api.outlook(lat: 13.78, lng: 100.54),
        throwsA(isA<http.ClientException>()),
      );
    },
  );

  test('syncTrips sends the saved home as the trips\' origin', () async {
    late Uri sent;
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        sent = req.url;
        return http.Response('{"trips":[]}', 200);
      }),
    );

    await api.syncTrips(
      email: 'owner@example.com',
      sample: false,
      home: const SavedPlace(
        id: 'home',
        kind: PlaceKind.home,
        labelTh: 'บ้าน',
        nameTh: 'คอนโดอารีย์',
        lat: 13.7797,
        lng: 100.5446,
      ),
    );

    expect(sent.path, '/v1/trips/sync');
    expect(sent.queryParameters, {
      'email': 'owner@example.com',
      'home_lat': '13.7797',
      'home_lng': '100.5446',
      'home_name': 'คอนโดอารีย์',
    });

    await api.syncTrips(email: 'owner@example.com', sample: false);
    expect(sent.queryParameters, {'email': 'owner@example.com'});
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
    expect(
      pick(
        const DecideRequest(tripId: 'x', departAt: '2026-09-29T16:15:00+07:00'),
      ),
      'decide_car',
    );
    expect(
      pick(
        const DecideRequest(tripId: 'x', departAt: '2026-09-29T18:00:00+07:00'),
      ),
      'decide_car_storm',
    );
    expect(
      pick(
        const DecideRequest(
          tripId: 'x',
          departAt: '2026-09-29T18:00:00+07:00',
          mode: TravelMode.moto,
        ),
      ),
      'decide_moto_storm',
    );
    expect(
      pick(const DecideRequest(tripId: 'x', mode: TravelMode.transit)),
      'decide_transit',
    );
    expect(
      pick(const DecideRequest(questionTh: 'ไป BTS แทนดีไหม')),
      'decide_transit',
    );
    expect(
      pick(const DecideRequest(questionTh: 'ถ้ารอถึงสองทุ่มค่อยกลับล่ะ')),
      'decide_question',
    );
  });

  test('sample home status switches to danger at the 21:40 preset', () {
    expect(
      sampleHomeStatusName('2026-09-29T16:10:00+07:00'),
      'home_status_watch',
    );
    expect(
      sampleHomeStatusName('2026-09-29T21:40:00+07:00'),
      'home_status_danger',
    );
    expect(sampleHomeStatusName(null), 'home_status_watch');
  });

  test('outlook reads the contract and sends the place', () async {
    late http.Request sent;
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        sent = req;
        final hour = {
          'time': '2026-09-29T16:00:00+07:00',
          'temp_c': 33.4,
          'feels_like_c': 39.1,
          'uv_index': 7,
          'rain_prob_pct': 20,
          'rain_mm_per_hr': 0.0,
          'condition': 'PARTLY_CLOUDY',
          'condition_th': 'มีเมฆบางส่วน',
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'now': hour,
              'hours': [hour],
            }),
          ),
          200,
        );
      }),
    );

    final r = await api.outlook(lat: 13.81, lng: 100.59);

    expect(sent.url.path, '/v1/outlook');
    expect(sent.url.queryParameters, {'lat': '13.81', 'lng': '100.59'});
    expect(r.data.now.uvIndex, 7);
    expect(r.data.now.conditionTh, 'มีเมฆบางส่วน');
  });

  test('the sample outlook starts at the current hour, moved onto today', () {
    WeatherHour h(String t) => WeatherHour(
      time: DateTime.parse(t),
      tempC: 30,
      feelsLikeC: 33,
      uvIndex: 0,
      rainProbPct: 0,
      rainMmPerHr: 0,
    );
    final day = Outlook(
      now: h('2026-09-29T06:00:00+07:00'),
      hours: [
        for (var i = 6; i < 24; i++)
          h('2026-09-29T${i.toString().padLeft(2, '0')}:00:00+07:00'),
      ],
    );

    final o = sampleOutlook(day, DateTime.parse('2026-10-17T16:10:00+07:00'));

    expect(o.hours, hasLength(8), reason: '16:00 to 23:00');
    expect(o.now.time, DateTime.parse('2026-10-17T16:00:00+07:00'));
  });
}
