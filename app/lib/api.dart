import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:http/http.dart' as http;

import 'events.dart' show bangkokDay;
import 'l10n/l10n.dart';
import 'models.dart';
import 'places.dart';

/// A response plus whether it came from the bundled sample fixtures because
/// the backend was unreachable.
class ApiResult<T> {
  const ApiResult(this.data, {required this.isSample});
  final T data;
  final bool isSample;
}

/// What the server knows about a Google sign-in.
class OAuthStatus {
  const OAuthStatus({
    required this.email,
    required this.connected,
    this.scopes = const [],
  });
  factory OAuthStatus.fromJson(Json j) => OAuthStatus(
    email: j['email'] as String? ?? '',
    connected: j['connected'] as bool? ?? false,
    scopes: (j['scopes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );
  final String email;
  final bool connected;
  final List<String> scopes;
}

/// Client for API contract v0 plus the v1 places additions. Calls fall back to
/// `assets/fixtures/*.json` when the backend fails, so the app always demos;
/// a real account's trips, plans and weather never do.
class FonTokMaiApi {
  FonTokMaiApi({
    required this.baseUrl,
    http.Client? client,
    AssetBundle? bundle,
    this.demoClock,
    this.language,
    this.allowSample,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client(),
       _bundle = bundle ?? rootBundle;

  final String baseUrl;
  final http.Client _client;
  final AssetBundle _bundle;
  final Duration timeout;

  /// Returns the current X-Demo-Clock value, or null for live mode.
  final String? Function()? demoClock;

  /// Returns the app language code (`th` or `en`) the server should answer in.
  final String Function()? language;

  /// Whether a failed plan or forecast may answer with มิว's sample day;
  /// only her demo profile may. Null allows it.
  final bool Function()? allowSample;

  bool get _sampleAllowed => allowSample?.call() ?? true;

  Map<String, String> get _headers {
    final clock = demoClock?.call();
    final lang = language?.call();
    return {
      'Accept': 'application/json',
      if (lang != null) 'Accept-Language': lang,
      if (clock != null) 'X-Demo-Clock': clock,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  /// The account's trips. With [sample] false a failure throws instead of
  /// answering with มิว's fixture trips.
  Future<ApiResult<List<Trip>>> trips({
    String? email,
    bool sample = true,
    SavedPlace? home,
  }) => _tripsFrom('/v1/trips', email, sample, {
    if (home != null && (home.lat != 0 || home.lng != 0)) ...{
      'home_lat': '${home.lat}',
      'home_lng': '${home.lng}',
      'home_name': home.nameTh.isNotEmpty ? home.nameTh : home.labelTh,
    },
  });

  /// Pulls Calendar and Gmail again, then the trips; see [trips]. Synced
  /// trips start from [home]; without it the server starts them downtown.
  Future<ApiResult<List<Trip>>> syncTrips({
    String? email,
    bool sample = true,
    SavedPlace? home,
  }) => _tripsFrom('/v1/trips/sync', email, sample, {
    if (home != null && (home.lat != 0 || home.lng != 0)) ...{
      'home_lat': '${home.lat}',
      'home_lng': '${home.lng}',
      'home_name': home.nameTh.isNotEmpty ? home.nameTh : home.labelTh,
    },
  });

  Future<ApiResult<List<Trip>>> _tripsFrom(
    String path,
    String? email,
    bool sample, [
    Map<String, String> extra = const {},
  ]) async {
    final query = {if (email != null && email.isNotEmpty) 'email': email, ...extra};
    Future<List<Trip>> live() async =>
        Trip.listFromJson(await _get(path, query.isEmpty ? null : query));
    return _withFallback(
      live,
      () async => Trip.listFromJson(await _fixture('trips')),
      sample: sample,
    );
  }

  /// Whether the sign-in started with [nonce] or for [email] has finished, and as whom.
  Future<OAuthStatus> oauthStatus({String? nonce, String? email}) async {
    final query = <String, String>{
      if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
      if (email != null && email.isNotEmpty) 'email': email,
    };
    return OAuthStatus.fromJson(await _get('/v1/oauth/status', query));
  }

  Future<ApiResult<Decision>> decide(DecideRequest req) => _withFallback(
    () async => Decision.fromJson(await _postJson('/v1/decide', req.toJson())),
    () async => Decision.fromJson(await _fixture(sampleDecisionName(req))),
    sample: _sampleAllowed,
  );

  /// The next 12 hours of weather at [lat],[lng]; without them, the
  /// server's demo home. The sample day is moved onto today when live.
  Future<ApiResult<Outlook>> outlook({double? lat, double? lng}) =>
      _withFallback(
        () async => Outlook.fromJson(
          await _get(
            '/v1/outlook',
            lat == null || lng == null ? null : {'lat': '$lat', 'lng': '$lng'},
          ),
        ),
        () async => sampleOutlook(
          Outlook.fromJson(await _fixture('outlook')),
          demoClock?.call() == null
              ? DateTime.now()
              : DateTime.tryParse(demoClock!.call()!) ?? DateTime.now(),
        ),
        sample: _sampleAllowed,
      );

  /// Flood status at [home]; without it, the server's demo home.
  Future<ApiResult<HomeStatus>> homeStatus({SavedPlace? home}) => _withFallback(
    () async => HomeStatus.fromJson(
      await _get(
        '/v1/home-status',
        home == null
            ? null
            : {
                'lat': '${home.lat}',
                'lng': '${home.lng}',
                'name_th': home.nameTh,
              },
      ),
    ),
    () async => HomeStatus.fromJson(
      await _fixture(
        sampleHomeStatusName(demoClock?.call(), lat: home?.lat, lng: home?.lng),
      ),
    ),
  );

  /// Places matching [q] (Thai or English). Offline: the bundled landmark
  /// list, marked `source: local`.
  Future<ApiResult<List<PlaceCandidate>>> searchPlaces(String q) =>
      _withFallback(
        () async => PlaceCandidate.listFromJson(
          await _get('/v1/places/search', {'q': q}),
        ),
        () async => searchLocal(await localLandmarks(), q),
      );

  /// What is at a point. Offline: the nearest bundled landmark.
  Future<ApiResult<PlaceCandidate>> reversePlace(double lat, double lng) =>
      _withFallback(
        () async => PlaceCandidate.fromJson(
          await _get('/v1/places/reverse', {'lat': '$lat', 'lng': '$lng'}),
        ),
        () async => reverseLocal(
          await localLandmarks(),
          lat,
          lng,
          lookupAppLocalizations(Locale(language?.call() ?? 'th')),
        ),
      );

  List<PlaceCandidate>? _landmarks;

  /// Bangkok landmarks bundled with the app (BTS/MRT stations, malls,
  /// districts, the demo places).
  Future<List<PlaceCandidate>> localLandmarks() async =>
      _landmarks ??= _landmarkList(await _fixture('places_local'));

  Future<ApiResult<FloodReport>> submitReport({
    required Uint8List photo,
    required String filename,
    required double lat,
    required double lng,
  }) => _withFallback(() async {
    final req = http.MultipartRequest('POST', _uri('/v1/reports'))
      ..headers.addAll(_headers)
      ..fields['lat'] = '$lat'
      ..fields['lng'] = '$lng'
      ..files.add(
        http.MultipartFile.fromBytes('photo', photo, filename: filename),
      );
    final res = await http.Response.fromStream(
      await _client.send(req).timeout(timeout),
    );
    return FloodReport.fromJson(_decode(res));
  }, () async => FloodReport.fromJson(await _fixture('report')));

  Future<ApiResult<List<FloodReport>>> reportsNear({
    required double lat,
    required double lng,
    int radiusM = 500,
  }) => _withFallback(
    () async => FloodReport.listFromJson(
      await _get('/v1/reports', {
        'lat': '$lat',
        'lng': '$lng',
        'radius_m': '$radiusM',
      }),
    ),
    () async => FloodReport.listFromJson(await _fixture('reports')),
  );

  Future<ApiResult<T>> _withFallback<T>(
    Future<T> Function() live,
    Future<T> Function() fixture, {
    bool sample = true,
  }) async {
    if (!sample) return ApiResult(await live(), isSample: false);
    try {
      return ApiResult(await live(), isSample: false);
    } catch (e) {
      debugPrint('fontokmai: backend unavailable ($e), using sample data');
      return ApiResult(await fixture(), isSample: true);
    }
  }

  Future<Json> _get(String path, [Map<String, String>? query]) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(timeout);
    return _decode(res);
  }

  Future<Json> _postJson(String path, Json body) async {
    final res = await _client
        .post(
          _uri(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(res);
  }

  Json _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('HTTP ${res.statusCode}', res.request?.url);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Json;
  }

  /// The bundled sample [name], in English when the app is (written by
  /// tool/fixtures_en.py). The landmarks have no twin: they serve search.
  Future<Json> _fixture(String name) async {
    final dir = language?.call() == 'en' && name != 'places_local'
        ? 'assets/fixtures/en'
        : 'assets/fixtures';
    return jsonDecode(await _bundle.loadString('$dir/$name.json')) as Json;
  }
}

List<PlaceCandidate> _landmarkList(Json j) => [
  for (final p in (j['places'] as List).cast<Json>())
    PlaceCandidate(
      nameTh: p['name_th'] as String,
      addressTh: p['address_th'] as String,
      nameEn: p['name_en'] as String?,
      lat: (p['lat'] as num).toDouble(),
      lng: (p['lng'] as num).toDouble(),
      source: 'local',
    ),
];

/// Case-insensitive match on name, address and English name; shorter names
/// first so "สยาม" outranks "สยามพารากอน".
@visibleForTesting
List<PlaceCandidate> searchLocal(List<PlaceCandidate> all, String q) {
  final needle = q.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final hits =
      all
          .where(
            (p) =>
                p.nameTh.toLowerCase().contains(needle) ||
                p.addressTh.toLowerCase().contains(needle) ||
                (p.nameEn?.toLowerCase().contains(needle) ?? false),
          )
          .toList()
        ..sort((a, b) {
          final an = a.nameTh.toLowerCase().contains(needle) ? 0 : 1;
          final bn = b.nameTh.toLowerCase().contains(needle) ? 0 : 1;
          return an != bn ? an - bn : a.nameTh.length - b.nameTh.length;
        });
  return hits.take(8).toList();
}

/// The nearest landmark within 1.5 km ("ใกล้…" beyond 150 m, as the
/// server's own fallback says it), else the bare coordinates, written in
/// [l]'s language. The landmarks have no English address, so English gives
/// the coordinates instead.
@visibleForTesting
PlaceCandidate reverseLocal(
  List<PlaceCandidate> all,
  double lat,
  double lng,
  AppLocalizations l,
) {
  PlaceCandidate? best;
  var bestD = double.infinity;
  for (final p in all) {
    final d = distanceM(lat, lng, p.lat, p.lng);
    if (d < bestD) {
      best = p;
      bestD = d;
    }
  }
  final inArea = inServiceArea(lat, lng);
  final coords = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  if (best == null || bestD > 1500) {
    return PlaceCandidate(
      nameTh: l.pickerPinnedSpot,
      addressTh: coords,
      lat: lat,
      lng: lng,
      inServiceArea: inArea,
    );
  }
  final name = l.isThai ? best.nameTh : best.nameEn ?? best.nameTh;
  final address = l.isThai ? best.addressTh : coords;
  return PlaceCandidate(
    nameTh: bestD > 150 ? l.pickerNearPlace(name) : name,
    addressTh: bestD > 150
        ? l.pickerAboutAway(address, (bestD / 50).round() * 50)
        : address,
    lat: lat,
    lng: lng,
    inServiceArea: inArea,
  );
}

/// Which bundled decision best matches [req], so the offline demo still
/// reacts to the slider and mode toggle the way the real agent would.
@visibleForTesting
String sampleDecisionName(DecideRequest req) {
  final q = req.questionTh;
  if (q != null && req.destination == null) {
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

/// Demo home (บ้านลาดพร้าว): the scripted canal fixtures only apply near it.
const _demoHome = (lat: 13.8160, lng: 100.5900);

@visibleForTesting
String sampleHomeStatusName(String? demoClock, {double? lat, double? lng}) {
  if (lat != null && lng != null) {
    if (!inServiceArea(lat, lng)) return 'home_status_outside';
    if (distanceM(lat, lng, _demoHome.lat, _demoHome.lng) > 3000)
      return 'home_status_nocanal';
  }
  final t = demoClock == null ? null : DateTime.tryParse(demoClock);
  if (t == null) return 'home_status_watch';
  final hour = t.toUtc().add(const Duration(hours: 7)).hour;
  return hour >= 21 ? 'home_status_danger' : 'home_status_watch';
}

/// The bundled weather day, re-dated onto [now]'s Bangkok date and cut to
/// the 12 hours from [now]'s hour.
@visibleForTesting
Outlook sampleOutlook(Outlook day, DateTime now) {
  final first = day.hours.first.time;
  final shift = bangkokDay(now).difference(bangkokDay(first));
  final hours = [
    for (final h in day.hours)
      if (!h.time.add(shift).add(const Duration(hours: 1)).isBefore(now))
        h.shifted(shift),
  ].take(12).toList();
  final all = hours.isEmpty ? [day.hours.last.shifted(shift)] : hours;
  return Outlook(
    now: all.first,
    hours: all,
    sunset: day.sunset?.add(shift),
    sources: day.sources,
  );
}
