import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/config.dart';
import 'package:fontokmai/location.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/places.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Live Clock', () {
    test('initialDemoClock defaults to null (live time)', () {
      expect(initialDemoClock(), isNull);
    });

    test('AppState.now() returns current system time when demoClock is null', () {
      final state = AppState(demoClock: null);
      final before = DateTime.now();
      final now = state.now();
      final after = DateTime.now();

      expect(now.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(now.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('FonTokMaiApi omits X-Demo-Clock header in live mode', () async {
      late http.Request sent;
      final api = FonTokMaiApi(
        baseUrl: 'http://api.test',
        demoClock: () => null,
        client: MockClient((req) async {
          sent = req;
          return http.Response('{"trips":[]}', 200, headers: {'content-type': 'application/json'});
        }),
      );

      await api.trips();
      expect(sent.headers.containsKey('X-Demo-Clock'), isFalse);
    });
  });

  group('Current Location as Information Source', () {
    test('AppState tracks currentLocation', () {
      final state = AppState();
      expect(state.currentLocation, isNull);

      const loc = LocateResult(LocateStatus.ok, lat: 13.7563, lng: 100.5018, accuracyM: 15);
      state.currentLocation = loc;
      expect(state.currentLocation, equals(loc));
      expect(state.currentLocation!.ok, isTrue);
    });

    test('Decision incorporates GPS in sources when trip origin is from current location', () {
      final d = Decision.fromJson({
        'verdict': 'leave_now',
        'headline_th': 'ออกได้เลย',
        'summary_th': 'สภาพอากาศดี',
        'sources': ['Google Weather API', 'WeatherNext 3'],
        'trip': {
          'id': 'app-home',
          'title_th': 'กลับบ้าน',
          'source': 'app',
          'origin': {'name_th': 'ตำแหน่งตอนนี้', 'lat': 13.7563, 'lng': 100.5018},
          'destination': {'name_th': 'บ้าน', 'lat': 13.8160, 'lng': 100.5900},
          'mode': 'car',
        },
      });

      expect(d.sources, contains('GPS ตำแหน่งปัจจุบัน'));
      expect(d.sources.first, 'GPS ตำแหน่งปัจจุบัน');
    });

    test('Decision keeps existing sources when GPS is not the origin', () {
      final d = Decision.fromJson({
        'verdict': 'leave_now',
        'headline_th': 'ออกได้เลย',
        'summary_th': 'สภาพอากาศดี',
        'sources': ['Google Weather API', 'WeatherNext 3'],
        'trip': {
          'id': 'cal-meeting',
          'title_th': 'ประชุม',
          'source': 'calendar',
          'origin': {'name_th': 'ออฟฟิศ', 'lat': 13.7263, 'lng': 100.5340},
          'destination': {'name_th': 'บ้าน', 'lat': 13.8160, 'lng': 100.5900},
          'mode': 'car',
        },
      });

      expect(d.sources, isNot(contains('GPS ตำแหน่งปัจจุบัน')));
      expect(d.sources, equals(['Google Weather API', 'WeatherNext 3']));
    });

    test('LocateResult flags lowAccuracy only when accuracy > 200m and not manual', () {
      const accurateGps = LocateResult(LocateStatus.ok, lat: 13.75, lng: 100.5, accuracyM: 25);
      expect(accurateGps.lowAccuracy, isFalse);

      const coarseGps = LocateResult(LocateStatus.ok, lat: 13.75, lng: 100.5, accuracyM: 850);
      expect(coarseGps.lowAccuracy, isTrue);

      const manualPin = LocateResult(
        LocateStatus.ok,
        lat: 13.7761,
        lng: 100.5074,
        nameTh: '29 ถนนสามเสน ดุสิต',
        isManual: true,
        accuracyM: 500,
      );
      expect(manualPin.lowAccuracy, isFalse, reason: 'manual calibration should never be low accuracy');
      expect(manualPin.nameTh, '29 ถนนสามเสน ดุสิต');
    });

    test('PlacesStore persists and clears manual calibrated location', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PlacesStore(prefs);

      expect(store.manualLocation, isNull);

      const pin = PlaceCandidate(
        nameTh: '29 ถนนสามเสน ดุสิต',
        addressTh: 'ถนนนครไชยศรี ดุสิต กทม.',
        lat: 13.7761,
        lng: 100.5074,
        source: 'manual',
      );
      store.setManualLocation(pin);

      expect(store.manualLocation, isNotNull);
      expect(store.manualLocation!.nameTh, '29 ถนนสามเสน ดุสิต');
      expect(store.manualLocation!.lat, 13.7761);
      expect(store.manualLocation!.lng, 100.5074);

      // Reloading from prefs
      final reloadedStore = PlacesStore(prefs);
      expect(reloadedStore.manualLocation, isNotNull);
      expect(reloadedStore.manualLocation!.nameTh, '29 ถนนสามเสน ดุสิต');
      expect(reloadedStore.manualLocation!.lat, 13.7761);

      // Clearing manual pin resets to GPS
      store.setManualLocation(null);
      expect(store.manualLocation, isNull);

      final clearedStore = PlacesStore(prefs);
      expect(clearedStore.manualLocation, isNull);
    });
  });
}
