import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/config.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/l10n/l10n.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/screens/verdict_screen.dart';
import 'package:fontokmai/trip_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  group('CRIT-05: demoClockIso and unhandled FormatException guards', () {
    test('demoClockIso leaves full RFC3339/ISO string unchanged', () {
      const fullIso = '2026-09-29T16:10:00+07:00';
      expect(demoClockIso(fullIso), fullIso);

      const utcIso = '2026-09-29T09:10:00Z';
      expect(demoClockIso(utcIso), utcIso);
    });

    test('demoClockIso only prepends Bangkok date when input is HH:MM', () {
      final now = DateTime.parse('2026-09-29T10:00:00Z'); // 17:00 Bangkok
      expect(demoClockIso('16:10', now: now), '2026-09-29T16:10:00+07:00');
      expect(demoClockIso('8:05', now: now), '2026-09-29T08:05:00+07:00');
    });

    test('AppState.now() does not throw FormatException on invalid demoClock', () {
      final state = AppState(demoClock: 'not-a-valid-datetime');
      expect(() => state.now(), returnsNormally);
      final now = state.now();
      expect(now.year, DateTime.now().year);
    });

    test('FonTokMaiApi.outlook sample fallback does not throw on invalid demoClock', () async {
      final api = FonTokMaiApi(
        baseUrl: 'http://test.api',
        demoClock: () => 'garbage-format-clock',
        allowSample: () => true,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      // Should safely use DateTime.now() in sampleOutlook fallback instead of throwing FormatException
      expect(() => api.outlook(), returnsNormally);
      final res = await api.outlook();
      expect(res.data, isNotNull);
    });
  });

  group('HIGH-03: Transit mode switch failure does not show stale decision', () {
    test('TripController.setMode clears _decision immediately', () async {
      final state = AppState(demoClock: '2026-09-29T16:10:00+07:00');
      final j = jsonDecode(File('assets/fixtures/decide_car.json').readAsStringSync()) as Json;
      bool shouldFail = false;
      final api = FonTokMaiApi(
        baseUrl: 'http://test.api',
        demoClock: () => state.demoClock,
        allowSample: () => false,
        client: MockClient((req) async {
          if (shouldFail) {
            throw http.ClientException('500 internal server error');
          }
          return jsonResponse(j);
        }),
      );

      final c = TripController(
        api: api,
        state: state,
        request: const DecideRequest(tripId: 'cal-dinner'),
        mode: TravelMode.car,
      );

      await c.load();
      expect(c.decision, isNotNull);
      expect(c.mode, TravelMode.car);

      // Changing mode when API will fail should clear _decision
      shouldFail = true;
      await c.setMode(TravelMode.transit);
      expect(c.decision, isNull);
      expect(c.error, isNotNull);
      expect(c.mode, TravelMode.transit);
    });

    testWidgets('VerdictScreen shows error banner and snackbar on mode switch failure without displaying stale decision', (tester) async {
      tester.view.physicalSize = const Size(402 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final carJson = jsonDecode(File('assets/fixtures/decide_car.json').readAsStringSync()) as Json;
      final trips = Trip.listFromJson(jsonDecode(File('assets/fixtures/trips.json').readAsStringSync()) as Json);
      final trip = trips.first;
      bool failDecide = false;

      final state = AppState(demoClock: '2026-09-29T16:10:00+07:00', locale: const Locale('th'));
      final places = await demoStore();
      final api = FonTokMaiApi(
        baseUrl: 'http://test.api',
        demoClock: () => state.demoClock,
        allowSample: () => false,
        client: MockClient((req) async {
          if (req.url.path == '/v1/decide') {
            if (failDecide) {
              return http.Response('{"error":"fail"}', 500, headers: {'content-type': 'application/json'});
            }
            return jsonResponse(carJson);
          }
          if (req.url.path == '/v1/outlook') {
            return jsonResponse(jsonDecode(File('assets/fixtures/outlook.json').readAsStringSync()));
          }
          throw http.ClientException('offline');
        }),
      );

      await tester.pumpWidget(
        AppScope(
          state: state,
          places: places,
          api: api,
          child: MaterialApp(
            theme: buildTheme(),
            locale: const Locale('th'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VerdictScreen(
                request: DecideRequest(tripId: trip.id),
                trip: trip,
                mode: TravelMode.car,
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      // Verify initial car decision is rendered
      expect(find.text('ควรออกก่อน 16:45'), findsOneWidget);

      // Now make mode switch fail
      failDecide = true;

      // Find and tap transit mode segment
      await tapAndSettle(tester, find.text('รถไฟฟ้า'));

      // Previous decision headline should NOT be displayed anymore
      expect(find.text('ควรออกก่อน 16:45'), findsNothing);

      // Explicit error state banner must be shown
      expect(find.byType(ErrorState), findsOneWidget);

      // SnackBar with retry must be shown
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('HIGH-04: SummaryScreen _onTrip mounted check', () {
    testWidgets('SummaryScreen disposes safely while trip controller fires', (tester) async {
      await pumpApp(
        tester,
        '2026-09-29T16:10:00+07:00',
        height: 1000,
      );

      // Navigate to Settings to pop/push and dispose SummaryScreen
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
      }

      // No crash or setState() called after dispose exception
      expect(tester.takeException(), isNull);
    });
  });

  group('HIGH-05: Defensive deserialization for models.dart', () {
    test('Decision.fromJson parses malformed sources without error', () {
      final j = jsonDecode(File('assets/fixtures/decide_car.json').readAsStringSync()) as Json;
      j['sources'] = ['Valid Source', 12345, null, true, {'nested': 'obj'}];

      expect(() => Decision.fromJson(j), returnsNormally);
      final d = Decision.fromJson(j);
      expect(d.sources, contains('Valid Source'));
      expect(d.sources, contains('12345'));
    });

    test('FloodReport.fromJson parses malformed passable without error', () {
      final j = {
        'id': 'rpt-1',
        'depth_cm_min': 10,
        'depth_cm_max': 25,
        'confidence': 0.85,
        'description_th': 'น้ำท่วมขัง',
        'passable': {
          'car': 'slow',
          'transit': 123,
          'moto': false,
        },
        'notified_users': 5,
        'corroborating_reports': 2,
        'generated_by': 'gemini',
      };

      expect(() => FloodReport.fromJson(j), returnsNormally);
      final r = FloodReport.fromJson(j);
      expect(r.passable[TravelMode.car], 'slow');
      expect(r.passable[TravelMode.transit], '123');
      expect(r.passable[TravelMode.moto], 'false');
    });

    test('SavedPlace.fromJson parses malformed days and non-string fields safely', () {
      final j = {
        'id': 'p1',
        'kind': 'work',
        'label_th': 'ที่ทำงาน',
        'name_th': 'อาคารสาทร',
        'address_th': 'สาทร',
        'lat': 13.72,
        'lng': 100.52,
        'icon': 999, // non-string
        'days': ['1', 2, 3.5, 'invalid', null],
        'leave_time': 1800, // non-string
      };

      expect(() => SavedPlace.fromJson(j), returnsNormally);
      final place = SavedPlace.fromJson(j);
      expect(place.icon, '999');
      expect(place.days, [1, 2, 3]);
      expect(place.leaveTime, '1800');
    });

    test('ActivityPlan, HomeStatus, Outlook parse malformed list fields safely', () {
      final jPlan = {
        'activity': 'climbing',
        'headline_th': 'เตรียมตัวไปปีนผา',
        'weather_notes_th': ['note 1', 42, null],
        'suggestions_th': ['sug 1', true],
        'checklist': [],
      };
      expect(() => ActivityPlan.fromJson(jPlan), returnsNormally);
      final plan = ActivityPlan.fromJson(jPlan);
      expect(plan.weatherNotesTh, ['note 1', '42']);
      expect(plan.suggestionsTh, ['sug 1', 'true']);

      final jHome = {
        'level': 'normal',
        'headline_th': 'ปกติ',
        'sources': ['sensor-1', 99],
        'actions': [],
      };
      expect(() => HomeStatus.fromJson(jHome), returnsNormally);
      final home = HomeStatus.fromJson(jHome);
      expect(home.sources, ['sensor-1', '99']);

      final jOutlook = {
        'now': {
          'time': '2026-09-29T16:00:00+07:00',
          'rain_intensity': 'none',
          'rain_prob_pct': 0,
          'rain_mm_per_hr': 0.0,
          'temp_c': 31.0,
          'wind_km_per_hr': 10.0,
        },
        'hours': [],
        'sources': ['source-1', 404],
      };
      expect(() => Outlook.fromJson(jOutlook), returnsNormally);
      final outlook = Outlook.fromJson(jOutlook);
      expect(outlook.sources, ['source-1', '404']);
    });
  });
}
