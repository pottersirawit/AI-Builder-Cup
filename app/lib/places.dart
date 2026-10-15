import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/l10n.dart';
import 'models.dart';
import 'time_th.dart';

/// Bangkok and its edges: flood spots and canal stations exist only here.
const serviceArea = (south: 13.49, north: 14.10, west: 100.30, east: 100.95);

bool inServiceArea(double lat, double lng) =>
    lat >= serviceArea.south &&
    lat <= serviceArea.north &&
    lng >= serviceArea.west &&
    lng <= serviceArea.east;

/// Great-circle distance in metres.
double distanceM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

extension SavedPlaceGeo on SavedPlace {
  bool get inArea => inServiceArea(lat, lng);
  double distanceTo(double lat2, double lng2) =>
      distanceM(lat, lng, lat2, lng2);
}

/// Why [PlacesStore.save] refused a place.
enum SaveRefusal { tooManyOthers }

/// The user's saved places and first-run profile, kept on this device with
/// shared_preferences. One home, one work, up to [maxOthers] others; the
/// server never stores any of it.
class PlacesStore extends ChangeNotifier {
  PlacesStore(this._prefs) {
    _read();
  }

  /// Loads the device store; a first launch with the demo clock set starts
  /// in มิว's demo profile so the scripted video still works.
  static Future<PlacesStore> open({required bool demoByDefault}) async {
    final store = PlacesStore(await SharedPreferences.getInstance());
    if (!store._initialized && demoByDefault) store.useDemoProfile();
    return store;
  }

  static const maxOthers = 8;
  static const duplicateRadiusM = 150.0;

  static const _kPlaces = 'places.v1';
  static const _kOnboarded = 'profile.onboarded';
  static const _kDemo = 'profile.demo';
  static const _kCalendarHint = 'profile.calendar_hint_dismissed';
  static const _kLocationAsked = 'profile.location_asked';
  static const _kManualLocation = 'profile.manual_location';

  final SharedPreferences _prefs;

  List<SavedPlace> _places = [];
  PlaceCandidate? _manualLocation;
  bool _onboarded = false;
  bool _demo = false;
  bool _calendarHintDismissed = false;
  bool _locationAsked = false;
  LinkState _calendar = LinkState.notConnected;

  bool get _initialized => _prefs.containsKey(_kOnboarded);

  void _read() {
    final raw = _prefs.getString(_kPlaces);
    if (raw != null) {
      try {
        _places = (jsonDecode(raw) as List)
            .cast<Json>()
            .map(SavedPlace.fromJson)
            .toList();
      } catch (_) {
        _places = [];
      }
    }
    final rawLoc = _prefs.getString(_kManualLocation);
    if (rawLoc != null) {
      try {
        final j = jsonDecode(rawLoc) as Map<String, dynamic>;
        _manualLocation = PlaceCandidate(
          nameTh: j['name_th'] as String? ?? 'ตำแหน่งที่ปักหมุด',
          addressTh: j['address_th'] as String? ?? '',
          lat: (j['lat'] as num).toDouble(),
          lng: (j['lng'] as num).toDouble(),
          source: 'manual',
        );
      } catch (_) {
        _manualLocation = null;
      }
    } else {
      _manualLocation = null;
    }
    _onboarded = _prefs.getBool(_kOnboarded) ?? false;
    _demo = _prefs.getBool(_kDemo) ?? false;
    _calendarHintDismissed = _prefs.getBool(_kCalendarHint) ?? false;
    _locationAsked = _prefs.getBool(_kLocationAsked) ?? false;
    _calendar = _demo ? LinkState.connected : LinkState.notConnected;
  }

  void _write() {
    _prefs.setString(
      _kPlaces,
      jsonEncode([for (final p in _places) p.toJson()]),
    );
    _prefs.setBool(_kOnboarded, _onboarded);
    _prefs.setBool(_kDemo, _demo);
    _prefs.setBool(_kCalendarHint, _calendarHintDismissed);
    _prefs.setBool(_kLocationAsked, _locationAsked);
    notifyListeners();
  }

  PlaceCandidate? get manualLocation => _manualLocation;

  void setManualLocation(PlaceCandidate? c) {
    _manualLocation = c;
    if (c == null) {
      _prefs.remove(_kManualLocation);
    } else {
      _prefs.setString(
        _kManualLocation,
        jsonEncode({
          'name_th': c.nameTh,
          'address_th': c.addressTh,
          'lat': c.lat,
          'lng': c.lng,
        }),
      );
    }
    notifyListeners();
  }

  List<SavedPlace> get places => List.unmodifiable(_places);
  SavedPlace? get home =>
      _places.where((p) => p.kind == PlaceKind.home).firstOrNull;
  SavedPlace? get work =>
      _places.where((p) => p.kind == PlaceKind.work).firstOrNull;
  List<SavedPlace> get others =>
      _places.where((p) => p.kind == PlaceKind.other).toList();
  SavedPlace? byId(String id) => _places.where((p) => p.id == id).firstOrNull;

  bool get canAddOther => others.length < maxOthers;

  /// Home and work within [duplicateRadiusM]: the commute is skipped.
  bool get workFromHome {
    final h = home, w = work;
    return h != null &&
        w != null &&
        h.distanceTo(w.lat, w.lng) <= duplicateRadiusM;
  }

  /// The saved place within [duplicateRadiusM] of a point, nearest first.
  /// Home and work never count as duplicates of each other (working from
  /// home is allowed), so [forKind] skips the other one of the pair.
  SavedPlace? duplicateOf(
    double lat,
    double lng, {
    String? exceptId,
    PlaceKind? forKind,
  }) {
    SavedPlace? best;
    var bestD = double.infinity;
    for (final p in _places) {
      if (p.id == exceptId) continue;
      if (forKind != null &&
          forKind != PlaceKind.other &&
          p.kind != PlaceKind.other &&
          p.kind != forKind) {
        continue;
      }
      final d = p.distanceTo(lat, lng);
      if (d <= duplicateRadiusM && d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  String newId() =>
      'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  /// Adds or replaces [p]. A home or work replaces the current one of that
  /// kind; anything else replaces the place with the same id. Returns why it
  /// refused, or null when saved.
  SaveRefusal? save(SavedPlace p) {
    final same = _places.indexWhere((x) => x.id == p.id);
    final sameKind = p.kind == PlaceKind.other
        ? -1
        : _places.indexWhere((x) => x.kind == p.kind);
    if (same >= 0) {
      _places[same] = p;
      if (sameKind >= 0 && sameKind != same) _places.removeAt(sameKind);
    } else if (sameKind >= 0) {
      _places[sameKind] = p;
    } else {
      if (p.kind == PlaceKind.other && !canAddOther)
        return SaveRefusal.tooManyOthers;
      _places.add(p);
    }
    _write();
    return null;
  }

  /// Removes a place; keep the result to undo with [restore].
  ({SavedPlace place, int index})? remove(String id) {
    final i = _places.indexWhere((p) => p.id == id);
    if (i < 0) return null;
    final p = _places.removeAt(i);
    _write();
    return (place: p, index: i);
  }

  void restore(SavedPlace p, int index) {
    if (_places.any((x) => x.id == p.id)) return;
    if (p.kind != PlaceKind.other && _places.any((x) => x.kind == p.kind))
      return;
    _places.insert(index.clamp(0, _places.length), p);
    _write();
  }

  bool get onboarded => _onboarded;
  void completeOnboarding() {
    _onboarded = true;
    _write();
  }

  bool get demoProfile => _demo;

  /// มิว's places, as in the scripted demo; Calendar counts as connected.
  void useDemoProfile() {
    _places = [...demoPlaces];
    _demo = true;
    _onboarded = true;
    _calendar = LinkState.connected;
    _calendarHintDismissed = false;
    _write();
  }

  /// Back to a first launch: no places, onboarding shows again.
  void resetToFirstRun() {
    _places = [];
    _manualLocation = null;
    _prefs.remove(_kManualLocation);
    _demo = false;
    _onboarded = false;
    _calendar = LinkState.notConnected;
    _calendarHintDismissed = false;
    _locationAsked = false;
    _write();
  }

  bool get calendarHintDismissed => _calendarHintDismissed;
  void dismissCalendarHint() {
    _calendarHintDismissed = true;
    _write();
  }

  /// The OS location prompt has been shown once; never loop it.
  bool get locationAsked => _locationAsked;
  void markLocationAsked() {
    if (_locationAsked) return;
    _locationAsked = true;
    _write();
  }

  LinkState get calendar => _calendar;

  /// Synthetic demo account; labelled as such wherever it is shown.
  String get calendarAccount => 'miw.demo@gmail.com';

  /// OAuth is stubbed: only the demo profile can connect.
  bool get canConnectCalendar => _demo;

  Future<void> connectCalendar({
    Duration delay = const Duration(milliseconds: 1200),
  }) async {
    if (!canConnectCalendar || _calendar == LinkState.connecting) return;
    _calendar = LinkState.connecting;
    notifyListeners();
    await Future<void>.delayed(delay);
    _calendar = LinkState.connected;
    notifyListeners();
  }

  void disconnectCalendar() {
    _calendar = LinkState.notConnected;
    notifyListeners();
  }

  @visibleForTesting
  set calendarForTest(LinkState v) {
    _calendar = v;
    notifyListeners();
  }
}

/// มิว's saved places (synthetic demo persona).
const demoPlaces = [
  SavedPlace(
    id: 'home',
    kind: PlaceKind.home,
    labelTh: 'บ้าน',
    nameTh: 'บ้านลาดพร้าว',
    addressTh: 'ซอยลาดพร้าว 32 · ใกล้คลองลาดพร้าว',
    lat: 13.8160,
    lng: 100.5900,
    icon: 'home',
  ),
  SavedPlace(
    id: 'work',
    kind: PlaceKind.work,
    labelTh: 'ที่ทำงาน',
    nameTh: 'สีลม ซอย 3',
    addressTh: 'ถ.สีลม แขวงสุริยวงศ์ เขตบางรัก',
    lat: 13.7263,
    lng: 100.5340,
    icon: 'work',
  ),
  SavedPlace(
    id: 'siam',
    kind: PlaceKind.other,
    labelTh: 'สยาม',
    nameTh: 'สยาม',
    addressTh: 'ถ.พระรามที่ 1 เขตปทุมวัน',
    lat: 13.7456,
    lng: 100.5341,
    icon: 'shop',
  ),
  SavedPlace(
    id: 'thonglor',
    kind: PlaceKind.other,
    labelTh: 'ทองหล่อ',
    nameTh: 'ทองหล่อ',
    addressTh: 'สุขุมวิท 55 เขตวัฒนา',
    lat: 13.7243,
    lng: 100.5853,
    icon: 'food',
  ),
  SavedPlace(
    id: 'impact',
    kind: PlaceKind.other,
    labelTh: 'อิมแพ็ค',
    nameTh: 'อิมแพ็ค เมืองทองธานี',
    addressTh: 'ถ.แจ้งวัฒนะ ปากเกร็ด นนทบุรี',
    lat: 13.9119,
    lng: 100.5480,
    icon: 'stadium',
  ),
];

/// The daily trip home the app builds from saved places.
class CommutePlan {
  const CommutePlan({
    required this.trip,
    required this.departAt,
    required this.fromCurrentLocation,
  });
  final Trip trip;
  final DateTime departAt;

  /// No work saved: the trip starts wherever the phone is when asked.
  final bool fromCurrentLocation;
}

/// Today's trip home, or null when there is none: no home, working from
/// home, not a work day, or long past the usual leave time.
CommutePlan? commuteFor({
  SavedPlace? home,
  SavedPlace? work,
  required DateTime now,
}) {
  if (home == null) return null;
  if (work != null &&
      home.distanceTo(work.lat, work.lng) <= PlacesStore.duplicateRadiusM)
    return null;
  final b = toBangkok(now);
  final days = work?.days ?? SavedPlace.defaultWorkDays;
  if (!days.contains(b.weekday)) return null;
  final hm = (work?.leaveTime ?? SavedPlace.defaultLeaveTime).split(':');
  final leaveAt = DateTime.utc(
    b.year,
    b.month,
    b.day,
    int.parse(hm[0]),
    int.parse(hm[1]),
  ).subtract(const Duration(hours: 7));
  if (now.isAfter(leaveAt.add(const Duration(hours: 4)))) return null;
  final fromHere = work == null;
  return CommutePlan(
    departAt: now.isAfter(leaveAt) ? now : leaveAt,
    fromCurrentLocation: fromHere,
    trip: Trip(
      id: 'routine-home',
      titleTh: 'กลับบ้าน',
      source: 'routine',
      origin:
          work?.asPlace ?? const Place(nameTh: 'ตำแหน่งตอนนี้', lat: 0, lng: 0),
      destination: home.asPlace,
      arriveBy: null,
      mode: TravelMode.car,
    ),
  );
}

/// A question that names home or work before the user saved it: ask for the
/// place instead of guessing.
PlaceKind? missingPlaceFor(
  String question, {
  SavedPlace? home,
  SavedPlace? work,
}) {
  if (home == null && question.contains('บ้าน')) return PlaceKind.home;
  if (work == null &&
      RegExp(
        'ที่ทำงาน|ไปทำงาน|ออฟฟิศ|office',
        caseSensitive: false,
      ).hasMatch(question)) {
    return PlaceKind.work;
  }
  return null;
}

/// The user's places plus their answer to "where?", so the same question
/// resolves on the server (a destination without an origin is refused).
/// A saved home/work or an already-saved spot needs nothing extra; a picked
/// candidate rides along as a transient place labelled with the asked words.
List<SavedPlace> placesWithAnswer(
  NeedsPlace needs,
  Place answer,
  List<SavedPlace> places,
) {
  if (needs.kind == PlaceKind.home || needs.kind == PlaceKind.work)
    return places;
  final known = places.any(
    (p) =>
        p.labelTh == needs.queryTh &&
        distanceM(p.lat, p.lng, answer.lat, answer.lng) <=
            PlacesStore.duplicateRadiusM,
  );
  if (known) return places;
  return [
    ...places,
    SavedPlace(
      id: 'answer',
      kind: PlaceKind.other,
      labelTh: needs.queryTh,
      nameTh: answer.nameTh,
      lat: answer.lat,
      lng: answer.lng,
    ),
  ];
}

String kindLabelTh(PlaceKind k) => switch (k) {
  PlaceKind.home => 'บ้าน',
  PlaceKind.work => 'ที่ทำงาน',
  PlaceKind.other => 'สถานที่',
};

String kindLabel(AppLocalizations l, PlaceKind k) => switch (k) {
  PlaceKind.home => l.placeKindHome,
  PlaceKind.work => l.placeKindWork,
  PlaceKind.other => l.placeKindOther,
};

extension SavedPlaceLabel on SavedPlace {
  /// The label as shown: a default Thai label the app invented (บ้าน, สยาม, …)
  /// follows the app language; anything the user typed shows as typed.
  String labelFor(AppLocalizations l) => switch (labelTh) {
    'บ้าน' when kind == PlaceKind.home => l.placeKindHome,
    'ที่ทำงาน' when kind == PlaceKind.work => l.placeKindWork,
    'สถานที่' when kind == PlaceKind.other => l.placeKindOther,
    'สยาม' when id == 'siam' => l.placeDemoSiam,
    'ทองหล่อ' when id == 'thonglor' => l.placeDemoThonglor,
    'อิมแพ็ค' when id == 'impact' => l.placeDemoImpact,
    _ => labelTh,
  };
}
