import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/places.dart';
import 'package:fontokmai/trip_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

SavedPlace place(String id, double lat, double lng, {PlaceKind kind = PlaceKind.other}) =>
    SavedPlace(id: id, kind: kind, labelTh: id, nameTh: id, lat: lat, lng: lng);

const siam = (lat: 13.7456, lng: 100.5341);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlacesStore', () {
    test('a place within 150 m is a duplicate; 300 m away is not', () async {
      final s = await freshStore();
      s.save(place('gym', siam.lat, siam.lng));
      expect(s.duplicateOf(siam.lat + 0.001, siam.lng)?.id, 'gym', reason: '~110 m north');
      expect(s.duplicateOf(siam.lat + 0.003, siam.lng), isNull, reason: '~330 m north');
      expect(s.duplicateOf(siam.lat, siam.lng, exceptId: 'gym'), isNull);
    });

    test('home and work in the same spot is working from home, not a duplicate', () async {
      final s = await freshStore();
      s.save(place('h', siam.lat, siam.lng, kind: PlaceKind.home));
      expect(s.duplicateOf(siam.lat, siam.lng, forKind: PlaceKind.work), isNull);
      s.save(place('w', siam.lat, siam.lng, kind: PlaceKind.work));
      expect(s.workFromHome, isTrue);
      expect(commuteFor(home: s.home, work: s.work, now: DateTime.parse('2026-09-29T16:10:00+07:00')), isNull);
    });

    test('one home, one work: a second home replaces the first', () async {
      final s = await freshStore();
      s.save(place('h1', 13.8, 100.5, kind: PlaceKind.home));
      s.save(place('h2', 13.7, 100.6, kind: PlaceKind.home));
      expect(s.places.where((p) => p.kind == PlaceKind.home), hasLength(1));
      expect(s.home!.id, 'h2');
    });

    test('up to 8 others; the 9th is refused', () async {
      final s = await freshStore();
      for (var i = 0; i < PlacesStore.maxOthers; i++) {
        expect(s.save(place('o$i', 13.7 + i * 0.01, 100.5)), isNull);
      }
      expect(s.canAddOther, isFalse);
      expect(s.save(place('o9', 13.6, 100.5)), SaveRefusal.tooManyOthers);
      expect(s.others, hasLength(8));
      expect(s.save(place('o0', 13.65, 100.5)), isNull, reason: 'editing an existing one still works');
    });

    test('Bangkok bounding box flags places outside it', () {
      expect(inServiceArea(siam.lat, siam.lng), isTrue);
      expect(inServiceArea(18.7883, 98.9853), isFalse, reason: 'Chiang Mai');
      expect(place('cm', 18.7883, 98.9853).inArea, isFalse);
    });

    test('places and profile flags survive a restart', () async {
      final s = await freshStore();
      s
        ..save(place('h', 13.8, 100.5, kind: PlaceKind.home)
            .copyWith(icon: 'home', addressTh: 'ซอย 1'))
        ..save(place('w', 13.72, 100.53, kind: PlaceKind.work).copyWith(days: [1, 3], leaveTime: '17:30'))
        ..completeOnboarding()
        ..markLocationAsked();
      final again = PlacesStore(await SharedPreferences.getInstance());
      expect(again.onboarded, isTrue);
      expect(again.locationAsked, isTrue);
      expect(again.home!.addressTh, 'ซอย 1');
      expect(again.work!.days, [1, 3]);
      expect(again.work!.leaveTime, '17:30');
    });

    test('delete then undo puts the place back where it was', () async {
      final s = await freshStore();
      s
        ..save(place('a', 13.7, 100.5))
        ..save(place('b', 13.75, 100.5))
        ..save(place('c', 13.8, 100.5));
      final removed = s.remove('b')!;
      expect(s.places.map((p) => p.id), ['a', 'c']);
      s.restore(removed.place, removed.index);
      expect(s.places.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('demo profile loads มิว and leaving it is a first run again', () async {
      final s = await freshStore();
      s.useDemoProfile();
      expect(s.demoProfile, isTrue);
      expect(s.home!.nameTh, 'บ้านลาดพร้าว');
      expect(s.calendar, LinkState.connected);
      s.resetToFirstRun();
      expect(s.places, isEmpty);
      expect(s.onboarded, isFalse);
      expect(s.calendar, LinkState.notConnected);
    });

    test('the stub connect works only in the demo profile', () async {
      final s = await freshStore();
      expect(s.canConnectCalendar, isFalse);
      await s.connectCalendar(delay: Duration.zero);
      expect(s.calendar, LinkState.notConnected);
      s
        ..useDemoProfile()
        ..disconnectCalendar();
      final f = s.connectCalendar(delay: Duration.zero);
      expect(s.calendar, LinkState.connecting);
      await f;
      expect(s.calendar, LinkState.connected);
    });

    test('a real profile has no account until Google names one', () async {
      final s = await freshStore();
      expect(s.calendarAccount, isNull);
      expect(s.gmailAccount, isNull);
    });

    test('Google connection and email survive page reload / store restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s1 = PlacesStore(prefs)..connectGoogle('owner.real@example.com');
      expect(s1.calendar, LinkState.connected);
      expect(s1.calendarAccount, 'owner.real@example.com');
      expect(s1.gmail, LinkState.connected);
      expect(s1.gmailAccount, 'owner.real@example.com');

      // Re-instantiate PlacesStore using the same preferences (browser refresh)
      final s2 = PlacesStore(prefs);
      expect(s2.calendar, LinkState.connected);
      expect(s2.calendarAccount, 'owner.real@example.com');
      expect(s2.gmail, LinkState.connected);
      expect(s2.gmailAccount, 'owner.real@example.com');

      // Disconnect clears saved state
      s2.disconnectCalendar();
      expect(s2.calendar, LinkState.notConnected);
      final s3 = PlacesStore(prefs);
      expect(s3.calendar, LinkState.notConnected);
      expect(s3.gmail, LinkState.connected);
    });

    test('a connect left half-way does not come back as connected', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      PlacesStore(prefs).beginGoogleConnect();
      final s = PlacesStore(prefs);
      expect(s.calendar, LinkState.notConnected);
      expect(s.gmail, LinkState.notConnected);
    });
  });

  group('commute', () {
    final home = demoPlaces[0];
    final work = demoPlaces[1];

    test('work day: from work at the usual leave time', () {
      final c = commuteFor(home: home, work: work, now: DateTime.parse('2026-09-29T16:10:00+07:00'))!;
      expect(c.trip.origin.nameTh, 'ที่ทำงาน');
      expect(c.trip.destination.lat, home.lat);
      expect(c.departAt, DateTime.parse('2026-09-29T18:00:00+07:00'));
      expect(c.fromCurrentLocation, isFalse);
    });

    test('weekend: no commute', () {
      expect(commuteFor(home: home, work: work, now: DateTime.parse('2026-10-03T16:10:00+07:00')), isNull);
    });

    test('home only: from wherever the phone is, at 18:00', () {
      final c = commuteFor(home: home, now: DateTime.parse('2026-09-29T16:10:00+07:00'))!;
      expect(c.fromCurrentLocation, isTrue);
      expect(c.departAt, DateTime.parse('2026-09-29T18:00:00+07:00'));
    });

    test('long after leave time: none; just after: leave now', () {
      expect(commuteFor(home: home, work: work, now: DateTime.parse('2026-09-29T23:30:00+07:00')), isNull);
      final now = DateTime.parse('2026-09-29T18:20:00+07:00');
      expect(commuteFor(home: home, work: work, now: now)!.departAt, now);
    });

    test('no home: nothing to go home to', () {
      expect(commuteFor(work: work, now: DateTime.parse('2026-09-29T16:10:00+07:00')), isNull);
    });
  });

  test('questions about an unsaved home or work are caught before asking', () {
    expect(missingPlaceFor('กลับบ้านตอนนี้'), PlaceKind.home);
    expect(missingPlaceFor('พรุ่งนี้ไปทำงานกี่โมงดี'), PlaceKind.work);
    expect(missingPlaceFor('กลับบ้านตอนนี้', home: demoPlaces[0]), isNull);
    expect(missingPlaceFor('ไปสยามตอนนี้'), isNull);
  });

  test('an answered "where?" rides along as a place labelled with the asked words', () {
    const needs = NeedsPlace(queryTh: 'เซ็นทรัล');
    const pick = Place(nameTh: 'เซ็นทรัลเวิลด์', lat: 13.7466, lng: 100.5393);
    final out = placesWithAnswer(needs, pick, demoPlaces);
    expect(out.last.labelTh, 'เซ็นทรัล');
    expect(out.last.toWire(), containsPair('kind', 'other'));
    expect(placesWithAnswer(const NeedsPlace(queryTh: 'บ้าน', kind: PlaceKind.home), pick, demoPlaces),
        same(demoPlaces));
  });

  group('wire', () {
    test('decide sends ad-hoc endpoints and the saved places', () {
      final body = DecideRequest(
        questionTh: 'ไปยิม',
        origin: const Place(nameTh: 'ตำแหน่งตอนนี้', lat: 13.7, lng: 100.5),
        destination: demoPlaces[0].asPlace,
        places: demoPlaces.take(1).toList(),
      ).toJson();
      expect(body['origin'], {'name_th': 'ตำแหน่งตอนนี้', 'lat': 13.7, 'lng': 100.5});
      expect(body['destination']['lat'], 13.816);
      expect(body['places'], [
        {'id': 'home', 'kind': 'home', 'label_th': 'บ้าน', 'name_th': 'บ้านลาดพร้าว', 'lat': 13.816, 'lng': 100.59},
      ]);
    });

    test('needs_place parses instead of a verdict', () {
      final d = Decision.fromJson({
        'needs_place': {
          'query_th': 'บ้าน',
          'kind': 'home',
          'candidates': [
            {'name_th': 'BTS อารีย์', 'name_en': 'BTS Ari', 'address_th': 'พญาไท', 'lat': 13.78, 'lng': 100.54, 'source': 'local'},
          ],
        },
      });
      expect(d.needsPlace!.kind, PlaceKind.home);
      expect(d.needsPlace!.candidates.single.nameEn, 'BTS Ari');
    });

    test('home-status without a canal, with nearby spots by distance', () {
      final s = HomeStatus.fromJson({
        'level': 'normal',
        'headline_th': 'x',
        'canal': null,
        'in_service_area': true,
        'rain_today_mm': 12.5,
        'flood_spots': [
          {'id': 'a', 'name_th': 'แยก', 'lat': 1, 'lng': 2, 'distance_m': 640, 'expected_depth_cm': 0, 'historical_max_depth_cm': 35},
        ],
      });
      expect(s.canal, isNull);
      expect(s.floodSpots.single.distanceM, 640);
      expect(s.floodSpots.single.risk, Risk.high);
    });

    test('a calendar trip whose place is unknown keeps its text', () {
      final t = Trip.fromJson({
        'id': 'cal-x',
        'title_th': 'ประชุม',
        'source': 'calendar',
        'origin': {'name_th': 'a', 'lat': 1, 'lng': 2},
        'destination': null,
        'location_text_th': 'ร้านป้าแดง',
      });
      expect(t.unresolved, isTrue);
      expect(t.locationTextTh, 'ร้านป้าแดง');
      expect(t.arriveBy, isNull);
    });
  });

  group('offline places', () {
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((_) => throw http.ClientException('offline')),
    );

    test('search falls back to bundled landmarks, Thai or English', () async {
      final r = await api.searchPlaces('สยาม');
      expect(r.isSample, isTrue);
      expect(r.data.first.nameTh, 'สยาม');
      expect(r.data.every((p) => p.source == 'local'), isTrue);
      expect((await api.searchPlaces('paragon')).data.first.nameTh, 'สยามพารากอน');
      expect((await api.searchPlaces('ร้านที่ไม่มีจริง')).data, isEmpty);
    });

    test('reverse names the nearest landmark, "ใกล้" only beyond 150 m', () async {
      expect((await api.reversePlace(13.7456, 100.5341)).data.nameTh, 'สยาม');
      final near = (await api.reversePlace(13.7480, 100.5341)).data;
      expect(near.nameTh, startsWith('ใกล้'));
      expect(near.lat, 13.7480, reason: 'keeps the asked point');
      final far = (await api.reversePlace(13.55, 100.32)).data;
      expect(far.nameTh, 'ตำแหน่งที่ปักหมุด');
    });

    test('reverse speaks English when the app does', () async {
      final en = FonTokMaiApi(
        baseUrl: 'http://api.test',
        language: () => 'en',
        client: MockClient((_) => throw http.ClientException('offline')),
      );
      expect((await en.reversePlace(13.7456, 100.5341)).data.nameTh, 'Siam');
      final near = (await en.reversePlace(13.7480, 100.5341)).data;
      expect(near.nameTh, startsWith('Near '));
      expect(near.addressTh, startsWith('13.7480, 100.5341 · about '));
      final far = (await en.reversePlace(13.55, 100.32)).data;
      expect(far.nameTh, 'Pinned location');
    });

    test('home-status fixture follows where home is', () {
      expect(sampleHomeStatusName(null, lat: 13.816, lng: 100.59), 'home_status_watch');
      expect(sampleHomeStatusName(null, lat: 13.7456, lng: 100.5341), 'home_status_nocanal');
      expect(sampleHomeStatusName(null, lat: 18.78, lng: 98.98), 'home_status_outside');
    });
  });

  test('slider follow-ups resend an app trip by id with its endpoints', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse({
          'verdict': 'leave_now',
          'headline_th': 'ออกได้เลย',
          'trip': {
            'id': 'app-0123456789',
            'title_th': 'กลับบ้าน',
            'source': 'app',
            'origin': {'name_th': 'ที่ทำงาน', 'lat': 13.7263, 'lng': 100.534},
            'destination': {'name_th': 'บ้าน', 'lat': 13.816, 'lng': 100.59},
            'mode': 'car',
          },
        });
      }),
    );
    final c = TripController(
      api: api,
      state: AppState(demoClock: '2026-09-29T16:10:00+07:00'),
      request: DecideRequest(origin: demoPlaces[1].asPlace, destination: demoPlaces[0].asPlace),
    );
    await c.load();
    expect(bodies.first.containsKey('trip_id'), isFalse);
    await c.setMode(TravelMode.moto);
    expect(bodies.last['trip_id'], 'app-0123456789');
    expect(bodies.last['origin'], isNotNull);
    expect(bodies.last['destination'], isNotNull);
    expect(bodies.last['mode'], 'moto');
  });

  test('TripController setOrigin updates request and sends new origin to decide', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse({
          'verdict': 'leave_now',
          'headline_th': 'ออกได้เลย',
          'trip': {
            'id': 'trip-1',
            'title_th': 'ดินเนอร์',
            'source': 'calendar',
            'origin': {'name_th': 'โรงพยาบาล A', 'lat': 13.75, 'lng': 100.55},
            'destination': {'name_th': 'ร้านอาหาร B', 'lat': 13.80, 'lng': 100.60},
            'mode': 'car',
          },
        });
      }),
    );
    final c = TripController(
      api: api,
      state: AppState(demoClock: '2026-09-29T16:10:00+07:00'),
      request: DecideRequest(
        tripId: 'trip-1',
        origin: const Place(nameTh: 'บ้าน', lat: 13.816, lng: 100.59),
        destination: const Place(nameTh: 'ร้านอาหาร B', lat: 13.80, lng: 100.60),
      ),
    );
    await c.load();
    expect(bodies.first['origin']['name_th'], 'บ้าน');
    expect(c.origin.nameTh, 'บ้าน');

    await c.setOrigin(const Place(nameTh: 'โรงพยาบาล A', lat: 13.75, lng: 100.55));
    expect(bodies.last['origin']['name_th'], 'โรงพยาบาล A');
    expect(bodies.last['origin']['lat'], 13.75);
    expect(c.origin.nameTh, 'โรงพยาบาล A');
  });
}

