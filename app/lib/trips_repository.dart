import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_state.dart';
import 'events.dart';
import 'models.dart';
import 'places.dart';
import 'time_th.dart';

/// The user's events and their departure answers, shared by the Summary and
/// Events tabs so each trip is loaded and decided once.
class TripsRepository extends ChangeNotifier {
  TripsRepository({
    required FonTokMaiApi api,
    required AppState state,
    required PlacesStore places,
  }) : _api = api,
       _state = state,
       _places = places;

  final FonTokMaiApi _api;
  final AppState _state;
  final PlacesStore _places;

  /// Rows further out than this get no leave-at answer: a forecast that far
  /// ahead is noise.
  static const decideAhead = Duration(hours: 24);

  List<Trip> _trips = const [];
  List<Trip> get trips => _trips;

  HomeStatus? _home;

  Outlook? _outlook;

  /// The next hours of weather where the user is; drives what to carry.
  Outlook? get outlook => _outlook;

  /// Flood status at the saved home; drives flood mode.
  HomeStatus? get home => _home;

  bool _loading = true;
  bool get loading => _loading;

  Object? _error;
  Object? get error => _error;

  final Map<String, Decision> _decisions = {};
  final Set<String> _deciding = {};
  int _seq = 0;
  bool _disposed = false;

  bool get connected =>
      _places.calendar == LinkState.connected ||
      _places.gmail == LinkState.connected;

  /// The account to read events for: Calendar's, else Gmail's.
  String? get account => _places.calendar == LinkState.connected
      ? _places.calendarAccount
      : (_places.gmail == LinkState.connected ? _places.gmailAccount : null);

  Decision? decisionFor(String tripId) => _decisions[tripId];

  /// The summary's controller answered; rows reuse its decision.
  void remember(String tripId, Decision d) {
    if (identical(_decisions[tripId], d)) return;
    _decisions[tripId] = d;
    _notify();
  }

  /// The request that plans [t] precisely: full trip plus identity.
  DecideRequest requestFor(Trip t) => DecideRequest(
    tripId: t.id,
    origin: t.origin,
    destination: t.destination,
    trip: t,
    email: account,
  );

  Future<void> refresh({bool sync = false}) async {
    final seq = ++_seq;
    _loading = true;
    _error = null;
    if (_trips.isEmpty && _places.cachedTrips.isNotEmpty && connected) {
      _trips = _places.cachedTrips;
    }
    _notify();
    final savedHome = _places.home;
    final homeF = savedHome == null
        ? null
        : _api.homeStatus(home: _places.demoProfile ? null : savedHome);
    final here = _state.currentLocation;
    final at = here != null && here.ok
        ? (lat: here.lat, lng: here.lng)
        : (savedHome == null || _places.demoProfile
              ? null
              : (lat: savedHome.lat, lng: savedHome.lng));
    final outlookF = _api.outlook(lat: at?.lat, lng: at?.lng);
    // Only มิว's demo profile may fill in with sample trips; a real account
    // shows the error and Retry instead.
    final demo = _places.demoProfile;
    Object? tripsError;
    ApiResult<List<Trip>>? tripsR;
    try {
      tripsR = !connected
          ? null
          : await (sync
                ? _api.syncTrips(
                    email: account,
                    sample: demo,
                    home: demo ? null : savedHome,
                  )
                : _api.trips(email: account, sample: demo));
    } catch (e) {
      tripsError = e;
    }
    try {
      final homeR = await homeF;
      final outlookR = await outlookF;
      if (seq != _seq || _disposed) return;
      _state
        ..markSample((tripsR?.isSample ?? false) || (homeR?.isSample ?? false))
        ..homeLevel = homeR?.data.level ?? HomeLevel.normal;
      final fresh = tripsR?.data ?? const <Trip>[];
      if (fresh.isNotEmpty && !tripsR!.isSample) _places.setCachedTrips(fresh);
      _trips = fresh.isNotEmpty
          ? fresh
          : (connected ? _places.cachedTrips : const []);
      _home = homeR?.data;
      _outlook = outlookR.data;
      _decisions.removeWhere((id, _) => !_trips.any((t) => t.id == id));
      _error = tripsError;
    } catch (e) {
      if (seq != _seq || _disposed) return;
      _error = e;
    }
    _loading = false;
    _notify();
  }

  /// Decides, one at a time, the events within [decideAhead] that have no
  /// answer yet. The next event is skipped: its controller decides it.
  Future<void> decideSoon() async {
    final now = _state.now();
    final next = nextEvent(_trips, now);
    final due = upcoming(_trips, now).where(
      (t) =>
          t.id != next?.id &&
          t.travels &&
          !t.unresolved &&
          t.arriveBy != null &&
          t.arriveBy!.difference(now) <= decideAhead &&
          !_decisions.containsKey(t.id) &&
          !_deciding.contains(t.id),
    );
    for (final t in due.toList()) {
      _deciding.add(t.id);
      try {
        final r = await _api.decide(
          requestFor(
            t,
          ).copyWith(departAt: isoBangkok(planDepartFor(t, now)), mode: t.mode),
        );
        if (_disposed) return;
        if (r.data.needsPlace == null) _decisions[t.id] = r.data;
        _notify();
      } catch (_) {
        // A row without an answer just shows no leave time.
      } finally {
        _deciding.remove(t.id);
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
