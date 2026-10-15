import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/l10n/l10n.dart';
import 'package:fontokmai/location.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/places.dart';

import 'helpers.dart';

const clock = '2026-09-29T16:10:00+07:00';
final thai = RegExp('[ก-๙]');

/// Every Thai string on screen, ignoring place data from the server.
List<String> thaiTexts(
  WidgetTester tester, {
  Set<String> allowed = const {},
}) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    if (w.data != null && thai.hasMatch(w.data!) && !allowed.contains(w.data))
      w.data!,
];

void main() {
  testWidgets('onboarding reads in English', (tester) async {
    final state = await pumpApp(tester, clock, places: await freshStore());
    state.locale = const Locale('en');
    await settle(tester);

    expect(find.text('Get a heads-up before you head home'), findsOneWidget);
    expect(find.text('Use my location'), findsNWidgets(2));
    expect(find.text('Search'), findsNWidgets(2));
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(thaiTexts(tester), isEmpty);
  });

  testWidgets(
    'picker and confirm sheet read in English, default labels stay Thai in storage',
    (tester) async {
      final store = await freshStore();
      final state = await pumpApp(tester, clock, places: store);
      state.locale = const Locale('en');
      await settle(tester);

      await tapAndSettle(tester, find.text('Search').first);
      expect(find.text('Set home'), findsOneWidget);
      expect(find.text('Search, or use your current location'), findsOneWidget);
      expect(
        find.text(
          'Type at least 2 characters: a BTS station, mall, soi or district',
        ),
        findsOneWidget,
      );
      expect(thaiTexts(tester), isEmpty);

      await tester.enterText(find.byType(TextField).last, 'อารีย์');
      await settle(tester);
      expect(
        find.text('Can\'t search online. Showing offline results'),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('BTS อารีย์'));
      expect(find.text('Confirm Home'), findsOneWidget);
      expect(find.text('Saved on this device'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Home'), findsOneWidget);
      expect(
        thaiTexts(
          tester,
          allowed: {
            'BTS อารีย์',
            'ถ.พหลโยธิน เขตพญาไท',
            'ถ.พหลโยธิน เขตพญาไท · BTS Ari',
          },
        ),
        isEmpty,
        reason: 'only place data stays Thai',
      );

      await tapAndSettle(tester, find.text('Save'));
      expect(
        store.home!.labelTh,
        'บ้าน',
        reason: 'the stored default stays Thai',
      );
      expect(store.home!.labelFor(await _en()), 'Home');
    },
  );

  testWidgets('no-results and permission states read in English', (
    tester,
  ) async {
    final state = await pumpApp(
      tester,
      clock,
      places: await freshStore(),
      locator: const StagedLocator(LocateStatus.deniedForever),
    );
    state.locale = const Locale('en');
    await settle(tester);

    await tapAndSettle(tester, find.text('Use my location').first);
    expect(find.text('Location permission needed'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(thaiTexts(tester), isEmpty);
  });

  testWidgets('demo places show English labels, typed labels show as typed', (
    tester,
  ) async {
    final l = await _en();
    final byId = {for (final p in demoPlaces) p.id: p};
    expect(byId['home']!.labelFor(l), 'Home');
    expect(byId['work']!.labelFor(l), 'Work');
    expect(byId['siam']!.labelFor(l), 'Siam');
    expect(byId['impact']!.labelFor(l), 'IMPACT');
    const typed = SavedPlace(
      id: 'x',
      kind: PlaceKind.other,
      labelTh: 'ร้านกาแฟ',
      nameTh: 'ร้านกาแฟ',
      lat: 13.7,
      lng: 100.5,
    );
    expect(typed.labelFor(l), 'ร้านกาแฟ');
  });
}

Future<AppLocalizations> _en() =>
    AppLocalizations.delegate.load(const Locale('en'));
