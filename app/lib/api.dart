import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A response plus whether it came from the bundled sample fixtures because
/// the backend was unreachable.
class ApiResult<T> {
  const ApiResult(this.data, {required this.isSample});
  final T data;
  final bool isSample;
}

/// Client for API contract v0. Every call falls back to
/// `assets/fixtures/*.json` when the backend fails, so the app always demos.
class FonTokMaiApi {
  FonTokMaiApi({
    required this.baseUrl,
    http.Client? client,
    AssetBundle? bundle,
    this.demoClock,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _bundle = bundle ?? rootBundle;

  final String baseUrl;
  final http.Client _client;
  final AssetBundle _bundle;
  final Duration timeout;

  /// Returns the current X-Demo-Clock value, or null for live mode.
  final String? Function()? demoClock;

  Map<String, String> get _headers {
    final clock = demoClock?.call();
    return {
      'Accept': 'application/json',
      if (clock != null) 'X-Demo-Clock': clock,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<ApiResult<List<Trip>>> trips() => _withFallback(
        () async => Trip.listFromJson(await _get('/v1/trips')),
        () async => Trip.listFromJson(await _fixture('trips')),
      );

  Future<ApiResult<Decision>> decide(DecideRequest req) => _withFallback(
        () async => Decision.fromJson(await _postJson('/v1/decide', req.toJson())),
        () async => Decision.fromJson(await _fixture(sampleDecisionName(req))),
      );

  Future<ApiResult<HomeStatus>> homeStatus() => _withFallback(
        () async => HomeStatus.fromJson(await _get('/v1/home-status')),
        () async => HomeStatus.fromJson(await _fixture(sampleHomeStatusName(demoClock?.call()))),
      );

  Future<ApiResult<FloodReport>> submitReport({
    required Uint8List photo,
    required String filename,
    required double lat,
    required double lng,
  }) =>
      _withFallback(
        () async {
          final req = http.MultipartRequest('POST', _uri('/v1/reports'))
            ..headers.addAll(_headers)
            ..fields['lat'] = '$lat'
            ..fields['lng'] = '$lng'
            ..files.add(http.MultipartFile.fromBytes('photo', photo, filename: filename));
          final res = await http.Response.fromStream(await _client.send(req).timeout(timeout));
          return FloodReport.fromJson(_decode(res));
        },
        () async => FloodReport.fromJson(await _fixture('report')),
      );

  Future<ApiResult<List<FloodReport>>> reportsNear({
    required double lat,
    required double lng,
    int radiusM = 500,
  }) =>
      _withFallback(
        () async => FloodReport.listFromJson(await _get(
            '/v1/reports', {'lat': '$lat', 'lng': '$lng', 'radius_m': '$radiusM'})),
        () async => FloodReport.listFromJson(await _fixture('reports')),
      );

  Future<ApiResult<T>> _withFallback<T>(
    Future<T> Function() live,
    Future<T> Function() sample,
  ) async {
    try {
      return ApiResult(await live(), isSample: false);
    } catch (e) {
      debugPrint('fontokmai: backend unavailable ($e), using sample data');
      return ApiResult(await sample(), isSample: true);
    }
  }

  Future<Json> _get(String path, [Map<String, String>? query]) async {
    final res = await _client.get(_uri(path, query), headers: _headers).timeout(timeout);
    return _decode(res);
  }

  Future<Json> _postJson(String path, Json body) async {
    final res = await _client
        .post(_uri(path),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(timeout);
    return _decode(res);
  }

  Json _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('HTTP ${res.statusCode}', res.request?.url);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Json;
  }

  Future<Json> _fixture(String name) async =>
      jsonDecode(await _bundle.loadString('assets/fixtures/$name.json')) as Json;
}

/// Which bundled decision best matches [req], so the offline demo still
/// reacts to the slider and mode toggle the way the real agent would.
@visibleForTesting
String sampleDecisionName(DecideRequest req) {
  final q = req.questionTh;
  if (q != null) {
    if (RegExp('BTS|MRT|รถไฟฟ้า', caseSensitive: false).hasMatch(q)) {
      return 'decide_transit';
    }
    return 'decide_question';
  }
  final mode = req.mode ?? TravelMode.car;
  if (mode == TravelMode.transit) return 'decide_transit';
  final depart = req.departAt == null ? null : DateTime.tryParse(req.departAt!);
  final stormy = depart != null && _inStormWindow(depart);
  final base = mode == TravelMode.moto ? 'decide_moto' : 'decide_car';
  return stormy ? '${base}_storm' : base;
}

/// Heavy rain and road water on the demo route: 17:15 to 19:59 Bangkok time.
bool _inStormWindow(DateTime t) {
  final b = t.toUtc().add(const Duration(hours: 7));
  final minutes = b.hour * 60 + b.minute;
  return minutes >= 17 * 60 + 15 && minutes < 20 * 60;
}

@visibleForTesting
String sampleHomeStatusName(String? demoClock) {
  final t = demoClock == null ? null : DateTime.tryParse(demoClock);
  if (t == null) return 'home_status_watch';
  final hour = t.toUtc().add(const Duration(hours: 7)).hour;
  return hour >= 21 ? 'home_status_danger' : 'home_status_watch';
}
