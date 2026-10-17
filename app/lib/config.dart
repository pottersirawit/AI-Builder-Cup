import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

const _defaultApiBaseUrl = 'https://fontokmai-api-lmr33aj5zq-as.a.run.app';
const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl);

/// `--dart-define=DEMO_CLOCK=16:10` picks the starting demo time; `live`
/// starts with no X-Demo-Clock header.
const _demoClockDefine = String.fromEnvironment('DEMO_CLOCK', defaultValue: 'live');
const _demoScreenDefine = String.fromEnvironment('DEMO_SCREEN');

/// Launch environment (Android/desktop), or the matching --dart-define.
String? _env(String key) {
  if (kIsWeb) return null;
  final v = Platform.environment[key];
  return v == null || v.isEmpty ? null : v;
}

/// Android emulators reach the host machine at 10.0.2.2, not localhost.
String resolveApiBaseUrl() {
  final env = _env('API_BASE_URL');
  if (env != null) return env;
  if (_apiBaseUrlDefine.isNotEmpty) return _apiBaseUrlDefine;
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return android ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
}

/// Moments of the storm day the server replays: its weather is keyed by
/// time of day, so the demo runs on today's date against the real calendar.
const demoPresets = ['16:10', '18:52', '21:40'];

/// ISO-8601 string with Bangkok offset for [hhmm] on today's Bangkok date.
String demoClockIso(String hhmm, {DateTime? now}) {
  final b = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${b.year}-${two(b.month)}-${two(b.day)}T$hhmm:00+07:00';
}

String? initialDemoClock() {
  final v = _env('DEMO_CLOCK') ?? _demoClockDefine;
  if (v == 'live' || v.isEmpty) return null;
  return demoClockIso(v);
}

/// Screen to open on launch for demo recording and screenshots, from
/// `--dart-define=DEMO_SCREEN=…` or the DEMO_SCREEN environment variable: `verdict@18:00/moto`, `report`,
/// `report_result`, `home_tab`, `ask`, `settings`, `gallery`, and the first-run states
/// [firstRunScreens].
class DemoLaunch {
  const DemoLaunch({required this.screen, this.departHhmm, this.mode});
  final String screen;
  final String? departHhmm;
  final String? mode;

  static DemoLaunch? fromEnvironment() {
    final v = _env('DEMO_SCREEN') ?? (_demoScreenDefine.isEmpty ? null : _demoScreenDefine);
    if (v == null) return null;
    final m = RegExp(r'^(\w+)(?:@(\d\d:\d\d))?(?:/(\w+))?$').firstMatch(v);
    if (m == null) return null;
    return DemoLaunch(screen: m[1]!, departHhmm: m[2], mode: m[3]);
  }
}

/// DEMO_SCREEN presets that start from a fresh install instead of มิว's
/// demo profile: `onboarding` shows the first-run screen; the rest have
/// skipped it with nothing saved.
const firstRunScreens = {
  'onboarding',
  'empty_home',
  'place_search',
  'place_confirm',
  'flood_nohome',
  'location_denied',
};
