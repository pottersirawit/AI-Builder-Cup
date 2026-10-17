import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/events.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/plan.dart';
import 'package:fontokmai/time_th.dart';

const _siam = Place(nameTh: 'สยาม', lat: 13.7462, lng: 100.5347);
const _thonglor = Place(nameTh: 'ทองหล่อ', lat: 13.7246, lng: 100.5784);
const _siamNextDoor = Place(nameTh: 'สยามดิสคัฟเวอรี่', lat: 13.7466, lng: 100.5330);
const _home = Place(nameTh: 'บ้าน', lat: 13.8160, lng: 100.5900);

DateTime _t(String hhmm, [int day = 30]) =>
    DateTime.parse('2026-09-${day}T$hhmm:00+07:00');

Trip _trip(
  String id,
  String start, {
  String? end,
  Place to = _siam,
  TravelMode mode = TravelMode.transit,
  bool virtual = false,
  bool allDay = false,
  String? unplaced,
  int day = 30,
}) => Trip(
  id: id,
  titleTh: id,
  source: 'calendar',
  origin: _home,
  destination: to,
  arriveBy: _t(start, day),
  endsAt: end == null ? null : _t(end, day),
  mode: mode,
  virtual: virtual,
  allDay: allDay,
  locationTextTh: unplaced,
);

WeatherHour _h(String hhmm, {int prob = 0, double mm = 0}) => WeatherHour(
  time: _t(hhmm),
  tempC: 30,
  feelsLikeC: 34,
  uvIndex: 0,
  rainProbPct: prob,
  rainMmPerHr: mm,
);

void main() {
  final now = _t('08:00');

  group('travelEstimate', () {
    test('grows with distance and is slower by car in town', () {
      final transit = travelEstimate(_siam, _thonglor, TravelMode.transit);
      final car = travelEstimate(_siam, _thonglor, TravelMode.car);
      expect(transit.inMinutes, inInclusiveRange(20, 45));
      expect(car, greaterThan(transit), reason: 'Bangkok traffic');
      expect(travelEstimate(_siam, _siamNextDoor, TravelMode.car), Duration.zero);
    });
  });

  group('connections', () {
    test('flags a hop that cannot be made in the gap', () {
      final cs = connections([
        _trip('lunch', '12:00', end: '12:45'),
        _trip('review', '13:00', end: '14:00', to: _thonglor),
      ]);
      final c = cs.single;
      expect(c.from.id, 'lunch');
      expect(c.to.id, 'review');
      expect(c.gap, const Duration(minutes: 15));
      expect(c.fit, ConnectionFit.short);
    });

    test('a gap that only just covers the ride is tight', () {
      final need = travelEstimate(_siam, _thonglor, TravelMode.transit);
      final cs = connections([
        _trip('lunch', '12:00', end: '12:45'),
        _trip(
          'review',
          hhmm(_t('12:45').add(need + const Duration(minutes: 5))),
          to: _thonglor,
        ),
      ]);
      expect(cs.single.fit, ConnectionFit.tight);
    });

    test('ignores online meetings, other days, unplaced and next-door hops', () {
      expect(
        connections([
          _trip('lunch', '12:00', end: '12:45'),
          _trip('meet', '12:50', virtual: true),
          _trip('shop', '13:00', to: _siamNextDoor),
        ]).where((c) => c.fit != ConnectionFit.ok),
        isEmpty,
      );
      expect(
        connections([
          _trip('a', '12:00', end: '12:45'),
          _trip('b', '13:00', unplaced: 'ร้านลับ'),
        ]),
        isEmpty,
      );
    });

    test('without an end time it assumes an hour-long event', () {
      final cs = connections([
        _trip('a', '12:00'),
        _trip('b', '13:20', to: _thonglor),
      ]);
      expect(cs.single.gap, const Duration(minutes: 20));
    });
  });

  group('nextEvent and online meetings', () {
    test('the next trip to plan skips online and all-day events', () {
      final next = nextEvent([
        _trip('holiday', '00:00', allDay: true),
        _trip('meet', '09:00', virtual: true),
        _trip('lunch', '12:00'),
      ], now);
      expect(next?.id, 'lunch');
    });
  });

  group('planAlerts', () {
    final outlook = Outlook(
      now: _h('08:00'),
      hours: [
        _h('08:00'),
        _h('11:00', prob: 20),
        _h('12:00', prob: 70, mm: 3),
        _h('13:00', prob: 85, mm: 9),
        _h('14:00', prob: 90, mm: 12),
        _h('15:00', prob: 40),
      ],
    );

    test('collects what changes the plan, most serious first', () {
      final alerts = planAlerts(
        trips: [
          _trip('lunch', '12:00', end: '12:45'),
          _trip('review', '13:00', end: '14:00', to: _thonglor, mode: TravelMode.moto),
          _trip('dentist', '17:00', unplaced: 'คลินิกอารีย์'),
        ],
        outlook: outlook,
        now: now,
        leaveAt: (t) => t.arriveBy!.subtract(const Duration(minutes: 30)),
      );
      expect([for (final a in alerts) a.kind], [
        AlertKind.shortConnection,
        AlertKind.wetLeave,
        AlertKind.wetReturn,
      ], reason: 'the place-less dentist is fourth, past the cap');
      final wet = alerts[1];
      expect(wet.trip.id, 'review');
      expect(hhmm(wet.at!), '12:30');
      expect(wet.value, 70, reason: 'rain chance in the 12:00 hour');
      final back = alerts[2];
      expect(back.trip.id, 'review', reason: 'last trip of the day');
      expect(hhmm(back.at!), '14:00');
      expect(back.value, 90);
    });

    test('a leave time already gone is now, not a past hour', () {
      final late = _t('12:40');
      final alerts = planAlerts(
        trips: [_trip('review', '13:00', to: _thonglor)],
        outlook: outlook,
        now: late,
        leaveAt: (t) => null,
      );
      final wet = alerts.firstWhere((a) => a.kind == AlertKind.wetLeave);
      expect(wet.at, late, reason: '13:00 - 45 min is already past');
      expect(wet.value, 70, reason: 'the 12:00 hour, where now falls');
    });

    test('no rain-as-you-leave alert once the event has started', () {
      final alerts = planAlerts(
        trips: [_trip('review', '13:00', end: '14:00', to: _thonglor)],
        outlook: outlook,
        now: _t('13:05'),
        leaveAt: (t) => null,
      );
      expect(alerts.map((a) => a.kind), isNot(contains(AlertKind.wetLeave)));
    });

    test('a dry day with an easy schedule raises nothing', () {
      expect(
        planAlerts(
          trips: [_trip('lunch', '12:00', end: '12:45')],
          outlook: Outlook(now: _h('08:00'), hours: [_h('11:00'), _h('12:00')]),
          now: now,
          leaveAt: (t) => t.arriveBy!.subtract(const Duration(minutes: 30)),
        ),
        isEmpty,
      );
    });
  });

  test('alerts put today first and keep the list short', () {
    final alerts = planAlerts(
      trips: [
        _trip('tomorrow-a', '12:00', end: '12:45', day: 30),
        _trip('tomorrow-b', '13:00', to: _thonglor, day: 30),
        _trip('today-x', '20:00', unplaced: 'ร้าน', day: 29),
      ],
      now: DateTime.parse('2026-09-29T16:00:00+07:00'),
      leaveAt: (t) => null,
    );
    expect(alerts.first.trip.id, 'today-x', reason: 'today before tomorrow');
    expect(alerts.length, lessThanOrEqualTo(maxAlerts));
  });
}
