import 'dart:async';

import 'package:clock/clock.dart';
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
  List<Trip> get trips =>
      _trips.where((t) => !_places.isTripDismissed(t.id)).toList();

  /// Events the user hid that are still upcoming.
  List<Trip> dismissedTrips(DateTime now) => upcoming(
    _trips.where((t) => _places.isTripDismissed(t.id)).toList(),
    now,
  );

  void dismissTrip(String tripId) {
    _places.dismissTrip(tripId);
    _notify();
  }

  void restoreTrip(String tripId) {
    _places.restoreTrip(tripId);
    _notify();
  }

  void restoreAllTrips() {
    _places.restoreAllTrips();
    _notify();
  }

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

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  @visibleForTesting
  set lastSyncTimeForTest(DateTime? t) => _lastSyncTime = t;

  final Map<String, Decision> _decisions = {};
  final Set<String> _deciding = {};

  /// Trips [decideSoon] found no answer for; nothing is on its way.
  final Set<String> _unanswered = {};
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

  /// A leave answer for [t] is on its way, so its row can hold the space.
  bool awaitsDecision(Trip t, DateTime now) =>
      t.travels &&
      !t.unresolved &&
      !t.inferredPlace &&
      t.arriveBy!.difference(now) <= decideAhead &&
      !_decisions.containsKey(t.id) &&
      !_unanswered.contains(t.id);

  /// The summary's controller answered; rows reuse its decision.
  void remember(String tripId, Decision d) {
    if (identical(_decisions[tripId], d)) return;
    _decisions[tripId] = d;
    _notify();
  }

  /// Saves and persists a confirmed [destination] onto [trip] (including
  /// all-day events and hybrid online meetings).
  Future<Trip> saveTripDestination(Trip trip, Place destination) async {
    final updated = trip.copyWith(
      destination: destination,
      clearLocationTextTh: true,
      virtual: false,
      inferredPlace: false,
    );
    _places.setTripPlace(trip.id, destination);
    _trips = [
      for (final t in _trips)
        if (t.id == trip.id) updated else t,
    ];
    _decisions.remove(trip.id);
    _unanswered.remove(trip.id);
    _notify();
    unawaited(_syncSavedTripToServer(updated));
    unawaited(decideSoon());
    return updated;
  }

  Future<void> _syncSavedTripToServer(Trip updated) async {
    if (!updated.destination.resolved) return;
    final now = _state.now();
    try {
      final r = await _api.decide(
        requestFor(updated).copyWith(
          departAt: isoBangkok(planDepartFor(updated, now)),
          mode: updated.mode,
        ),
      );
      if (_disposed) return;
      if (r.data.needsPlace == null) {
        _decisions[updated.id] = r.data;
        _notify();
      }
    } catch (_) {}
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
      _trips = [for (final t in _places.cachedTrips) _applySavedPlace(t)];
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
    // Caught now: it can fail while the trips are still loading.
    final outlookF = _api
        .outlook(lat: at?.lat, lng: at?.lng)
        .then<ApiResult<Outlook>?>((r) => r, onError: (_) => null);
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
                : _api.trips(
                    email: account,
                    sample: demo,
                    home: demo ? null : savedHome,
                  ));
    } catch (e) {
      tripsError = e;
    }
    // Weather and the home's flood status stand on their own: the page
    // keeps them when the events fail, and keeps the last ones when they do.
    ApiResult<HomeStatus>? homeR;
    try {
      homeR = await homeF;
    } catch (_) {}
    final outlookR = await outlookF;
    if (seq != _seq || _disposed) return;
    _state.markSample(
      (tripsR?.isSample ?? false) || (homeR?.isSample ?? false),
    );
    if (homeF == null || homeR != null) {
      _state.homeLevel = homeR?.data.level ?? HomeLevel.normal;
      _home = homeR?.data;
    }
    var fresh = [
      for (final t in (tripsR?.data ?? const <Trip>[])) _applySavedPlace(t),
    ];
    if (fresh.isNotEmpty) {
      fresh = await _inferMissingPlaces(fresh);
      if (seq != _seq || _disposed) return;
    }
    if (fresh.isNotEmpty && !demo) {
      fresh = _chainTrips(fresh);
      if (savedHome != null) {
        fresh = [for (final t in fresh) _withHomeOrigin(t, savedHome)];
      }
    }
    if (tripsR != null && !tripsR.isSample) {
      if (sync) _lastSyncTime = clock.now();
      _places.setCachedTrips(fresh);
    }
    final rawCached = [
      for (final t in _places.cachedTrips) _applySavedPlace(t),
    ];
    final chainedCached = demo ? rawCached : _chainTrips(rawCached);
    final cached = savedHome == null || demo
        ? chainedCached
        : [for (final t in chainedCached) _withHomeOrigin(t, savedHome)];
    _trips = tripsR != null && !tripsR.isSample
        ? fresh
        : (fresh.isNotEmpty ? fresh : (connected ? cached : const []));
    _outlook = outlookR?.data ?? _outlook;
    _decisions.removeWhere((id, _) => !_trips.any((t) => t.id == id));
    _error = tripsError;
    _loading = false;
    _notify();
  }

  Trip _applySavedPlace(Trip t) {
    final saved = _places.tripPlace(t.id);
    if (saved != null && saved.resolved) {
      return t.copyWith(
        destination: saved,
        clearLocationTextTh: true,
        virtual: false,
        inferredPlace: false,
      );
    }
    return t;
  }

  Future<List<Trip>> _inferMissingPlaces(List<Trip> list) async {
    final out = <Trip>[];
    for (final t in list) {
      if (t.destination.resolved || _places.tripPlace(t.id) != null) {
        out.add(t);
        continue;
      }
      final q = inferPlaceQueryFromTitle(t.titleTh);
      if (q == null) {
        out.add(t);
        continue;
      }
      final inferred = await _resolveInferredPlace(q);
      if (inferred != null) {
        out.add(
          t.copyWith(
            destination: inferred,
            clearLocationTextTh: true,
            virtual: false,
            inferredPlace: true,
          ),
        );
      } else {
        out.add(t);
      }
    }
    return out;
  }

  Future<Place?> _resolveInferredPlace(String query) async {
    final lower = query.toLowerCase();
    for (final sp in _places.places) {
      if (sp.kind == PlaceKind.home) continue;
      final name = sp.nameTh.toLowerCase();
      final label = sp.labelTh.toLowerCase();
      if ((name.isNotEmpty && lower.contains(name)) ||
          (label.isNotEmpty && lower.contains(label))) {
        return sp.asPlace;
      }
    }
    try {
      final res = await _api.searchPlaces(query);
      for (final c in res.data) {
        if (c.lat != 0 || c.lng != 0) {
          return Place(nameTh: c.nameTh, lat: c.lat, lng: c.lng);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Decides, one at a time, the events within [decideAhead] that have no
  /// answer yet. The next event is skipped: its controller decides it.
  Future<void> decideSoon() async {
    final now = _state.now();
    final current = trips;
    final next = nextEvent(current, now);
    final due = upcoming(current, now).where(
      (t) =>
          t.id != next?.id &&
          t.travels &&
          !t.unresolved &&
          !t.inferredPlace &&
          t.arriveBy != null &&
          t.arriveBy!.difference(now) <= decideAhead &&
          !_decisions.containsKey(t.id) &&
          !_deciding.contains(t.id),
    );
    for (final t in due.toList()) {
      _deciding.add(t.id);
      _unanswered.remove(t.id);
      try {
        final r = await _api.decide(
          requestFor(
            t,
          ).copyWith(departAt: isoBangkok(planDepartFor(t, now)), mode: t.mode),
        );
        if (_disposed) return;
        if (r.data.needsPlace == null) {
          _decisions[t.id] = r.data;
        } else {
          _unanswered.add(t.id);
        }
        _notify();
      } catch (_) {
        // A row without an answer just shows no leave time.
        _unanswered.add(t.id);
        _notify();
      } finally {
        _deciding.remove(t.id);
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<Trip> _chainTrips(List<Trip> list) {
    final out = <Trip>[];
    for (final t in list) {
      if (t.origin.isPlaceholder) {
        final prev = previousEventFor(out, t);
        if (prev != null && prev.destination.resolved) {
          out.add(t.copyWith(origin: prev.destination));
          continue;
        }
      }
      out.add(t);
    }
    return out;
  }

  Trip _withHomeOrigin(Trip t, SavedPlace home) {
    if ((t.source == 'calendar' || t.source == 'gmail') &&
        t.origin.isPlaceholder &&
        (t.destination.lat != home.lat || t.destination.lng != home.lng)) {
      final homeOrigin = Place(
        nameTh: home.nameTh.isNotEmpty ? home.nameTh : home.labelTh,
        lat: home.lat,
        lng: home.lng,
      );
      return t.copyWith(origin: homeOrigin);
    }
    return t;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
