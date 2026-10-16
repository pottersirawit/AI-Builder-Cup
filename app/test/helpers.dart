import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/google_link.dart';
import 'package:fontokmai/location.dart';
import 'package:fontokmai/main.dart';
import 'package:fontokmai/places.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh in-memory device store.
Future<PlacesStore> freshStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PlacesStore(await SharedPreferences.getInstance());
}

Future<PlacesStore> demoStore() async => (await freshStore())..useDemoProfile();

/// Skipped onboarding, nothing saved.
Future<PlacesStore> emptyStore() async =>
    (await freshStore())..completeOnboarding();

http.Response jsonResponse(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

/// Pumps the app offline (every request falls back to fixtures). [places]
/// defaults to มิว's demo profile; [respond] can answer a request instead.
/// [launch] stands in for opening Google; [appBase] is the app's URL.
Future<AppState> pumpApp(
  WidgetTester tester,
  String? clock, {
  List<String>? decideLog,
  double height = 874,
  PlacesStore? places,
  Locator locator = const StagedLocator(LocateStatus.ok),
  http.Response? Function(http.Request req)? respond,
  Future<bool> Function(Uri url)? launch,
  Uri? appBase,
}) async {
  tester.view.physicalSize = Size(402 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Most widget tests read the Thai copy; English ones switch explicitly.
  final state = AppState(demoClock: clock, locale: const Locale('th'));
  final api = FonTokMaiApi(
    baseUrl: 'http://offline.test',
    demoClock: () => state.demoClock,
    language: () => state.locale.languageCode,
    client: MockClient((req) async {
      if (req.url.path == '/v1/decide') decideLog?.add(req.body);
      final r = respond?.call(req);
      if (r != null) return r;
      throw http.ClientException('offline');
    }),
    bundle: _DiskBundle(),
  );
  places ??= await demoStore();
  final link = GoogleLink(
    api: api,
    places: places,
    appBase: appBase ?? Uri.parse('http://localhost:8080/'),
    launch: launch ?? (_) async => false,
    replaceUrl: (_) {},
  );
  await tester.pumpWidget(
    FonTokMaiApp(
      state: state,
      places: places,
      api: api,
      locator: locator,
      googleLink: link,
    ),
  );
  await settle(tester);
  return state;
}

/// Serves assets straight from disk so fixture loads finish inside fake async.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Scrolls the visible vertical list until [f] is built; lists build lazily.
Future<void> reveal(WidgetTester tester, Finder f) async {
  final list = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable()
      .first;
  for (final dy in [-250.0, 250.0]) {
    for (var i = 0; i < 15 && f.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(list, Offset(0, dy));
      await tester.pump();
    }
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f.hitTestable().first);
  await tester.pump();
  await settle(tester);
}

String bubbleText(WidgetTester tester) => tester
    .widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('rain-band-bubble')),
            matching: find.byType(Text),
          )
          .first,
    )
    .data!;

/// Opens the summary hero's detail (the demo's dinner trip).
Future<void> openHero(WidgetTester tester) =>
    tapAndSettle(tester, find.byKey(const ValueKey('hero-cal-dinner')));
