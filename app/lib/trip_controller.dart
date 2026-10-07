import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_state.dart';
import 'departure.dart';
import 'models.dart';
import 'time_th.dart';

/// One trip's live answer: departure time, mode, the agent's decision, and
/// the on-device preview while the user drags the departure marker.
class TripController extends ChangeNotifier {
  TripController({
    required FonTokMaiApi api,
    required AppState state,
    required this.request,
    DateTime? departAt,
    TravelMode? mode,
  })  : _api = api,
        _state = state,
        _departAt = departAt ?? state.now(),
        _mode = mode ?? request.mode ?? state.mode;

  final FonTokMaiApi _api;
  final AppState _state;

  /// Trip id or Thai question; departure and mode are filled in here.
  final DecideRequest request;

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
    _loading = true;
    _error = null;
    _notify();
    try {
      final r = await _api.decide(request.copyWith(departAt: isoBangkok(_departAt), mode: _mode));
      if (seq != _seq || _disposed) return;
      _state.markSample(r.isSample);
      _decision = r.data;
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
