// Data types for API contract v0 and its v1 places additions
// (docs/plan/merged-flow.md, docs/plan/places-and-empty-states.md).
// All wire parsing lives here, so a renamed field is a one-line change.

typedef Json = Map<String, dynamic>;

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _str(Object? v) => v as String? ?? '';
List<Json> _list(Object? v) => (v as List? ?? const []).cast<Json>();
List<String> _strList(Object? v) => (v as List? ?? const [])
    .map((e) => e?.toString() ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

/// Travel mode as named on the wire.
enum TravelMode {
  car('car'),
  transit('transit'),
  moto('moto');

  const TravelMode(this.wire);
  final String wire;

  static TravelMode parse(Object? v) =>
      values.firstWhere((m) => m.wire == v, orElse: () => car);
}

enum Verdict {
  leaveNow('leave_now'),
  wait('wait'),
  switchMode('switch_mode'),
  dontGo('dont_go');

  const Verdict(this.wire);
  final String wire;

  static Verdict parse(Object? v) =>
      values.firstWhere((x) => x.wire == v, orElse: () => wait);
}

enum Risk {
  low('low'),
  medium('medium'),
  high('high');

  const Risk(this.wire);
  final String wire;

  static Risk parse(Object? v) =>
      values.firstWhere((x) => x.wire == v, orElse: () => medium);
}

class Place {
  const Place({required this.nameTh, required this.lat, required this.lng});
  factory Place.fromJson(Json j) => Place(
    nameTh: _str(j['name_th']),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
  );
  final String nameTh;
  final double lat;
  final double lng;

  Json toJson() => {'name_th': nameTh, 'lat': lat, 'lng': lng};
}

class Trip {
  const Trip({
    required this.id,
    required this.titleTh,
    required this.source,
    required this.origin,
    required this.destination,
    required this.arriveBy,
    required this.mode,
    this.locationTextTh,
  });

  factory Trip.fromJson(Json j) {
    final dest = j['destination'] as Json?;
    final resolved = dest != null && dest['lat'] != null && dest['lng'] != null;
    final text =
        j['location_text_th'] as String? ?? j['location_th'] as String?;
    return Trip(
      id: _str(j['id']),
      titleTh: _str(j['title_th']),
      source: _str(j['source']),
      origin: Place.fromJson(j['origin'] as Json? ?? const {}),
      destination: resolved
          ? Place.fromJson(dest)
          : Place(nameTh: text ?? _str(dest?['name_th']), lat: 0, lng: 0),
      arriveBy: DateTime.tryParse(_str(j['arrive_by'])),
      mode: TravelMode.parse(j['mode']),
      locationTextTh: resolved ? null : (text ?? _str(dest?['name_th'])),
    );
  }

  static List<Trip> listFromJson(Json j) =>
      _list(j['trips']).map(Trip.fromJson).toList();

  final String id;
  final String titleTh;

  /// calendar | gmail | question | routine (the daily commute the app
  /// builds from saved home and work) | app
  final String source;
  final Place origin;
  final Place destination;

  /// Null when the trip has no deadline.
  final DateTime? arriveBy;
  final TravelMode mode;

  /// The event's location as written, when the server could not place it.
  final String? locationTextTh;
  bool get unresolved => locationTextTh != null;
}

class RainPoint {
  const RainPoint(this.time, this.mmPerHr);
  factory RainPoint.fromJson(Json j) =>
      RainPoint(DateTime.parse(_str(j['time'])), _num(j['mm_per_hr']));
  final DateTime time;
  final double mmPerHr;
}

class ModeOption {
  const ModeOption({
    required this.mode,
    required this.verdict,
    required this.etaMin,
    required this.risk,
    required this.noteTh,
  });
  factory ModeOption.fromJson(Json j) => ModeOption(
    mode: TravelMode.parse(j['mode']),
    verdict: Verdict.parse(j['verdict']),
    etaMin: _int(j['eta_min']),
    risk: Risk.parse(j['risk']),
    noteTh: _str(j['note_th']),
  );
  final TravelMode mode;
  final Verdict verdict;
  final int etaMin;
  final Risk risk;
  final String noteTh;
}

class FloodSpot {
  const FloodSpot({
    required this.id,
    required this.nameTh,
    required this.lat,
    required this.lng,
    required this.expectedDepthCm,
    required this.risk,
    this.distanceM,
  });
  factory FloodSpot.fromJson(Json j) => FloodSpot(
    id: _str(j['id']),
    nameTh: _str(j['name_th']),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
    expectedDepthCm: _num(j['expected_depth_cm']),
    // home-status spots carry their history instead of a risk.
    risk: j['risk'] == null && j['historical_max_depth_cm'] != null
        ? switch (_num(j['historical_max_depth_cm'])) {
            >= 30 => Risk.high,
            >= 10 => Risk.medium,
            _ => Risk.low,
          }
        : Risk.parse(j['risk']),
    distanceM: (j['distance_m'] as num?)?.toDouble(),
  );
  final String id;
  final String nameTh;
  final double lat;
  final double lng;
  final double expectedDepthCm;
  final Risk risk;

  /// From the asked point (home-status only).
  final double? distanceM;
}

class ReasoningStep {
  const ReasoningStep(this.tool, this.summaryTh);
  factory ReasoningStep.fromJson(Json j) =>
      ReasoningStep(_str(j['tool']), _str(j['summary_th']));
  final String tool;
  final String summaryTh;
}

class DecisionExplanation {
  const DecisionExplanation({
    required this.reasonWhyTh,
    required this.factorsTh,
    required this.routeAdviceTh,
    required this.avoidSpotsTh,
  });

  factory DecisionExplanation.fromJson(Json j) => DecisionExplanation(
    reasonWhyTh: _str(j['reason_why_th']),
    factorsTh: _strList(j['factors_th']),
    routeAdviceTh: _str(j['route_advice_th']),
    avoidSpotsTh: _strList(j['avoid_spots_th']),
  );

  final String reasonWhyTh;
  final List<String> factorsTh;
  final String routeAdviceTh;
  final List<String> avoidSpotsTh;

  bool get isEmpty =>
      reasonWhyTh.isEmpty &&
      factorsTh.isEmpty &&
      routeAdviceTh.isEmpty &&
      avoidSpotsTh.isEmpty;
}

/// Source line added when the trip starts at the phone's position; screens
/// swap it for localized text.
const gpsSourceLabel = 'GPS ตำแหน่งปัจจุบัน';

class Decision {
  const Decision({
    required this.verdict,
    required this.headlineTh,
    required this.summaryTh,
    required this.leaveBy,
    required this.confidence,
    required this.rainTimeline,
    required this.modeOptions,
    required this.floodSpots,
    required this.reasoning,
    required this.sources,
    required this.generatedBy,
    this.trip,
    this.needsPlace,
    this.explanation,
  });

  factory Decision.fromJson(Json j) {
    final rawSources = (j['sources'] as List? ?? const []).cast<String>();
    final trip = j['trip'] == null ? null : Trip.fromJson(j['trip'] as Json);
    final hasGpsOrigin =
        trip?.origin.nameTh.contains('ตำแหน่ง') == true ||
        (trip != null && trip.source == 'app');
    final sources = [
      if (hasGpsOrigin &&
          !rawSources.any((s) => s.contains('GPS') || s.contains('ตำแหน่ง')))
        gpsSourceLabel,
      ...rawSources,
    ];
    return Decision(
      verdict: Verdict.parse(j['verdict']),
      headlineTh: _str(j['headline_th']),
      summaryTh: _str(j['summary_th']),
      leaveBy: DateTime.tryParse(_str(j['leave_by'])),
      confidence: _num(j['confidence']),
      rainTimeline: _list(j['rain_timeline']).map(RainPoint.fromJson).toList(),
      modeOptions: _list(j['mode_options']).map(ModeOption.fromJson).toList(),
      floodSpots: _list(j['flood_spots']).map(FloodSpot.fromJson).toList(),
      reasoning: _list(j['reasoning']).map(ReasoningStep.fromJson).toList(),
      sources: sources,
      generatedBy: _str(j['generated_by']),
      trip: trip,
      needsPlace: j['needs_place'] == null
          ? null
          : NeedsPlace.fromJson(j['needs_place'] as Json),
      explanation: j['explanation'] == null
          ? null
          : DecisionExplanation.fromJson(j['explanation'] as Json),
    );
  }

  /// The server could not tell where the question goes; it asks instead of
  /// answering, and every verdict field is empty.
  factory Decision.asking(NeedsPlace n) => Decision(
    verdict: Verdict.wait,
    headlineTh: '',
    summaryTh: '',
    leaveBy: null,
    confidence: 0,
    rainTimeline: const [],
    modeOptions: const [],
    floodSpots: const [],
    reasoning: const [],
    sources: const [],
    generatedBy: '',
    needsPlace: n,
    explanation: null,
  );

  final Verdict verdict;
  final String headlineTh;
  final String summaryTh;
  final DateTime? leaveBy;

  /// 0..1
  final double confidence;
  final List<RainPoint> rainTimeline;
  final List<ModeOption> modeOptions;
  final List<FloodSpot> floodSpots;
  final List<ReasoningStep> reasoning;
  final List<String> sources;

  /// gemini | fallback
  final String generatedBy;

  /// The trip actually decided (additive), e.g. a question parsed into a trip.
  final Trip? trip;

  /// Set instead of a verdict when the question names no resolvable place.
  final NeedsPlace? needsPlace;

  /// Transparent explanation on why chosen, factors, and flood-avoidance route advice.
  final DecisionExplanation? explanation;
}

/// Body of POST /v1/decide. The main input is [tripId], an ad-hoc
/// [origin]/[destination] pair, or [questionTh]; [places] lets a question
/// resolve against the user's own places. The server ignores what it does
/// not need.
class DecideRequest {
  const DecideRequest({
    this.tripId,
    this.departAt,
    this.mode,
    this.questionTh,
    this.origin,
    this.destination,
    this.places = const [],
  });
  final String? tripId;

  /// Already formatted ISO-8601 with +07:00 offset.
  final String? departAt;
  final TravelMode? mode;
  final String? questionTh;
  final Place? origin;
  final Place? destination;
  final List<SavedPlace> places;

  DecideRequest copyWith({
    String? departAt,
    TravelMode? mode,
    Place? destination,
    List<SavedPlace>? places,
  }) => DecideRequest(
    tripId: tripId,
    departAt: departAt ?? this.departAt,
    mode: mode ?? this.mode,
    questionTh: questionTh,
    origin: origin,
    destination: destination ?? this.destination,
    places: places ?? this.places,
  );

  Json toJson() => {
    if (tripId != null) 'trip_id': tripId,
    if (departAt != null) 'depart_at': departAt,
    if (mode != null) 'mode': mode!.wire,
    if (questionTh != null) 'question_th': questionTh,
    if (origin != null) 'origin': origin!.toJson(),
    if (destination != null) 'destination': destination!.toJson(),
    if (places.isNotEmpty) 'places': [for (final p in places) p.toWire()],
  };
}

class FloodReport {
  const FloodReport({
    required this.id,
    required this.depthCmMin,
    required this.depthCmMax,
    required this.confidence,
    required this.descriptionTh,
    required this.passable,
    required this.notifiedUsers,
    required this.corroboratingReports,
  });

  factory FloodReport.fromJson(Json j) => FloodReport(
    id: _str(j['id']),
    depthCmMin: _int(j['depth_cm_min']),
    depthCmMax: _int(j['depth_cm_max']),
    confidence: _num(j['confidence']),
    descriptionTh: _str(j['description_th']),
    passable: (j['passable'] as Map? ?? const {}).map(
      (k, v) => MapEntry(TravelMode.parse(k), v as String),
    ),
    notifiedUsers: _int(j['notified_users']),
    corroboratingReports: _int(j['corroborating_reports']),
  );

  static List<FloodReport> listFromJson(Json j) =>
      _list(j['reports']).map(FloodReport.fromJson).toList();

  final String id;
  final int depthCmMin;
  final int depthCmMax;
  final double confidence;
  final String descriptionTh;

  /// yes | slow | no per mode.
  final Map<TravelMode, String> passable;
  final int notifiedUsers;
  final int corroboratingReports;
}

enum HomeLevel {
  normal('normal'),
  watch('watch'),
  danger('danger');

  const HomeLevel(this.wire);
  final String wire;

  static HomeLevel parse(Object? v) =>
      values.firstWhere((x) => x.wire == v, orElse: () => normal);
}

class Canal {
  const Canal({
    required this.nameTh,
    required this.levelM,
    required this.bankM,
    required this.riseCm2h,
  });
  factory Canal.fromJson(Json j) => Canal(
    nameTh: _str(j['name_th']),
    levelM: _num(j['level_m']),
    bankM: _num(j['bank_m']),
    riseCm2h: _num(j['rise_cm_2h']),
  );
  final String nameTh;
  final double levelM;
  final double bankM;
  final double riseCm2h;

  /// Water level as a fraction of the bank height, clamped to 0..1.
  double get fill => bankM <= 0 ? 0 : (levelM / bankM).clamp(0.0, 1.0);
}

class HomeAction {
  const HomeAction(this.order, this.textTh);
  factory HomeAction.fromJson(Json j) =>
      HomeAction(_int(j['order']), _str(j['text_th']));
  final int order;
  final String textTh;
}

class HomeStatus {
  const HomeStatus({
    required this.level,
    required this.headlineTh,
    required this.canal,
    required this.actions,
    required this.sources,
    this.summaryTh = '',
    this.inServiceArea = true,
    this.floodSpots = const [],
    this.reportsNearby,
    this.rainTodayMm,
  });

  factory HomeStatus.fromJson(Json j) {
    final actions = _list(j['actions']).map(HomeAction.fromJson).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return HomeStatus(
      level: HomeLevel.parse(j['level']),
      headlineTh: _str(j['headline_th']),
      canal: j['canal'] == null ? null : Canal.fromJson(j['canal'] as Json),
      actions: actions,
      sources: (j['sources'] as List? ?? const []).cast<String>(),
      summaryTh: _str(j['summary_th']),
      inServiceArea: j['in_service_area'] as bool? ?? true,
      floodSpots: _list(j['flood_spots']).map(FloodSpot.fromJson).toList(),
      reportsNearby: (j['reports_nearby'] as num?)?.toInt(),
      rainTodayMm: (j['rain_today_mm'] as num?)?.toDouble(),
    );
  }

  final HomeLevel level;
  final String headlineTh;
  final Canal? canal;

  /// Sorted by [HomeAction.order].
  final List<HomeAction> actions;
  final List<String> sources;
  final String summaryTh;

  /// False outside Bangkok: rain still works, flood spots and canals do not.
  final bool inServiceArea;

  /// BMA flood spots within 2 km of the point.
  final List<FloodSpot> floodSpots;

  /// Community reports within 500 m, when the server counts them.
  final int? reportsNearby;
  final double? rainTodayMm;
}

/// A connected account's state (Google Calendar).
enum LinkState { notConnected, connecting, connected, error }

enum PlaceKind {
  home('home'),
  work('work'),
  other('other');

  const PlaceKind(this.wire);
  final String wire;

  static PlaceKind parse(Object? v) =>
      values.firstWhere((k) => k.wire == v, orElse: () => other);
}

/// A place the user saved on this device. Sent with each request, never
/// stored on the server.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.kind,
    required this.labelTh,
    required this.nameTh,
    required this.lat,
    required this.lng,
    this.addressTh = '',
    this.icon = 'pin',
    this.days = defaultWorkDays,
    this.leaveTime = defaultLeaveTime,
  });

  factory SavedPlace.fromJson(Json j) => SavedPlace(
    id: _str(j['id']),
    kind: PlaceKind.parse(j['kind']),
    labelTh: _str(j['label_th']),
    nameTh: _str(j['name_th']),
    addressTh: _str(j['address_th']),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
    icon: j['icon'] as String? ?? 'pin',
    days: (j['days'] as List?)?.cast<int>() ?? defaultWorkDays,
    leaveTime: j['leave_time'] as String? ?? defaultLeaveTime,
  );

  /// ISO weekdays, Monday = 1.
  static const defaultWorkDays = [1, 2, 3, 4, 5];
  static const defaultLeaveTime = '18:00';

  final String id;
  final PlaceKind kind;

  /// What the user calls it: บ้าน, ที่ทำงาน, ยิม.
  final String labelTh;

  /// The resolved landmark or address.
  final String nameTh;
  final String addressTh;
  final double lat;
  final double lng;

  /// Icon key; see `placeIcon` in the design system.
  final String icon;

  /// Work days (work only).
  final List<int> days;

  /// Usual time to leave for home, HH:MM (work only).
  final String leaveTime;

  Place get asPlace =>
      Place(nameTh: labelTh.isEmpty ? nameTh : labelTh, lat: lat, lng: lng);

  SavedPlace copyWith({
    String? id,
    PlaceKind? kind,
    String? labelTh,
    String? nameTh,
    String? addressTh,
    double? lat,
    double? lng,
    String? icon,
    List<int>? days,
    String? leaveTime,
  }) => SavedPlace(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    labelTh: labelTh ?? this.labelTh,
    nameTh: nameTh ?? this.nameTh,
    addressTh: addressTh ?? this.addressTh,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    icon: icon ?? this.icon,
    days: days ?? this.days,
    leaveTime: leaveTime ?? this.leaveTime,
  );

  /// The `places` entry of POST /v1/decide.
  Json toWire() => {
    'id': id,
    'kind': kind.wire,
    'label_th': labelTh,
    'name_th': nameTh,
    'lat': lat,
    'lng': lng,
  };

  /// Everything, for on-device storage.
  Json toJson() => {
    ...toWire(),
    'address_th': addressTh,
    'icon': icon,
    if (kind == PlaceKind.work) 'days': days,
    if (kind == PlaceKind.work) 'leave_time': leaveTime,
  };
}

/// A search or reverse-geocode hit from `/v1/places/*`.
class PlaceCandidate {
  const PlaceCandidate({
    required this.nameTh,
    required this.lat,
    required this.lng,
    this.addressTh = '',
    this.nameEn,
    this.source = 'local',
    this.inServiceArea,
    this.accuracyM,
  });

  factory PlaceCandidate.fromJson(Json j) => PlaceCandidate(
    nameTh: _str(j['name_th']),
    nameEn: j['name_en'] as String?,
    addressTh: _str(j['address_th']),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
    source: j['source'] as String? ?? 'local',
    inServiceArea: j['in_service_area'] as bool?,
  );

  static List<PlaceCandidate> listFromJson(Json j) =>
      _list(j['places']).map(PlaceCandidate.fromJson).toList();

  final String nameTh;
  final String addressTh;

  /// English name (bundled landmarks only).
  final String? nameEn;
  final double lat;
  final double lng;

  /// google | local | gps
  final String source;
  final bool? inServiceArea;

  /// GPS accuracy radius in metres, for a "use my location" fix.
  final double? accuracyM;

  PlaceCandidate withAccuracy(double? m) => PlaceCandidate(
    nameTh: nameTh,
    addressTh: addressTh,
    nameEn: nameEn,
    lat: lat,
    lng: lng,
    source: source,
    inServiceArea: inServiceArea,
    accuracyM: m,
  );
}

/// `needs_place` from POST /v1/decide: the question's place is unknown.
class NeedsPlace {
  const NeedsPlace({
    required this.queryTh,
    this.kind,
    this.candidates = const [],
  });

  /// "บ้าน" / "ที่ทำงาน" for a missing home/work, else the asked words.
  factory NeedsPlace.fromJson(Json j) => NeedsPlace(
    queryTh: _str(j['query_th']),
    kind: j['kind'] == null ? null : PlaceKind.parse(j['kind']),
    candidates: _list(j['candidates']).map(PlaceCandidate.fromJson).toList(),
  );

  final String queryTh;

  /// home or work when the question named one the user has not saved.
  final PlaceKind? kind;
  final List<PlaceCandidate> candidates;
}
