import 'package:flutter/widgets.dart';

import 'api.dart';
import 'models.dart';

/// App-wide state: demo clock, offline flag and local-only settings.
class AppState extends ChangeNotifier {
  AppState({String? demoClock}) : _demoClock = demoClock;

  String? _demoClock;

  /// X-Demo-Clock value (ISO-8601, +07:00), or null for live mode.
  String? get demoClock => _demoClock;
  set demoClock(String? v) {
    if (v == _demoClock) return;
    _demoClock = v;
    pushDismissed = false;
    notifyListeners();
  }

  /// "Now" as the app should show it: the demo clock when set.
  DateTime now() =>
      _demoClock == null ? DateTime.now() : DateTime.parse(_demoClock!);

  bool _usingSample = false;
  bool get usingSample => _usingSample;

  /// Records where the latest response came from; drives the sample badge.
  T track<T>(ApiResult<T> r) {
    markSample(r.isSample);
    return r.data;
  }

  void markSample(bool isSample) {
    if (isSample == _usingSample) return;
    _usingSample = isSample;
    notifyListeners();
  }

  bool pushDismissed = false;
  void dismissPush() {
    pushDismissed = true;
    notifyListeners();
  }

  TravelMode _mode = TravelMode.car;
  TravelMode get mode => _mode;
  set mode(TravelMode m) {
    _mode = m;
    notifyListeners();
  }

  /// Local-only toggles from the settings screen, keyed by setting id.
  final Map<String, bool> toggles = {
    'calendar': true,
    'gmail': true,
    'routine': false,
    'share_reports': true,
    'home_alerts': true,
    'sms_backup': true,
  };
  void setToggle(String key, bool v) {
    toggles[key] = v;
    notifyListeners();
  }
}

/// Exposes [AppState] and [FonTokMaiApi] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required this.api,
    required super.child,
  }) : super(notifier: state);

  final FonTokMaiApi api;

  static AppScope _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static AppScope _read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  /// Watches state: rebuilds [context] when it changes.
  static AppState stateOf(BuildContext context) => _of(context).notifier!;

  /// Reads state without subscribing; safe in initState and callbacks.
  static AppState readState(BuildContext context) => _read(context).notifier!;
  static FonTokMaiApi apiOf(BuildContext context) => _read(context).api;
}
