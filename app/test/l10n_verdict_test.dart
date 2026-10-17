import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _clock = '2026-09-29T16:10:00+07:00';

void main() {
  testWidgets('the verdict screen shows English chrome', (tester) async {
    final state = await pumpApp(tester, _clock, height: 2400);
    await openHero(tester);
    expect(find.text('เทียบวิธีเดินทาง'), findsOneWidget);

    state.locale = const Locale('en');
    await settle(tester);

    expect(find.text('Compare ways to travel'), findsOneWidget);
    expect(find.text('Flood spots on your route'), findsOneWidget);
    await reveal(tester, find.text('Ask a follow-up'));
    expect(find.text('Ask a follow-up'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('เทียบวิธีเดินทาง'), findsNothing);
    expect(find.text('ถามต่อ'), findsNothing);
  });

  testWidgets('flood checklist in English', (tester) async {
    final state = await pumpApp(tester, '2026-09-29T21:40:00+07:00');
    state.locale = const Locale('en');
    await settle(tester);
    await tapAndSettle(tester, find.text('What to do'));

    expect(find.text('Do this now, in order'), findsOneWidget);
    expect(find.text('ทำตอนนี้ เรียงตามลำดับ'), findsNothing);
  });

  testWidgets('settings in English, and the selector flips the language', (
    tester,
  ) async {
    final state = await pumpApp(tester, _clock);
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 1000),
    );
    await tester.pump();
    await settle(tester);
    await tapAndSettle(tester, find.byTooltip('ตั้งค่า'));
    expect(find.text('ตั้งค่า'), findsOneWidget);

    await tapAndSettle(tester, find.text('English'));
    expect(state.locale, const Locale('en'));
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 1500),
    );
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('My places'), findsOneWidget);
    expect(find.text('ตั้งค่า'), findsNothing);
    expect(find.text('สถานที่ของฉัน'), findsNothing);

    await reveal(tester, find.text('Gmail'));
    for (final hidden in [
      'Community and flooding',
      'Profile',
      'For the team',
      'Design system',
      'Demo clock',
      'Learn my routine',
      'Remind me ahead',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }

    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 3000),
    );
    await settle(tester);
    await tapAndSettle(tester, find.text('ไทย'));
    expect(state.locale, const Locale('th'));
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 3000),
    );
    await settle(tester);
    expect(find.text('ตั้งค่า'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });
}
