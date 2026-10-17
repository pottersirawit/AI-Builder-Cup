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

  bool get resolved => !(lat == 0 && lng == 0);

  bool get isPlaceholder =>
      !resolved ||
      nameTh.contains('ยังไม่ได้ตั้งบ้าน') ||
      nameTh.contains('สีลม');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place &&
          runtimeType == other.runtimeType &&
          nameTh == other.nameTh &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(nameTh, lat, lng);

  Json toJson() => {'name_th': nameTh, 'lat': lat, 'lng': lng};
}

const _onlineLocationMarkers = [
  'ออนไลน์',
  'online',
  'meet.google.com',
  'zoom.us',
  'teams.microsoft.com',
  'google meet',
  'zoom',
  'teams',
];

bool _isOnlineLocationText(String? raw) {
  if (raw == null) return false;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return false;
  if (s.startsWith('http://') || s.startsWith('https://')) return true;
  for (final m in _onlineLocationMarkers) {
    if (s == m || s.contains(m)) return true;
  }
  return false;
}

const _titleLocationSplitters = [
  ' ที่ ',
  'ที่',
  ' แถว ',
  'แถว',
  ' ณ ',
  ' @ ',
  '@',
  ' at ',
  ' in ',
];

/// Infers a candidate location query from an event title (e.g.
/// "นัดกินข้าวที่เซ็นทรัลเวิลด์" -> "เซ็นทรัลเวิลด์"), or null when none is found.
String? inferPlaceQueryFromTitle(String title) {
  final lower = title.toLowerCase();
  for (final sep in _titleLocationSplitters) {
    final idx = lower.lastIndexOf(sep);
    if (idx >= 0) {
      var candidate = title.substring(idx + sep.length).trim();
      candidate = candidate.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
      if (candidate.isNotEmpty && !_isOnlineLocationText(candidate)) {
        return candidate;
      }
    }
  }
  return null;
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
    this.endsAt,
    this.virtual = false,
    this.allDay = false,
    this.inferredPlace = false,
  });

  Trip copyWith({
    String? id,
    String? titleTh,
    String? source,
    Place? origin,
    Place? destination,
    DateTime? arriveBy,
    TravelMode? mode,
    String? locationTextTh,
    bool clearLocationTextTh = false,
    DateTime? endsAt,
    bool? virtual,
    bool? allDay,
    bool? inferredPlace,
  }) => Trip(
    id: id ?? this.id,
    titleTh: titleTh ?? this.titleTh,
    source: source ?? this.source,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    arriveBy: arriveBy ?? this.arriveBy,
    mode: mode ?? this.mode,
    locationTextTh: clearLocationTextTh
        ? null
        : (locationTextTh ?? this.locationTextTh),
    endsAt: endsAt ?? this.endsAt,
    virtual: virtual ?? this.virtual,
    allDay: allDay ?? this.allDay,
    inferredPlace: inferredPlace ?? this.inferredPlace,
  );

  factory Trip.fromJson(Json j) {
    final dest = j['destination'] as Json?;
    final rawVirtual = j['virtual'] == true;
    final allDay = j['all_day'] == true;
    final inferredPlace = j['inferred_place'] == true;
    // (0, 0) is how an unplaced trip comes back from the device cache.
    final resolved =
        dest != null &&
        dest['lat'] != null &&
        dest['lng'] != null &&
        !(_num(dest['lat']) == 0 && _num(dest['lng']) == 0);
    final text =
        j['location_text_th'] as String? ?? j['location_th'] as String?;
    final destName = _str(dest?['name_th']).trim();
    final hasPhysicalLocationText =
        (text != null &&
            text.trim().isNotEmpty &&
            !_isOnlineLocationText(text)) ||
        (destName.isNotEmpty && !_isOnlineLocationText(destName));
    // Online meeting with both a Meet link (virtual: true) and a physical
    // location is treated as onsite.
    final virtual = rawVirtual && !resolved && !hasPhysicalLocationText;
    final hasLocationText =
        (text != null && text.trim().isNotEmpty) || destName.isNotEmpty;
    final placeless = !resolved && !virtual && (!allDay || hasLocationText);
    final unplacedText = text ?? (destName.isNotEmpty ? destName : null);
    return Trip(
      id: _str(j['id']),
      titleTh: _str(j['title_th']),
      source: _str(j['source']),
      origin: Place.fromJson(j['origin'] as Json? ?? const {}),
      destination: resolved
          ? Place.fromJson(dest)
          : Place(nameTh: unplacedText ?? '', lat: 0, lng: 0),
      arriveBy: DateTime.tryParse(_str(j['arrive_by'])),
      mode: TravelMode.parse(j['mode']),
      locationTextTh: placeless ? unplacedText : null,
      endsAt: DateTime.tryParse(_str(j['ends_at'])),
      virtual: virtual,
      allDay: allDay,
      inferredPlace: inferredPlace,
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

  /// When the event ends; Gmail bookings often have none.
  final DateTime? endsAt;

  /// An online meeting: nothing to travel to.
  final bool virtual;

  /// An all-day event (a holiday, a trip day): not a departure.
  final bool allDay;

  /// Whether [destination] was inferred by AI from [titleTh] and awaits confirmation.
  final bool inferredPlace;

  /// Whether this event means going somewhere at a time.
  bool get travels => !virtual && !allDay && arriveBy != null;

  /// Whether a destination place or label was specified.
  bool get hasDestination =>
      destination.nameTh.isNotEmpty || destination.resolved;

  Json toJson() => {
    'id': id,
    'title_th': titleTh,
    'source': source,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    if (arriveBy != null) 'arrive_by': arriveBy!.toIso8601String(),
    'mode': mode.wire,
    if (locationTextTh != null) 'location_text_th': locationTextTh,
    if (endsAt != null) 'ends_at': endsAt!.toIso8601String(),
    if (virtual) 'virtual': true,
    if (allDay) 'all_day': true,
    if (inferredPlace) 'inferred_place': true,
  };
}

class RainPoint {
  const RainPoint(this.time, this.mmPerHr, [this.probPct = 0]);
  factory RainPoint.fromJson(Json j) => RainPoint(
        DateTime.parse(_str(j['time'])),
        _num(j['mm_per_hr']),
        (j['prob_pct'] as num?)?.toInt() ?? 0,
      );
  final DateTime time;
  final double mmPerHr;
  final int probPct;
}

class TransitLeg {
  const TransitLeg({
    required this.lineTh,
    required this.fromStationTh,
    required this.toStationTh,
    this.stopCount = 0,
  });

  factory TransitLeg.fromJson(Json j) => TransitLeg(
    lineTh: _str(j['line_th']),
    fromStationTh: _str(j['from_station_th']),
    toStationTh: _str(j['to_station_th']),
    stopCount: _int(j['stop_count']),
  );

  final String lineTh;
  final String fromStationTh;
  final String toStationTh;
  final int stopCount;
}

class ModeOption {
  const ModeOption({
    required this.mode,
    required this.verdict,
    required this.etaMin,
    required this.risk,
    required this.noteTh,
    this.rainProbPct = 0,
    this.viaTh = const [],
    this.transitLegs = const [],
  });
  factory ModeOption.fromJson(Json j) => ModeOption(
    mode: TravelMode.parse(j['mode']),
    verdict: Verdict.parse(j['verdict']),
    etaMin: _int(j['eta_min']),
    risk: Risk.parse(j['risk']),
    noteTh: _str(j['note_th']),
    rainProbPct: (j['rain_prob_pct'] as num?)?.toInt() ?? 0,
    viaTh: _strList(j['via_th']),
    transitLegs: _list(j['transit_legs']).map(TransitLeg.fromJson).toList(),
  );
  final TravelMode mode;
  final Verdict verdict;
  final int etaMin;
  final Risk risk;
  final int rainProbPct;
  final String noteTh;
  final List<String> viaTh;
  final List<TransitLeg> transitLegs;
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
    this.emergencyContacts = const [],
    this.refused = false,
    this.activity,
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
      emergencyContacts: (j['emergency_contacts'] as List? ?? const [])
          .map((c) => EmergencyContact.fromJson(c as Json))
          .toList(),
      refused: j['refused'] == true,
      activity: j['activity'] == null
          ? null
          : ActivityPlan.fromJson(j['activity'] as Json),
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
    refused: false,
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

  /// Official emergency hotlines during severe flood and weather hazards.
  final List<EmergencyContact> emergencyContacts;

  /// True when the question was rejected by guardrails (unrelated to travel/trip).
  final bool refused;

  /// What to prepare for the day out the question is about. Without a
  /// verdict ([asksWhere]) it is the whole answer: a checklist and "where?".
  final ActivityPlan? activity;

  bool get asksWhere => activity?.asksWhere == true;

  /// An answer with nothing to show: no verdict text, no ways to travel and
  /// no question back. Never drawn as an empty pass.
  bool get unreadable =>
      !refused &&
      !asksWhere &&
      needsPlace == null &&
      headlineTh.isEmpty &&
      modeOptions.isEmpty;
}

/// A day out the user is preparing for ("ไปปีนผา"), sent back with the next
/// question so a "where?" answer stays about it.
class Activity {
  const Activity({required this.kind, this.nameTh = '', this.day});

  factory Activity.fromJson(Json j) => Activity(
    kind: _str(j['kind']),
    nameTh: _str(j['name_th']),
    day: j['day'] == null || _str(j['day']).isEmpty ? null : _str(j['day']),
  );

  /// climbing, camping, hiking, beach, cycling, running or other.
  final String kind;
  final String nameTh;

  /// Bangkok date, YYYY-MM-DD.
  final String? day;

  Activity withDay(String? day) => Activity(kind: kind, nameTh: nameTh, day: day);

  Json toJson() => {
    'kind': kind,
    if (nameTh.isNotEmpty) 'name_th': nameTh,
    if (day != null) 'day': day,
  };
}

class ChecklistItem {
  const ChecklistItem({required this.itemTh, this.whyTh = ''});
  factory ChecklistItem.fromJson(Json j) =>
      ChecklistItem(itemTh: _str(j['item_th']), whyTh: _str(j['why_th']));
  final String itemTh;
  final String whyTh;
}

/// One day's weather at a place, for days past the hourly outlook.
class DayForecast {
  const DayForecast({
    required this.day,
    required this.maxC,
    required this.minC,
    required this.feelsMaxC,
    required this.feelsMinC,
    required this.rainProbPct,
    this.thunderProbPct = 0,
    this.uvIndex = 0,
    this.condition = '',
    this.conditionTh = '',
  });

  factory DayForecast.fromJson(Json j) => DayForecast(
    day: DateTime.parse(_str(j['day'])),
    maxC: _num(j['max_c']),
    minC: _num(j['min_c']),
    feelsMaxC: _num(j['feels_max_c']),
    feelsMinC: _num(j['feels_min_c']),
    rainProbPct: _int(j['rain_prob_pct']),
    thunderProbPct: _int(j['thunder_prob_pct']),
    uvIndex: _int(j['uv_index']),
    condition: _str(j['condition']),
    conditionTh: _str(j['condition_th']),
  );

  final DateTime day;
  final double maxC;
  final double minC;
  final double feelsMaxC;
  final double feelsMinC;
  final int rainProbPct;
  final int thunderProbPct;
  final int uvIndex;
  final String condition;
  final String conditionTh;
}

/// What to prepare for an activity: a checklist, the day's weather notes at
/// its place, and, before the place is known, the question back.
class ActivityPlan {
  const ActivityPlan({
    required this.activity,
    required this.headlineTh,
    required this.checklist,
    this.weatherNotesTh = const [],
    this.forecast,
    this.placeTh = '',
    this.askTh = '',
    this.suggestionsTh = const [],
    this.generatedBy = '',
  });

  factory ActivityPlan.fromJson(Json j) => ActivityPlan(
    activity: Activity.fromJson(j),
    headlineTh: _str(j['headline_th']),
    checklist: _list(j['checklist']).map(ChecklistItem.fromJson).toList(),
    weatherNotesTh: (j['weather_notes_th'] as List? ?? const [])
        .cast<String>(),
    forecast: j['forecast'] == null
        ? null
        : DayForecast.fromJson(j['forecast'] as Json),
    placeTh: _str(j['place_th']),
    askTh: _str(j['ask_th']),
    suggestionsTh: (j['suggestions_th'] as List? ?? const []).cast<String>(),
    generatedBy: _str(j['generated_by']),
  );

  final Activity activity;
  final String headlineTh;
  final List<ChecklistItem> checklist;
  final List<String> weatherNotesTh;
  final DayForecast? forecast;
  final String placeTh;
  final String askTh;

  /// Search words for places known for the activity.
  final List<String> suggestionsTh;
  final String generatedBy;

  bool get asksWhere => askTh.isNotEmpty;
}

class EmergencyContact {
  const EmergencyContact({
    required this.agencyTh,
    required this.agencyEn,
    required this.number,
    required this.purposeTh,
    required this.purposeEn,
    this.lineId,
  });

  final String agencyTh;
  final String agencyEn;
  final String number;
  final String purposeTh;
  final String purposeEn;
  final String? lineId;

  factory EmergencyContact.fromJson(Json j) => EmergencyContact(
    agencyTh: _str(j['agency_th']),
    agencyEn: _str(j['agency_en']),
    number: _str(j['number']),
    purposeTh: _str(j['purpose_th']),
    purposeEn: _str(j['purpose_en']),
    lineId: j['line_id'] as String?,
  );
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
    this.trip,
    this.email,
    this.activity,
  });
  final String? tripId;

  /// Already formatted ISO-8601 with +07:00 offset.
  final String? departAt;
  final TravelMode? mode;
  final String? questionTh;
  final Place? origin;
  final Place? destination;
  final List<SavedPlace> places;
  final Trip? trip;
  final String? email;

  /// The day out an earlier answer asked "where?" about.
  final Activity? activity;

  DecideRequest copyWith({
    String? tripId,
    String? departAt,
    TravelMode? mode,
    Place? origin,
    Place? destination,
    List<SavedPlace>? places,
    Trip? trip,
    String? email,
    Activity? activity,
  }) => DecideRequest(
    tripId: tripId ?? this.tripId,
    departAt: departAt ?? this.departAt,
    mode: mode ?? this.mode,
    questionTh: questionTh,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    places: places ?? this.places,
    trip: trip ?? this.trip,
    email: email ?? this.email,
    activity: activity ?? this.activity,
  );

  Json toJson() => {
    if (tripId != null) 'trip_id': tripId,
    if (departAt != null) 'depart_at': departAt,
    if (mode != null) 'mode': mode!.wire,
    if (questionTh != null) 'question_th': questionTh,
    if (origin != null) 'origin': origin!.toJson(),
    if (destination != null) 'destination': destination!.toJson(),
    if (places.isNotEmpty) 'places': [for (final p in places) p.toWire()],
    if (trip != null) 'trip': trip!.toJson(),
    if (email != null) 'email': email,
    if (activity != null) 'activity': activity!.toJson(),
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
    this.generatedBy = '',
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
    generatedBy: _str(j['generated_by']),
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

  /// `gemini` when Gemini analysed the photo; anything else is a sample result.
  final String generatedBy;
  bool get analysedByGemini => generatedBy == 'gemini';

  /// The photo was not usable as evidence (not a flood, a screenshot, too unsure).
  bool get rejected => generatedBy == 'rejected';
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

/// One hour of weather at a place.
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.tempC,
    required this.feelsLikeC,
    required this.uvIndex,
    required this.rainProbPct,
    required this.rainMmPerHr,
    this.humidityPct = 0,
    this.windKph = 0,
    this.condition = '',
    this.conditionTh = '',
  });

  factory WeatherHour.fromJson(Json j) => WeatherHour(
    time: DateTime.parse(_str(j['time'])),
    tempC: _num(j['temp_c']),
    feelsLikeC: _num(j['feels_like_c']),
    uvIndex: _int(j['uv_index']),
    rainProbPct: _int(j['rain_prob_pct']),
    rainMmPerHr: _num(j['rain_mm_per_hr']),
    humidityPct: _int(j['humidity_pct']),
    windKph: _num(j['wind_kph']),
    condition: _str(j['condition']),
    conditionTh: _str(j['condition_th']),
  );

  final DateTime time;
  final double tempC;
  final double feelsLikeC;
  final int uvIndex;
  final int rainProbPct;
  final double rainMmPerHr;
  final int humidityPct;
  final double windKph;

  /// Google's weatherCondition.type, e.g. PARTLY_CLOUDY, HEAVY_RAIN.
  final String condition;

  /// Short description in the request's language.
  final String conditionTh;

  WeatherHour shifted(Duration by) => WeatherHour(
    time: time.add(by),
    tempC: tempC,
    feelsLikeC: feelsLikeC,
    uvIndex: uvIndex,
    rainProbPct: rainProbPct,
    rainMmPerHr: rainMmPerHr,
    humidityPct: humidityPct,
    windKph: windKph,
    condition: condition,
    conditionTh: conditionTh,
  );
}

/// The next hours of weather where the user is (`GET /v1/outlook`).
class Outlook {
  const Outlook({
    required this.now,
    required this.hours,
    this.sunset,
    this.sources = const [],
  });

  factory Outlook.fromJson(Json j) => Outlook(
    now: WeatherHour.fromJson(j['now'] as Json),
    hours: _list(j['hours']).map(WeatherHour.fromJson).toList(),
    sunset: DateTime.tryParse(_str(j['sunset'])),
    sources: (j['sources'] as List? ?? const []).cast<String>(),
  );

  final WeatherHour now;
  final List<WeatherHour> hours;
  final DateTime? sunset;
  final List<String> sources;
}
