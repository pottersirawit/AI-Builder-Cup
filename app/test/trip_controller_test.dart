import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/events.dart';
import 'package:fontokmai/models.dart';
import 'package:fontokmai/time_th.dart';
import 'package:fontokmai/trip_controller.dart';
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  test('the suggested leave time stays where the pin went when the ETA '
      'shifts on the re-check', () async {
    final departs = <String>[];
    // The first answer takes 91 min, the re-check at the new time 86.
    final api = FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        departs.add(body['depart_at'] as String);
        final eta = departs.length == 1 ? 91 : 86;
        return jsonResponse({
          'verdict': 'leave_now',
          'headline_th': 'ออกได้เลย',
          'mode_options': [
            {
              'mode': 'moto',
              'verdict': 'leave_now',
              'eta_min': eta,
              'risk': 'low',
            },
          ],
        });
      }),
    );
    final c = TripController(
      api: api,
      state: AppState(demoClock: '2026-09-29T18:15:00+07:00'),
      request: const DecideRequest(tripId: 'flight'),
      mode: TravelMode.moto,
      departAt: DateTime.parse('2026-09-30T20:10:00+07:00'),
      deadline: DateTime.parse('2026-09-30T23:10:00+07:00'),
    );
    await c.load();
    await pumpEventQueue();

    expect(departs.last, '2026-09-30T21:29:00+07:00');
    expect(c.etaMin, 86);
    final plan = c.plan!;
    expect(plan.kind, LeaveKind.before);
    expect(hhmm(plan.time!), hhmm(c.departAt));
    expect(hhmm(plan.arriveAt), '22:55');
  });
}
