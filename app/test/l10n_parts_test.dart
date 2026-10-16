import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/l10n/l10n.dart';
import 'package:fontokmai/screens/gallery_screen.dart';

import 'helpers.dart';

final _thai = RegExp(r'[ก-๙]');

void main() {
  testWidgets('the departure pass, board and GeneratedBy read in English', (
    tester,
  ) async {
    final state = await pumpApp(tester, '2026-09-29T16:10:00+07:00');
    state.locale = const Locale('en');
    await settle(tester);
    await openHero(tester);

    expect(find.text('Analyzed by AI'), findsOneWidget);
    expect(find.text('AI วิเคราะห์ให้'), findsNothing);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Arrive'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Sure'), findsWidgets);
    expect(find.text('Drag the pin to try a departure time'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Sample data'), findsWidgets);
    expect(find.textContaining(RegExp(r'Takes \d+ min')), findsOneWidget);

    final band = find.byKey(const ValueKey('rain-band'));
    await reveal(tester, band);
    expect(bubbleText(tester), 'Leave 16:10');
  });

  testWidgets(
    'dragging the pin shows the English preview text and a way back',
    (tester) async {
      final state = await pumpApp(
        tester,
        '2026-09-29T16:10:00+07:00',
        height: 1600,
      );
      state.locale = const Locale('en');
      await settle(tester);
      await openHero(tester);

      final band = find.byKey(const ValueKey('rain-band'));
      await reveal(tester, band);
      final rect = tester.getRect(band);
      double xAt(int m) => rect.left + rect.width * m / 300;
      final gesture = await tester.startGesture(Offset(xAt(10), rect.top + 60));
      for (var m = 20; m <= 100; m += 10) {
        await gesture.moveTo(Offset(xAt(m), rect.top + 60));
        await tester.pump();
      }
      expect(
        find.text('Estimated from rain along the route. Release to confirm.'),
        findsOneWidget,
      );
      expect(find.text('Leave now'), findsOneWidget);
      await gesture.up();
      await settle(tester);
    },
  );

  testWidgets('the home status card reads in English in flood mode', (
    tester,
  ) async {
    final state = await pumpApp(tester, '2026-09-29T21:40:00+07:00');
    state.locale = const Locale('en');
    await settle(tester);
    expect(find.text('Flooding near home'), findsOneWidget);
    await tapAndSettle(tester, find.text('What to do'));

    expect(find.text('Danger'), findsWidgets);
    expect(find.text('Canal level'), findsOneWidget);
    expect(find.text('Rise in 2 h'), findsOneWidget);
    expect(find.text('To the bank'), findsOneWidget);
    expect(find.text('ระดับคลอง'), findsNothing);
  });

  testWidgets('the design gallery opens in English without Thai UI labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(),
        home: const GalleryScreen(),
      ),
    );
    await settle(tester);

    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('Clear'), findsWidgets);
    expect(find.text('Sky fields'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final s = w.data ?? w.textSpan?.toPlainText() ?? '';
        expect(
          _thai.hasMatch(s),
          isFalse,
          reason: 'Thai left in gallery: "$s"',
        );
      }
      await tester.drag(list, const Offset(0, -600));
      await tester.pump();
    }
  });
}
