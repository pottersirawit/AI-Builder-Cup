import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('all-day tickets say their days and ask for a place to go', (
    tester,
  ) async {
    await _pump(tester);
    await tapAndSettle(tester, find.text('อีเวนต์'));

    expect(
      find.text('ทั้งวัน · 28 ก.ย. – 1 ต.ค.'),
      findsOneWidget,
      reason: 'a multi-day trip shows its range',
    );

    await tapAndSettle(tester, find.byKey(const ValueKey('event-cal-wed')));
    expect(find.text('ไม่พบ “โรงแรมสุโขทัย”'), findsOneWidget);
  });

  testWidgets('the summary opens the detail sheet for an all-day event', (
    tester,
  ) async {
    await _pump(tester);
    await tapAndSettle(tester, find.byKey(const ValueKey('next-cal-cm')));
    expect(
      find.text('กิจกรรมทั้งวันไม่มีเวลานัด จึงไม่มีเวลาออกให้'),
      findsOneWidget,
    );
    expect(find.textContaining('ถามทางไป'), findsNothing, reason: 'no place');
  });

  testWidgets(
    'events page infers location from event name, shows confirmation UI, and persists all-day and hybrid events',
    (tester) async {
      final store = (await emptyStore())..connectGoogle('owner@example.com');
      var serverTrips = <Map<String, Object?>>[
        // 1. All-day event with location in event name -> AI infers location
        _allDay(
          'cal-bookfair',
          'งานหนังสือที่สยามพารากอน',
          '2026-09-30',
          '2026-10-01',
        ),
        // 2. Online meeting with Google Meet + physical location -> treated as onsite
        {
          'id': 'cal-hybrid',
          'title_th': 'ประชุมทีม (Google Meet)',
          'source': 'calendar',
          'origin': {'name_th': 'Home', 'lat': 13.72, 'lng': 100.53},
          'destination': {
            'name_th': 'ไบเทค บางนา',
            'lat': 13.67,
            'lng': 100.61,
          },
          'arrive_by': '2026-09-30T14:00:00+07:00',
          'ends_at': '2026-09-30T15:00:00+07:00',
          'mode': 'car',
          'virtual': true,
        },
      ];

      await pumpApp(
        tester,
        '2026-09-30T10:00:00+07:00',
        height: 2400,
        places: store,
        respond: (req) {
          if (req.url.path.startsWith('/v1/trips')) {
            return jsonResponse({'trips': serverTrips});
          }
          if (req.url.path == '/v1/places/search') {
            final q = req.url.queryParameters['q'] ?? '';
            if (q.contains('สยามพารากอน')) {
              return jsonResponse({
                'places': [
                  {
                    'name_th': 'สยามพารากอน',
                    'address_th': 'ปทุมวัน กรุงเทพฯ',
                    'lat': 13.7466,
                    'lng': 100.5347,
                    'source': 'geocoder',
                  },
                ],
              });
            }
          }
          return null;
        },
      );

      await tapAndSettle(tester, find.text('อีเวนต์'));

      // Hybrid online meeting with location is shown as onsite ('ไบเทค บางนา'), not online
      expect(find.text('ไบเทค บางนา'), findsOneWidget);
      expect(find.text('ออนไลน์ · ไม่ต้องเดินทาง'), findsNothing);

      // AI inferred 'สยามพารากอน' from 'งานหนังสือที่สยามพารากอน' and shows confirmation UI
      expect(
        find.text('AI แนะนำสถานที่: สยามพารากอน'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('confirm-place-cal-bookfair')),
        findsOneWidget,
      );

      // Confirm the inferred location on the all-day event
      await tapAndSettle(
        tester,
        find.byKey(const ValueKey('confirm-place-cal-bookfair')),
      );

      // Confirmation prompt disappears and the saved place is shown on the all-day event
      expect(find.text('AI แนะนำสถานที่: สยามพารากอน'), findsNothing);
      expect(find.text('สยามพารากอน'), findsOneWidget);

      // Refresh events (server still returns unplaced _allDay for cal-bookfair)
      await tapAndSettle(tester, find.byTooltip('รีเฟรช'));

      // All-day event's saved location persists across refresh!
      expect(find.text('สยามพารากอน'), findsOneWidget);
      expect(find.text('AI แนะนำสถานที่: สยามพารากอน'), findsNothing);
    },
  );
}
