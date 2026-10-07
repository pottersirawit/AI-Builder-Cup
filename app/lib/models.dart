// Data types for API contract v0 (docs/plan/merged-flow.md).

typedef Json = Map<String, dynamic>;

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _str(Object? v) => v as String? ?? '';
List<Json> _list(Object? v) => (v as List? ?? const []).cast<Json>();

/// Travel mode as named on the wire.
enum TravelMode {
  car('car', 'รถยนต์', '🚗'),
  transit('transit', 'BTS / MRT', '🚈'),
  moto('moto', 'มอเตอร์ไซค์', '🛵');

  const TravelMode(this.wire, this.labelTh, this.emoji);
  final String wire;
  final String labelTh;
  final String emoji;

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
  factory Place.fromJson(Json j) =>
      Place(nameTh: _str(j['name_th']), lat: _num(j['lat']), lng: _num(j['lng']));
  final String nameTh;
  final double lat;
  final double lng;
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
  });

  factory Trip.fromJson(Json j) => Trip(
        id: _str(j['id']),
        titleTh: _str(j['title_th']),
        source: _str(j['source']),
        origin: Place.fromJson(j['origin'] as Json),
        destination: Place.fromJson(j['destination'] as Json),
        arriveBy: DateTime.parse(_str(j['arrive_by'])),
        mode: TravelMode.parse(j['mode']),
      );

  static List<Trip> listFromJson(Json j) =>
      _list(j['trips']).map(Trip.fromJson).toList();

  final String id;
  final String titleTh;

  /// calendar | gmail | typed
  final String source;
  final Place origin;
  final Place destination;
  final DateTime arriveBy;
  final TravelMode mode;
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
  });
  factory FloodSpot.fromJson(Json j) => FloodSpot(
        id: _str(j['id']),
        nameTh: _str(j['name_th']),
        lat: _num(j['lat']),
        lng: _num(j['lng']),
        expectedDepthCm: _num(j['expected_depth_cm']),
        risk: Risk.parse(j['risk']),
      );
  final String id;
  final String nameTh;
  final double lat;
  final double lng;
  final double expectedDepthCm;
  final Risk risk;
}

class ReasoningStep {
  const ReasoningStep(this.tool, this.summaryTh);
  factory ReasoningStep.fromJson(Json j) =>
      ReasoningStep(_str(j['tool']), _str(j['summary_th']));
  final String tool;
  final String summaryTh;
}

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
  });

  factory Decision.fromJson(Json j) => Decision(
        verdict: Verdict.parse(j['verdict']),
        headlineTh: _str(j['headline_th']),
        summaryTh: _str(j['summary_th']),
        leaveBy: DateTime.tryParse(_str(j['leave_by'])),
        confidence: _num(j['confidence']),
        rainTimeline: _list(j['rain_timeline']).map(RainPoint.fromJson).toList(),
        modeOptions: _list(j['mode_options']).map(ModeOption.fromJson).toList(),
        floodSpots: _list(j['flood_spots']).map(FloodSpot.fromJson).toList(),
        reasoning: _list(j['reasoning']).map(ReasoningStep.fromJson).toList(),
        sources: (j['sources'] as List? ?? const []).cast<String>(),
        generatedBy: _str(j['generated_by']),
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
}

/// Body of POST /v1/decide. Either [tripId] (with [departAt]/[mode]) or
/// [questionTh] is the main input; the server ignores fields it does not need.
class DecideRequest {
  const DecideRequest({this.tripId, this.departAt, this.mode, this.questionTh});
  final String? tripId;

  /// Already formatted ISO-8601 with +07:00 offset.
  final String? departAt;
  final TravelMode? mode;
  final String? questionTh;

  DecideRequest copyWith({String? departAt, TravelMode? mode}) => DecideRequest(
        tripId: tripId,
        departAt: departAt ?? this.departAt,
        mode: mode ?? this.mode,
        questionTh: questionTh,
      );

  Json toJson() => {
        if (tripId != null) 'trip_id': tripId,
        if (departAt != null) 'depart_at': departAt,
        if (mode != null) 'mode': mode!.wire,
        if (questionTh != null) 'question_th': questionTh,
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
        passable: (j['passable'] as Map? ?? const {})
            .map((k, v) => MapEntry(TravelMode.parse(k), v as String)),
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
    );
  }

  final HomeLevel level;
  final String headlineTh;
  final Canal? canal;

  /// Sorted by [HomeAction.order].
  final List<HomeAction> actions;
  final List<String> sources;
}
