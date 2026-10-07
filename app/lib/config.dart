import 'package:flutter/foundation.dart';

const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

/// `--dart-define=DEMO_CLOCK=16:10` picks the starting demo time; `live`
/// starts with no X-Demo-Clock header.
const _demoClockDefine = String.fromEnvironment('DEMO_CLOCK', defaultValue: '16:10');

/// Android emulators reach the host machine at 10.0.2.2, not localhost.
String resolveApiBaseUrl() {
  if (_apiBaseUrlDefine.isNotEmpty) return _apiBaseUrlDefine;
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return android ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
}

/// Scenario day of the demo: Tuesday 29 September 2026, Bangkok time.
const demoDate = '2026-09-29';
const demoPresets = ['16:10', '18:52', '21:40'];

/// ISO-8601 string with Bangkok offset for [hhmm] on the demo day.
String demoClockIso(String hhmm) => '${demoDate}T$hhmm:00+07:00';

String? initialDemoClock() {
  if (_demoClockDefine == 'live' || _demoClockDefine.isEmpty) return null;
  return demoClockIso(_demoClockDefine);
}
