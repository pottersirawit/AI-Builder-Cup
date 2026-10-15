import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'location.dart';
import 'models.dart';
import 'places.dart';

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

  static const _localeKey = 'language';
  static const supportedLocales = [Locale('th'), Locale('en')];

  Locale _locale = supportedLocales.first;

  /// The language of the whole app: its screens and the server's answers.
  Locale get locale => _locale;
  set locale(Locale l) {
    if (l == _locale) return;
    _locale = l;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString(_localeKey, l.languageCode))
        .ignore();
  }

  /// Restores the language chosen in an earlier session.
  Future<void> restoreLocale() async {
    final code = (await SharedPreferences.getInstance()).getString(_localeKey);
    final saved = supportedLocales.where((l) => l.languageCode == code);
    if (saved.isNotEmpty) _locale = saved.first;
  }

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

  HomeLevel _homeLevel = HomeLevel.normal;

  LocateResult? _currentLocation;

  /// The device's current location fix, when available.
  LocateResult? get currentLocation => _currentLocation;
  set currentLocation(LocateResult? loc) {
    if (loc == _currentLocation) return;
    _currentLocation = loc;
    notifyListeners();
  }

  /// Latest flood level at home; danger switches the whole app to flood mode.
  HomeLevel get homeLevel => _homeLevel;
  bool get flood => _homeLevel == HomeLevel.danger;
  set homeLevel(HomeLevel l) {
    if (l == _homeLevel) return;
    _homeLevel = l;
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

  /// Notification permission. Stubbed: the app has no notifications plugin
  /// yet, so this is only false when a demo preset stages the denied state.
  bool notificationsDenied = false;
}

/// Exposes [AppState], [PlacesStore], [Locator] and [FonTokMaiApi] to the
/// widget tree; dependents rebuild when state or places change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({
    super.key,
    required this.state,
    required this.places,
    required this.api,
    this.locator = const Locator(),
    required super.child,
  }) : super(notifier: Listenable.merge([state, places]));

  final AppState state;
  final PlacesStore places;
  final FonTokMaiApi api;
  final Locator locator;

  static AppScope _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static AppScope _read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  /// Watches state: rebuilds [context] when it changes.
  static AppState stateOf(BuildContext context) => _of(context).state;

  /// Reads state without subscribing; safe in initState and callbacks.
  static AppState readState(BuildContext context) => _read(context).state;

  /// Watches saved places and the profile.
  static PlacesStore placesOf(BuildContext context) => _of(context).places;
  static PlacesStore readPlaces(BuildContext context) => _read(context).places;
  static FonTokMaiApi apiOf(BuildContext context) => _read(context).api;
  static Locator locatorOf(BuildContext context) => _read(context).locator;
}
