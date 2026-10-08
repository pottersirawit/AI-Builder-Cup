import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_state.dart';
import 'departure.dart';
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
  })  : _api = api,
        _state = state,
        _request = request,
        _departAt = departAt ?? state.now(),
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

  DateTime _departAt;
  DateTime get departAt => _departAt;

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
    return rankOptions(_previewing ? previewOptions(d, _departAt) : serverOptions(d, _departAt));
  }

  Departure? get selected => board.where((o) => o.mode == _mode).firstOrNull;

  String get headline {
    final d = _decision;
    if (d == null) return '';
    return _previewing ? previewHeadline(previewOptions(d, _departAt), _mode) : d.headlineTh;
  }

  Verdict? get verdict => _previewing ? selected?.verdict : _decision?.verdict;

  int get etaMin => selected?.etaMin ?? 0;

  SkyState sky({HomeLevel? home}) {
    final d = _decision;
    if (d == null) return home == HomeLevel.danger ? SkyState.flood : SkyState.clear;
    return skyFor(d.rainTimeline, _departAt, etaMin, verdict: verdict, home: home);
  }

  Future<void> load() async {
    final seq = ++_seq;
    final missing = _missingPlace();
    if (missing != null) {
      _needsPlace = NeedsPlace(queryTh: kindLabelTh(missing), kind: missing);
      _decision = null;
      _loading = false;
      _notify();
      return;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _api.decide(_request.copyWith(departAt: isoBangkok(_departAt), mode: _mode));
      if (seq != _seq || _disposed) return;
      _state.markSample(r.isSample);
      if (r.data.needsPlace != null) {
        _needsPlace = r.data.needsPlace;
        _decision = null;
      } else {
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
  }

  /// Moves the marker; shows the on-device preview until [commit].
  void drag(DateTime t) {
    if (t == _departAt && _previewing) return;
    _departAt = t;
    _previewing = _decision != null;
    _notify();
  }

  /// Settles the departure and asks the agent.
  Future<void> commit(DateTime t) {
    _departAt = t;
    _previewing = _decision != null;
    return load();
  }

  Future<void> setMode(TravelMode m) {
    if (m == _mode) return Future.value();
    _mode = m;
    return load();
  }

  /// "กลับบ้าน" before home is saved: known without asking the server.
  PlaceKind? _missingPlace() {
    final q = _request.questionTh;
    if (q == null || _request.tripId != null || _request.destination != null) return null;
    SavedPlace? of(PlaceKind k) => _request.places.where((p) => p.kind == k).firstOrNull;
    return missingPlaceFor(q, home: of(PlaceKind.home), work: of(PlaceKind.work));
  }

  /// Once the server names the trip it decided, moving the slider or mode
  /// re-asks about that trip rather than re-parsing the question. App-built
  /// trips (`app-…`) must carry their endpoints again.
  void _followUp(Trip? t) {
    if (t == null || t.id.isEmpty || _request.tripId != null) return;
    final app = t.id.startsWith('app-');
    _request = DecideRequest(
      tripId: t.id,
      origin: app ? t.origin : null,
      destination: app ? t.destination : null,
      places: _request.places,
    );
  }

  /// The user answered "where?": run the same question again, resolving
  /// against their updated places plus the answer.
  Future<void> resolvePlace(Place destination, List<SavedPlace> places) {
    final needs = _needsPlace;
    _request = _request.copyWith(
        places: needs == null ? places : placesWithAnswer(needs, destination, places));
    _needsPlace = null;
    _decision = null;
    return load();
  }

  /// Back to leaving now.
  Future<void> resetDeparture() => commit(_state.now());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
