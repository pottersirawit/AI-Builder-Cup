import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/departure.dart';
import 'package:fontokmai/events.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/time_th.dart';

Decision _fixture(String name) => Decision.fromJson(
  jsonDecode(File('assets/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>,
);

Trip _trip(
  String id,
  String? arriveBy, {
  String source = 'calendar',
  bool resolved = true,
  bool allDay = false,
}) => Trip(
  id: id,
  titleTh: id,
  source: source,
  origin: const Place(nameTh: 'สีลม', lat: 13.72, lng: 100.53),
  destination: resolved
      ? const Place(nameTh: 'สยาม', lat: 13.74, lng: 100.53)
      : const Place(nameTh: 'ตึกใหม่', lat: 0, lng: 0),
  arriveBy: arriveBy == null ? null : DateTime.parse(arriveBy),
  mode: TravelMode.car,
  locationTextTh: resolved ? null : 'ตึกใหม่',
  allDay: allDay,
);

/// An all-day calendar event from [start] up to the exclusive [end] date.
Trip _allDay(String id, String start, String end, {String place = ''}) => Trip(
  id: id,
  titleTh: id,
  source: 'calendar',
  origin: const Place(nameTh: 'สีลม', lat: 13.72, lng: 100.53),
  destination: Place(nameTh: place, lat: 0, lng: 0),
  arriveBy: DateTime.parse('${start}T00:00:00+07:00'),
  endsAt: DateTime.parse('${end}T00:00:00+07:00'),
  mode: TravelMode.car,
  allDay: true,
);

void main() {
  final now = DateTime.parse('2026-10-17T16:00:00+07:00');

  group('upcoming', () {
    test('sorts by arrival and drops past events and routine trips', () {
      final out = upcoming([
        _trip('late', '2026-10-18T09:00:00+07:00'),
        _trip('past', '2026-10-17T12:00:00+07:00'),
        _trip('soon', '2026-10-17T18:30:00+07:00', source: 'gmail'),
        _trip('home', '2026-10-17T19:00:00+07:00', source: 'routine'),
      ], now);
      expect(out.map((t) => t.id), ['soon', 'late']);
    });

    test('keeps an event that started under 10 minutes ago', () {
      final out = upcoming([
        _trip('started', '2026-10-17T15:55:00+07:00'),
        _trip('gone', '2026-10-17T15:45:00+07:00'),
      ], now);
      expect(out.map((t) => t.id), ['started']);
    });

    test('puts events without a time last', () {
      final out = upcoming([
        _trip('untimed', null),
        _trip('timed', '2026-10-20T09:00:00+07:00'),
      ], now);
      expect(out.map((t) => t.id), ['timed', 'untimed']);
    });
  });

  group('nextEvent', () {
    test('is the first timed upcoming event, unresolved or not', () {
      final next = nextEvent([
        _trip('untimed', null),
        _trip('b', '2026-10-17T20:00:00+07:00'),
        _trip('a', '2026-10-17T18:00:00+07:00', resolved: false),
      ], now);
      expect(next?.id, 'a');
    });

    test('is null when nothing is coming up', () {
      expect(nextEvent([_trip('untimed', null)], now), isNull);
      expect(nextEvent(const [], now), isNull);
    });
  });

  group('groupByDay', () {
    test('groups on Bangkok days, not device days', () {
      final groups = groupByDay([
        _trip('a', '2026-10-17T23:30:00+07:00'),
        _trip('b', '2026-10-18T00:30:00+07:00'),
        _trip('c', '2026-10-18T09:00:00+07:00'),
      ]);
      expect(groups.map((g) => g.day), [
        DateTime.utc(2026, 10, 17),
        DateTime.utc(2026, 10, 18),
      ]);
      expect(groups.map((g) => g.trips.map((t) => t.id).toList()), [
        ['a'],
        ['b', 'c'],
      ]);
    });

    test('gives untimed events their own group with no day', () {
      final groups = groupByDay([
        _trip('a', '2026-10-17T18:00:00+07:00'),
        _trip('x', null),
      ]);
      expect(groups.last.day, isNull);
      expect(groups.last.trips.single.id, 'x');
    });
  });

  group('planDepartFor', () {
    test('plans from now when the event is within the planning window', () {
      final t = _trip('soon', '2026-10-17T18:30:00+07:00');
      expect(planDepartFor(t, now), now);
    });

    test('plans a later event from three hours before it', () {
      final t = _trip('tomorrow', '2026-10-18T09:00:00+07:00');
      expect(isoBangkok(planDepartFor(t, now)), '2026-10-18T06:00:00+07:00');
    });

    test('plans an all-day event today from now', () {
      final t = _trip('today-allday', '2026-10-17T00:00:00+07:00', allDay: true);
      expect(planDepartFor(t, now), now);
    });

    test('plans an all-day event on a future day from morning 08:00', () {
      final t = _trip('future-allday', '2026-10-19T00:00:00+07:00', allDay: true);
      expect(isoBangkok(planDepartFor(t, now)), '2026-10-19T08:00:00+07:00');
    });
  });

  group('leavePlan', () {
    final at = DateTime.parse('2026-09-29T16:10:00+07:00');
    LeavePlan plan(String fixture, DateTime now) {
      final d = _fixture(fixture);
      return leavePlan(d, rankOptions(serverOptions(d, now)), now);
    }

    test('go now: leave before the server time, on the best-ranked mode', () {
      final p = plan('decide_car', at);
      expect(p.kind, LeaveKind.before);
      expect(hhmm(p.time!), '16:45');
      expect(p.best!.mode, TravelMode.transit);
      expect(hhmm(p.arriveAt), '17:25', reason: '16:45 + 40 min by BTS');
    });

    test('a passed leave-by time becomes overdue, arriving from now', () {
      final p = plan('decide_car', DateTime.parse('2026-09-29T16:50:00+07:00'));
      expect(p.kind, LeaveKind.overdue);
      expect(hhmm(p.arriveAt), '17:30');
    });

    test('wait on the car, but the BTS goes now: the plan is the BTS', () {
      final d = _fixture('decide_car_storm');
      final dinner = DateTime.parse('2026-09-29T18:30:00+07:00');
      final p = leavePlan(
        d,
        rankOptions(serverOptions(d, at)),
        at,
        deadline: dinner,
      );
      expect(p.best!.mode, TravelMode.transit);
      expect(p.kind, LeaveKind.before);
      expect(
        hhmm(p.time!),
        '16:55',
        reason: 'the latest BTS trip that stays out of the 17:45 downpour',
      );
      expect(hhmm(p.arriveAt), '17:45');
    });

    test('the alternative is "now", not overdue, while it still makes it', () {
      final d = _fixture('decide_car_storm');
      final dinner = DateTime.parse('2026-09-29T18:30:00+07:00');
      final board = rankOptions(serverOptions(d, at));
      final p = leavePlan(
        d,
        board,
        DateTime.parse('2026-09-29T17:31:00+07:00'),
        deadline: dinner,
      );
      expect(p.kind, LeaveKind.now, reason: '17:31 + 50 min is 18:21');
      final late = leavePlan(
        d,
        board,
        DateTime.parse('2026-09-29T17:50:00+07:00'),
        deadline: dinner,
      );
      expect(late.kind, LeaveKind.overdue);
      expect(hhmm(late.time!), '17:30');
    });

    test('switch mode never reads the leave-by as "leave before"', () {
      final p = plan('decide_moto_storm', at);
      expect(p.best!.mode, TravelMode.transit);
      expect(p.kind, LeaveKind.now, reason: 'no event to back off from');
      expect(hhmm(p.arriveAt), '17:00');
    });

    test('wait when nothing else can go: leave at the server time', () {
      final d = _fixture('decide_car_storm');
      final carOnly = rankOptions(
        serverOptions(d, at).where((o) => o.mode == TravelMode.car).toList(),
      );
      final p = leavePlan(d, carOnly, at);
      expect(p.kind, LeaveKind.at);
      expect(hhmm(p.time!), '19:15');
      final later = leavePlan(
        d,
        carOnly,
        DateTime.parse('2026-09-29T19:40:00+07:00'),
      );
      expect(later.kind, LeaveKind.now, reason: 'the wait is over');
      expect(hhmm(later.arriveAt), '21:15', reason: '19:40 + 95 min');
    });

    test('a leave-by before the planned departure is stale, not overdue', () {
      final d = _fixture('decide_car');
      final planned = DateTime.parse('2026-10-03T16:00:00+07:00');
      final now = DateTime.parse('2026-09-29T18:40:00+07:00');
      final board = rankOptions(serverOptions(d, planned));
      final p = leavePlan(d, board, now);
      expect(p.kind, LeaveKind.before);
      expect(isoBangkok(p.time!), '2026-10-03T16:00:00+07:00');

      final event = DateTime.parse('2026-10-03T19:00:00+07:00');
      final timed = leavePlan(d, board, now, deadline: event);
      expect(
        isoBangkok(timed.time!),
        '2026-10-03T18:10:00+07:00',
        reason: '19:00 - 40 min by BTS - 10 min to spare',
      );
    });

    test(
      'a leave-by far earlier than the event is stale even when planning from now',
      () {
        final d = _fixture('decide_transit');
        final now = DateTime.parse('2026-09-30T08:00:00+07:00');
        final event = DateTime.parse('2026-09-30T09:30:00+07:00');
        final p = leavePlan(
          d,
          rankOptions(serverOptions(d, now)),
          now,
          deadline: event,
        );
        expect(p.kind, LeaveKind.before);
        expect(hhmm(p.time!), '08:40', reason: '09:30 - 40 min - 10 min');
      },
    );

    test(
      'an event tomorrow with no leave-by never returns LeaveKind.now',
      () {
        final j =
            jsonDecode(
                  File('assets/fixtures/decide_car.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        j.remove('leave_by');
        final d = Decision.fromJson(j);
        final now = DateTime.parse('2026-10-17T22:20:00+07:00');
        final eventTomorrow = DateTime.parse('2026-10-18T13:30:00+07:00');
        final planned = DateTime.parse('2026-10-18T10:30:00+07:00');
        final p = leavePlan(
          d,
          rankOptions(serverOptions(d, planned)),
          now,
          deadline: eventTomorrow,
        );
        expect(p.kind, LeaveKind.before);
        expect(
          isoBangkok(p.time!),
          '2026-10-18T12:40:00+07:00',
          reason: '13:30 - 40 min by BTS - 10 min slack',
        );
      },
    );
  });

  group('all-day events', () {
    final trip = _allDay('chiangmai', '2026-10-15', '2026-10-19');
    final today = DateTime.utc(2026, 10, 17);

    test('a trip that started days ago files under today, first', () {
      final out = upcoming([
        _trip('dinner', '2026-10-17T19:00:00+07:00'),
        trip,
      ], now);
      expect(out.map((t) => t.id), ['chiangmai', 'dinner']);
      final groups = groupByDay(out, now: now);
      expect(groups.single.day, today);
      expect(eventDay(trip, now), today);
    });

    test('covers every day up to its exclusive end', () {
      expect(daysOf(trip), [
        DateTime.utc(2026, 10, 15),
        DateTime.utc(2026, 10, 16),
        today,
        DateTime.utc(2026, 10, 18),
      ]);
      expect(onDay(trip, today), isTrue);
      expect(onDay(trip, DateTime.utc(2026, 10, 19)), isFalse);
      final timed = _trip('dinner', '2026-10-17T19:00:00+07:00');
      expect(daysOf(timed), [today]);
      expect(onDay(timed, DateTime.utc(2026, 10, 18)), isFalse);
    });

    test('drops off once its last day is over', () {
      final over = DateTime.parse('2026-10-19T00:30:00+07:00');
      expect(upcoming([trip], over), isEmpty);
    });

    test('a future one keeps its own day', () {
      final later = _allDay('holiday', '2026-10-23', '2026-10-24');
      expect(eventDay(later, now), DateTime.utc(2026, 10, 23));
    });
  });

  group('previousEventFor', () {
    test('finds the preceding same-day event with resolved destination', () {
      final dentist = _trip(
        'dentist',
        '2026-10-17T10:00:00+07:00',
        resolved: true,
      );
      final dinner = _trip(
        'dinner',
        '2026-10-17T18:00:00+07:00',
        resolved: true,
      );
      final otherDay = _trip(
        'otherDay',
        '2026-10-18T08:00:00+07:00',
        resolved: true,
      );
      final list = [dentist, dinner, otherDay];
      expect(previousEventFor(list, dinner)?.id, 'dentist');
      expect(previousEventFor(list, dentist), isNull);
    });

    test('ignores virtual, allDay, and unresolved preceding events', () {
      final virtualEvent = Trip(
        id: 'meet',
        titleTh: 'Online meeting',
        source: 'calendar',
        origin: const Place(nameTh: 'Home', lat: 13.72, lng: 100.53),
        destination: const Place(nameTh: 'Zoom', lat: 0, lng: 0),
        arriveBy: DateTime.parse('2026-10-17T09:00:00+07:00'),
        mode: TravelMode.car,
        virtual: true,
      );
      final unplaced = _trip(
        'unplaced',
        '2026-10-17T09:30:00+07:00',
        resolved: false,
      );
      final allDayEvent = Trip(
        id: 'holiday',
        titleTh: 'Holiday',
        source: 'calendar',
        origin: const Place(nameTh: 'Home', lat: 13.72, lng: 100.53),
        destination: const Place(nameTh: 'Beach', lat: 12.5, lng: 100.0),
        arriveBy: DateTime.parse('2026-10-17T08:00:00+07:00'),
        mode: TravelMode.car,
        allDay: true,
      );
      final dentist = _trip(
        'dentist',
        '2026-10-17T11:00:00+07:00',
        resolved: true,
      );
      final dinner = _trip(
        'dinner',
        '2026-10-17T18:00:00+07:00',
        resolved: true,
      );
      final list = [virtualEvent, unplaced, allDayEvent, dentist, dinner];
      expect(previousEventFor(list, dinner)?.id, 'dentist');
    });

    test('picks the closest preceding event when there are multiple', () {
      final e1 = _trip('e1', '2026-10-17T09:00:00+07:00');
      final e2 = _trip('e2', '2026-10-17T13:00:00+07:00');
      final e3 = _trip('e3', '2026-10-17T17:00:00+07:00');
      expect(previousEventFor([e1, e2, e3], e3)?.id, 'e2');
    });
  });

  group('event location customization & hybrid online meetings', () {
    test('online meeting with resolved destination is treated as onsite', () {
      final t = Trip.fromJson({
        'id': 'cal-hybrid',
        'title_th': 'Quarterly Review (Google Meet)',
        'source': 'calendar',
        'origin': {'name_th': 'บ้าน', 'lat': 13.81, 'lng': 100.59},
        'destination': {'name_th': 'ไบเทค บางนา', 'lat': 13.67, 'lng': 100.61},
        'arrive_by': '2026-10-17T10:00:00+07:00',
        'mode': 'car',
        'virtual': true,
      });
      expect(t.virtual, isFalse);
      expect(t.travels, isTrue);
      expect(t.destination.resolved, isTrue);
      expect(t.destination.nameTh, 'ไบเทค บางนา');
    });

    test('online meeting with unresolved physical location_text_th is onsite unresolved', () {
      final t = Trip.fromJson({
        'id': 'cal-hybrid-unres',
        'title_th': 'Workshop (Google Meet)',
        'source': 'calendar',
        'origin': {'name_th': 'บ้าน', 'lat': 13.81, 'lng': 100.59},
        'destination': {'name_th': 'อาคารลับ ชั้น 9'},
        'location_text_th': 'อาคารลับ ชั้น 9',
        'arrive_by': '2026-10-17T14:00:00+07:00',
        'mode': 'car',
        'virtual': true,
      });
      expect(t.virtual, isFalse);
      expect(t.unresolved, isTrue);
      expect(t.locationTextTh, 'อาคารลับ ชั้น 9');
    });

    test('pure online meeting without physical location stays virtual', () {
      final t = Trip.fromJson({
        'id': 'cal-pure-online',
        'title_th': 'Sprint planning',
        'source': 'calendar',
        'origin': {'name_th': 'บ้าน', 'lat': 13.81, 'lng': 100.59},
        'destination': {'name_th': 'ออนไลน์'},
        'arrive_by': '2026-10-17T10:00:00+07:00',
        'mode': 'car',
        'virtual': true,
      });
      expect(t.virtual, isTrue);
      expect(t.travels, isFalse);
    });

    test('inferPlaceQueryFromTitle extracts location from event title', () {
      expect(inferPlaceQueryFromTitle('นัดกินข้าวที่เซ็นทรัลเวิลด์'), 'เซ็นทรัลเวิลด์');
      expect(inferPlaceQueryFromTitle('ประชุมทีม @ สยามพารากอน'), 'สยามพารากอน');
      expect(inferPlaceQueryFromTitle('Dinner at Thonglor'), 'Thonglor');
      expect(inferPlaceQueryFromTitle('คุยเรื่องงบประมาณ'), isNull);
      expect(inferPlaceQueryFromTitle('Sprint planning'), isNull);
    });
  });
}

