import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/screens/verdict_screen.dart';

import 'helpers.dart';

Map<String, Object?> _allDay(
  String id,
  String title,
  String start,
  String end, {
  String place = '',
}) => {
  'id': id,
  'title_th': title,
  'source': 'calendar',
  'origin': {'name_th': 'Home', 'lat': 13.72, 'lng': 100.53},
  'destination': {'name_th': place},
  'arrive_by': '${start}T00:00:00+07:00',
  'ends_at': '${end}T00:00:00+07:00',
  'mode': 'car',
  'all_day': true,
};

Future<void> _pump(WidgetTester tester) async => pumpApp(
  tester,
  '2026-09-30T10:00:00+07:00',
  height: 2400,
  places: (await emptyStore())..connectGoogle('owner@example.com'),
  respond: (req) => req.url.path.startsWith('/v1/trips')
      ? jsonResponse({
          'trips': [
            _allDay('cal-cm', 'เที่ยวเชียงใหม่', '2026-09-28', '2026-10-02'),
            _allDay(
              'cal-wed',
              'งานแต่งพี่บี',
              '2026-09-30',
              '2026-10-01',
              place: 'โรงแรมสุโขทัย',
            ),
          ],
        })
      : null,
);

void main() {
  testWidgets('all-day tickets say their days and open a detail sheet', (
    tester,
  ) async {
    await _pump(tester);
    await tapAndSettle(tester, find.text('อีเวนต์'));

    expect(
      find.text('ทั้งวัน · 28 ก.ย. – 1 ต.ค.'),
      findsOneWidget,
      reason: 'a multi-day trip shows its range',
    );
    expect(find.text('ไม่มีเวลาออก'), findsOneWidget, reason: 'no place');
    expect(find.text('โรงแรมสุโขทัย'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('event-cal-cm')));
    expect(
      find.text('กิจกรรมทั้งวันไม่มีเวลานัด จึงไม่มีเวลาออกให้'),
      findsOneWidget,
    );
    expect(find.textContaining('ถามทางไป'), findsNothing, reason: 'no place');
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await settle(tester);

    await tapAndSettle(tester, find.byKey(const ValueKey('event-cal-wed')));
    await tapAndSettle(tester, find.text('ถามทางไปโรงแรมสุโขทัย'));
    final verdict = tester.widget<VerdictScreen>(find.byType(VerdictScreen));
    expect(verdict.request.questionTh, 'ไปโรงแรมสุโขทัยตอนนี้');
  });

  testWidgets('the summary opens the same sheet for an all-day event', (
    tester,
  ) async {
    await _pump(tester);
    await tapAndSettle(tester, find.text('งานแต่งพี่บี').first);
    expect(find.text('ถามทางไปโรงแรมสุโขทัย'), findsOneWidget);
  });
}
