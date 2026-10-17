import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_state.dart';
import 'departure.dart';
import 'events.dart';
import 'l10n/l10n.dart';
import 'models.dart';
import 'places.dart';
import 'time_th.dart';

/// One trip's live answer: departure time, mode, the agent's decision, and
/// the on-device preview while the user drags the departure marker.
class TripController extends ChangeNotifier {
  TripController({
    required FonTokMaiApi api,
    required AppState state,
    required DecideRequest request,
    DateTime? departAt,
    TravelMode? mode,
    this.deadline,
  }) : _api = api,
       _state = state,
       _request = request,
       _departAt = departAt ?? state.now(),
       _plannedAt = departAt,
       _mode = mode ?? request.mode ?? state.mode;

  final FonTokMaiApi _api;
  final AppState _state;

  /// Trip id, origin/destination or Thai question; departure and mode are
  /// filled in here.
  DecideRequest get request => _request;
  DecideRequest _request;

  NeedsPlace? _needsPlace;

  /// The question names a place the app cannot find; ask the user instead.
  NeedsPlace? get needsPlace => _needsPlace;

  ActivityPlan? _askActivity;

  /// The question is about a day out with no place yet: what to bring, and
  /// "where and when?" before there is a trip to decide.
  ActivityPlan? get askActivity => _askActivity;

  DateTime _departAt;
  DateTime get departAt => _departAt;

  /// When the event starts, for a trip to one: the departure is planned
  /// back from it until the user picks a time.
  final DateTime? deadline;

  final DateTime? _plannedAt;

  bool _userSet = false;

  /// The user chose the departure (dragged, picked or reset it).
  bool get userSet => _userSet;

  bool _aligned = false;

  /// Where [_alignToPlan] put the marker. The re-asked answer can change the
  /// ETA and so the plan's time; the marker's time stays the one the page
  /// shows, so the headline, pin and segments agree.
  DateTime? _alignedAt;

  TravelMode _mode;
  TravelMode get mode => _mode;

  Decision? _decision;
  Decision? get decision => _decision;

  bool _loading = false;
  bool get loading => _loading;

  Object? _error;
  Object? get error => _error;

  bool _previewing = false;

  /// True while the marker is being dragged and the agent has not answered.
  bool get previewing => _previewing;

  int _seq = 0;
  bool _disposed = false;

  /// The marker cannot go before now.
  DateTime get earliest => _state.now();

  /// Every mode at the current departure, best first.
  List<Departure> get board {
    final d = _decision;
    if (d == null) return const [];
    return rankOptions(
      _previewing
          ? previewOptions(d, _departAt, _l)
          : serverOptions(d, _departAt),
    );
  }

  Departure? get selected => board.where((o) => o.mode == _mode).firstOrNull;

  String get headline {
    final d = _decision;
    if (d == null) return '';
    return _previewing
        ? previewHeadline(previewOptions(d, _departAt, _l), _mode, _l)
        : d.headlineTh;
  }

  AppLocalizations get _l => lookupAppLocalizations(_state.locale);

  Verdict? get verdict => _previewing ? selected?.verdict : _decision?.verdict;

  int get etaMin => selected?.etaMin ?? 0;

  /// The chosen mode at the chosen time can go and arrives on time.
  bool get selectedGoes {
    final s = selected;
    if (s == null) return true;
    return s.verdict == Verdict.leaveNow &&
        (deadline == null || !s.arriveAt.isAfter(deadline!));
  }

  /// Another mode that goes at this departure, when the chosen one cannot.
  Departure? get otherMode =>
      selectedGoes ? null : otherModeThatGoes(board, _mode, deadline: deadline);

  /// A later departure for the chosen mode that clears the rain, when the
  /// chosen time cannot go.
  Departure? get waitOut {
    final d = _decision;
    if (d == null || selectedGoes) return null;
    return nextGoodDeparture(d, _mode, _departAt, deadline: deadline, l: _l);
  }

  /// When to leave for the event, as its card says; null for a trip with no
  /// start time or while previewing.
  LeavePlan? get plan {
    final d = _decision;
    if (d == null || deadline == null || _previewing) return null;
    final p = leavePlan(d, board, _state.now(), deadline: deadline);
    if (_userSet ||
        _alignedAt != _departAt ||
        (p.kind != LeaveKind.before && p.kind != LeaveKind.at)) {
      return p;
    }
    return (
      kind: p.kind,
      time: _departAt,
      best: p.best,
      arriveAt: _departAt.add(Duration(minutes: etaMin)),
    );
  }

  SkyState sky({HomeLevel? home}) {
    final d = _decision;
    if (d == null)
      return home == HomeLevel.danger ? SkyState.flood : SkyState.clear;
    return skyFor(
      d.rainTimeline,
      _departAt,
      etaMin,
      verdict: verdict,
      home: home,
    );
  }

  Future<void> load() async {
    final seq = ++_seq;
    final missing = _missingPlace();
    if (missing != null) {
      _needsPlace = NeedsPlace(queryTh: kindLabel(_l, missing), kind: missing);
      _decision = null;
      _loading = false;
      _notify();
      return;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _api.decide(
        _request.copyWith(departAt: isoBangkok(_departAt), mode: _mode),
      );
      if (seq != _seq || _disposed) return;
      _state.markSample(r.isSample);
      if (r.data.needsPlace != null) {
        _needsPlace = r.data.needsPlace;
        _decision = null;
      } else if (r.data.asksWhere) {
        _askActivity = r.data.activity;
        _needsPlace = null;
        _decision = null;
      } else {
        _askActivity = null;
        _needsPlace = null;
        _decision = r.data;
        _followUp(r.data.trip);
      }
      _previewing = false;
    } catch (e) {
      if (seq != _seq || _disposed) return;
      _error = e;
    }
    _loading = false;
    _notify();
    _alignToPlan();
  }

  /// The first answer is for the planning window's start, hours early; move
  /// the marker to the plan's leave time once so the pass and the band agree.
  void _alignToPlan() {
    if (_aligned || _userSet || _decision == null) return;
    _aligned = true;
    // Leaving now is already a valid answer to "leave before …".
    if (_departAt.difference(_state.now()).inMinutes < 5) return;
    final p = plan;
    final t = p?.time;
    if (t == null || (p!.kind != LeaveKind.before && p.kind != LeaveKind.at)) {
      return;
    }
    if (!t.isAfter(_state.now()) ||
        t.difference(_departAt).inMinutes.abs() < 10) {
      return;
    }
    _departAt = t;
    _alignedAt = t;
    load();
  }

  /// Moves the marker; shows the on-device preview until [commit].
  void drag(DateTime t) {
    if (t == _departAt && _previewing) return;
    _userSet = true;
    _departAt = t;
    _previewing = _decision != null;
    _notify();
  }

  /// Settles the departure and asks the agent.
  Future<void> commit(DateTime t) {
    _userSet = true;
    _departAt = t.isBefore(earliest) ? earliest : t;
    _previewing = _decision != null;
    return load();
  }

  Place get origin =>
      _request.origin ??
      _request.trip?.origin ??
      _decision?.trip?.origin ??
      const Place(nameTh: '', lat: 0, lng: 0);

  Future<void> setOrigin(Place newOrigin) {
    if (newOrigin.lat == origin.lat &&
        newOrigin.lng == origin.lng &&
        newOrigin.nameTh == origin.nameTh) {
      return Future.value();
    }
    _request = _request.copyWith(
      origin: newOrigin,
      trip: _request.trip?.copyWith(origin: newOrigin),
    );
    return load();
  }

  void invalidateDecision() {
    _decision = null;
    _notify();
  }

  Future<void> setMode(TravelMode m) {
    if (m == _mode) return Future.value();
    _mode = m;
    _decision = null;
    return load();
  }

  /// "กลับบ้าน" before home is saved: known without asking the server.
  PlaceKind? _missingPlace() {
    final q = _request.questionTh;
    if (q == null || _request.tripId != null || _request.destination != null)
      return null;
    SavedPlace? of(PlaceKind k) =>
        _request.places.where((p) => p.kind == k).firstOrNull;
    return missingPlaceFor(
      q,
      home: of(PlaceKind.home),
      work: of(PlaceKind.work),
    );
  }

  /// Once the server names the trip it decided, moving the slider or mode
  /// re-asks about that trip rather than re-parsing the question. App-built
  /// trips (`app-…`) must carry their endpoints again.
  void _followUp(Trip? t) {
    if (t == null || t.id.isEmpty || _request.tripId != null) return;
    final app = t.id.startsWith('app-');
    _request = DecideRequest(
      tripId: t.id,
      origin: app ? t.origin : _request.origin,
      destination: app ? t.destination : _request.destination,
      places: _request.places,
      trip: _request.trip,
      email: _request.email,
      activity: _request.activity ?? _decision?.activity?.activity,
    );
  }

  /// The user said where and when the day out is: decide the trip there,
  /// leaving at seven that morning, or now when it is today.
  Future<void> planActivity({
    required Activity activity,
    required Place origin,
    required Place destination,
    required DateTime day,
  }) {
    final now = _state.now();
    final morning = bangkokAt(day, 7, 0);
    _request = DecideRequest(
      questionTh: _request.questionTh,
      origin: origin,
      destination: destination,
      places: _request.places,
      email: _request.email,
      activity: activity.withDay(isoDay(day)),
    );
    _departAt = morning.isAfter(now) ? morning : now;
    _askActivity = null;
    _decision = null;
    return load();
  }

  /// The user answered "where?": run the same question again, resolving
  /// against their updated places plus the answer.
  Future<void> resolvePlace(Place destination, List<SavedPlace> places) {
    final needs = _needsPlace;
    _request = _request.copyWith(
      places: needs == null
          ? places
          : placesWithAnswer(needs, destination, places),
    );
    _needsPlace = null;
    _decision = null;
    return load();
  }

  /// Back to leaving now.
  Future<void> resetDeparture() => commit(_state.now());

  /// Leave early enough to arrive at [t].
  Future<void> arriveAt(DateTime t) =>
      commit(t.subtract(Duration(minutes: etaMin)));

  /// Back to the event's suggested leave time.
  Future<void> useSuggested() {
    _userSet = false;
    _aligned = false;
    _alignedAt = null;
    _departAt = _plannedAt ?? _state.now();
    if (_departAt.isBefore(earliest)) _departAt = earliest;
    return load();
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
