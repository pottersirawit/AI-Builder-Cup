import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../carry.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import '../trip_controller.dart';
import 'activity_cards.dart';
import 'ask_screen.dart';
import 'origin_picker.dart';
import 'parts.dart';
import 'place_picker.dart';
import 'weather_cards.dart' show carryLook;

/// One trip in full: drag the departure, compare modes, see why.
class VerdictScreen extends StatefulWidget {
  const VerdictScreen({
    super.key,
    required this.request,
    this.trip,
    this.previousTrip,
    this.departAt,
    this.mode,
  });

  /// A trip id, an origin/destination pair, or a Thai question.
  final DecideRequest request;
  final Trip? trip;
  final Trip? previousTrip;
  final DateTime? departAt;
  final TravelMode? mode;

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  late final TripController _c = TripController(
    api: AppScope.apiOf(context),
    state: AppScope.readState(context),
    request: _initialRequest,
    departAt: widget.departAt,
    mode: widget.mode,
    deadline: widget.trip?.allDay == true ? null : widget.trip?.arriveBy,
  )..addListener(_changed);

  /// Weather at the destination, for what to bring.
  Outlook? _outlook;

  DecideRequest get _initialRequest {
    final prev = widget.previousTrip;
    final trip = widget.trip;
    if (prev != null &&
        prev.destination.resolved &&
        trip != null &&
        (widget.request.origin == null ||
            widget.request.origin!.isPlaceholder)) {
      return widget.request.copyWith(
        origin: prev.destination,
        trip: trip.copyWith(origin: prev.destination),
      );
    }
    return widget.request;
  }

  @override
  void initState() {
    super.initState();
    _c.load();
    _loadOutlook();
  }

  Future<void> _loadOutlook() async {
    final dest = widget.trip?.destination ?? widget.request.destination;
    final known = dest != null && (dest.lat != 0 || dest.lng != 0);
    try {
      final r = await AppScope.apiOf(
        context,
      ).outlook(lat: known ? dest.lat : null, lng: known ? dest.lng : null);
      if (mounted) setState(() => _outlook = r.data);
    } catch (_) {
      // No weather, no packing list; the trip's answer stands on its own.
    }
  }

  void _changed() => setState(() {});

  Future<void> _openOriginPicker() async {
    final state = AppScope.readState(context);
    final store = AppScope.readPlaces(context);
    final prev =
        widget.previousTrip ??
        (widget.trip != null
            ? previousEventFor(store.cachedTrips, widget.trip!)
            : null);
    await showOriginPickerSheet(
      context: context,
      currentOrigin: _c.origin,
      previousTrip: prev,
      home: store.home,
      work: store.work,
      others: store.others,
      currentLocation: state.currentLocation,
      onSelected: (place) => _c.setOrigin(place),
    );
  }

  void _planActivity(ActivityPlan plan, Place destination, DateTime day) {
    final origin = activityOrigin(context);
    if (origin == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.activityNeedsOrigin)));
      return;
    }
    _c.planActivity(
      activity: plan.activity,
      origin: origin,
      destination: destination,
      day: day,
    );
  }

  Future<void> _savePlace(Place dest) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final r = await showPlaceConfirmSheet(
      context,
      kind: PlaceKind.other,
      candidate: PlaceCandidate(
        nameTh: dest.nameTh,
        lat: dest.lat,
        lng: dest.lng,
      ),
    );
    if (r?.saved != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.verdictSavedSnack(r!.saved!.labelFor(l)))),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = AppScope.stateOf(context);
    final d = _c.decision;
    final rawTrip = widget.trip ?? d?.trip;
    final trip = rawTrip?.copyWith(origin: _c.origin);
    final store = AppScope.placesOf(context);
    final dest = trip?.destination;
    final unsaved =
        dest != null &&
        !trip!.unresolved &&
        (dest.lat != 0 || dest.lng != 0) &&
        store.duplicateOf(dest.lat, dest.lng) == null;
    final sky = state.flood ? SkyState.flood : _c.sky(home: state.homeLevel);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);

    final needs = _c.needsPlace;
    final ask = _c.askActivity;
    final Widget pass = ask != null
        ? ActivityAskPass(
            plan: ask,
            now: state.now(),
            onPlan: (dest, day) => _planActivity(ask, dest, day),
          )
        : needs != null
        ? NeedsPlacePass(needs: needs, onResolved: _c.resolvePlace)
        : (_c.error != null && d == null) || d?.unreadable == true
        ? Pass(
            sections: [
              PassSection(
                child: ErrorState(
                  title: l.verdictCantDecide,
                  message: l.verdictServerError,
                  retryLabel: l.verdictRetry,
                  onRetry: _c.load,
                ),
              ),
            ],
          )
        : d?.refused == true
        ? Pass(
            sections: [
              PassSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d!.headlineTh,
                      style: tabular(
                        t.headlineMedium!,
                      ).copyWith(color: c.paperInk),
                    ),
                    const SizedBox(height: Space.x3),
                    Text(
                      d.summaryTh,
                      style: t.bodyLarge!.copyWith(color: c.paperInk),
                    ),
                  ],
                ),
              ),
            ],
          )
        : TripPass(
            controller: _c,
            now: state.now(),
            trip: trip,
            question: widget.request.questionTh,
            actions: [
              if (trip != null)
                ActionChip(
                  avatar: const Icon(
                    Symbols.edit_location_alt_rounded,
                    size: 18,
                  ),
                  label: Text(l.isThai ? 'เปลี่ยนจุดเริ่มต้น' : 'Change start'),
                  onPressed: _openOriginPicker,
                ),
              if (unsaved && store.canAddOther)
                ActionChip(
                  avatar: const Icon(Symbols.bookmark_add_rounded, size: 18),
                  label: Text(l.verdictSavePlace),
                  onPressed: () => _savePlace(dest),
                ),
            ],
          );

    final board = _c.board;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SkyField(
              state: sky,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    FieldHeader(
                      state: sky,
                      back: true,
                      title: ask != null
                          ? ask.headlineTh
                          : trip == null
                          ? l.verdictQuestionTitle
                          : trip.source == 'routine' ||
                                trip.titleTh == 'กลับบ้าน'
                          ? trip.titleTh
                          : l.verdictGoTo(trip.destination.nameTh),
                      subtitle: ask != null
                          ? widget.request.questionTh ?? ''
                          : trip == null
                          ? l.verdictReadingQuestion
                          : '${trip.origin.nameTh} → ${trip.destination.nameTh}',
                      onSubtitleTap: trip != null ? _openOriginPicker : null,
                      subtitleTapLabel: l.isThai
                          ? 'เปลี่ยนจุดเริ่มต้น'
                          : 'Change starting point',
                      actions: [
                        if (state.usingSample)
                          const Padding(
                            padding: EdgeInsets.only(right: Space.x3),
                            child: SampleBadge(onField: true),
                          ),
                      ],
                    ),
                    if (_c.loading)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: c.sky(sky).onField,
                        backgroundColor: Colors.transparent,
                      )
                    else
                      const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.x2,
                        Space.gutter,
                        0,
                      ),
                      child: pass,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (d != null && !d.refused && !d.unreadable) ...[
            if (d.explanation case final e? when !e.isEmpty)
              SliverToBoxAdapter(
                child: _WhySection(explanation: e, decision: d),
              ),
            if (d.activity case final a?)
              SliverToBoxAdapter(child: ActivitySection(plan: a))
            else if (_outlook case final o?)
              SliverToBoxAdapter(
                child: _GearSection(
                  outlook: o,
                  from: _c.departAt,
                  until: _c.deadline != null
                      ? _c.deadline!.add(const Duration(hours: 2))
                      : _c.departAt.add(Duration(minutes: _c.etaMin + 60)),
                  mode: _c.mode,
                ),
              ),
            SliverToBoxAdapter(
              child: Section(
                title: l.verdictCompareModes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModeSegmented(
                      selected: _c.mode,
                      onChanged: _c.setMode,
                      status: {
                        for (final o in board)
                          o.mode: ModeStatus(
                            risk: o.risk,
                            text: o.rainProbPct > 0
                                ? l.verdictModeStatusWithProb(
                                    o.etaMin,
                                    boardStatusText(l, o.verdict, o.risk),
                                    o.rainProbPct,
                                  )
                                : l.verdictModeStatus(
                                    o.etaMin,
                                    boardStatusText(l, o.verdict, o.risk),
                                  ),
                          ),
                      },
                    ),
                    if (_c.selected != null) ...[
                      const SizedBox(height: Space.x3),
                      Text(_c.selected!.noteTh, style: t.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CalculatedRouteSection(
                decision: d,
                trip: trip,
                selectedMode: _c.mode,
                onChangeOrigin: trip != null ? _openOriginPicker : null,
              ),
            ),
            SliverToBoxAdapter(
              child: Section(
                title: l.verdictFloodSpotsTitle,
                child: d.floodSpots.isEmpty
                    ? EmptyState(
                        icon: Symbols.check_circle_rounded,
                        title: l.verdictNoFloodSpots,
                        message: l.verdictNoFloodSpotsMsg,
                      )
                    : Column(
                        children: [
                          for (final s in d.floodSpots) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Symbols.flood_rounded,
                                color: c.riskInk(s.risk),
                              ),
                              title: Text(s.nameTh),
                              subtitle: Text(
                                s.expectedDepthCm > 0
                                    ? l.verdictExpectedDepth(
                                        s.expectedDepthCm.round(),
                                      )
                                    : l.verdictStillDry,
                                style: tabular(
                                  t.bodySmall!,
                                ).copyWith(color: scheme.onSurfaceVariant),
                              ),
                              trailing: RiskChip(risk: s.risk, dense: true),
                            ),
                            if (s != d.floodSpots.last) const Divider(),
                          ],
                        ],
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Section(
                title: l.verdictTraceTitle,
                trailing: GeminiMark(
                  size: 22,
                  fallback: d.generatedBy == 'fallback',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, step)
                        in _traceStepsWithSynthesis(d, l).indexed)
                      _TraceStep(
                        step: step,
                        index: i + 1,
                        last: i == _traceStepsWithSynthesis(d, l).length - 1,
                      ),
                    const SizedBox(height: Space.x4),
                    ConfidenceMeter(
                      value: d.confidence,
                      color: scheme.onSurface,
                    ),
                    if (d.emergencyContacts.isNotEmpty) ...[
                      const SizedBox(height: Space.x4),
                      Text(
                        l.verdictHotlinesTitle,
                        style: t.titleSmall?.copyWith(color: scheme.error),
                      ),
                      const SizedBox(height: Space.x2),
                      Wrap(
                        spacing: Space.x2,
                        runSpacing: Space.x2,
                        children: [
                          for (final contact in d.emergencyContacts)
                            ActionChip(
                              avatar: const Icon(
                                Symbols.phone_in_talk_rounded,
                                size: 16,
                              ),
                              label: Text(
                                '${contact.number} ${l.isThai ? contact.agencyTh : contact.agencyEn}',
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: contact.number),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l.verdictHotlineCopied(
                                        contact.number,
                                        l.isThai
                                            ? contact.purposeTh
                                            : contact.purposeEn,
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Space.x4),
                    Text(l.verdictSources, style: t.titleSmall),
                    const SizedBox(height: Space.x2),
                    Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        for (final s in d.sources)
                          Chip(
                            avatar: Icon(_sourceIcon(s), size: 16),
                            label: Text(
                              s == gpsSourceLabel ? l.verdictSourceGps : s,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.x4),
                    GeneratedBy(d.generatedBy),
                    const SizedBox(height: Space.x2),
                    Text(
                      l.verdictAccuracyDisclaimer,
                      style: t.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x8,
                  Space.gutter,
                  Space.x10,
                ),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AskScreen(trip: trip, opening: _c.headline),
                    ),
                  ),
                  icon: const Icon(Symbols.chat_rounded),
                  label: Text(l.verdictAskMore),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What to bring for this trip, from the weather at the destination between
/// leaving and the end of the event: rain gear, sun, heat or cold.
class _GearSection extends StatelessWidget {
  const _GearSection({
    required this.outlook,
    required this.from,
    required this.until,
    required this.mode,
  });
  final Outlook outlook;
  final DateTime from;
  final DateTime until;
  final TravelMode mode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hours = hoursAhead(outlook, now: from, until: until);
    final items = whatToCarry(outlook, now: from, until: until, mode: mode);
    final moto = mode == TravelMode.moto;
    final first = hours.firstOrNull;
    final peakTemp = hours.fold(-99.0, (m, h) => h.tempC > m ? h.tempC : m);
    // The extreme the body feels: the coldest when it is cold, else the hottest.
    final feels = hours.any((h) => h.feelsLikeC <= coldFeelsLikeC)
        ? hours.fold(99.0, (m, h) => h.feelsLikeC < m ? h.feelsLikeC : m)
        : hours.fold(-99.0, (m, h) => h.feelsLikeC > m ? h.feelsLikeC : m);

    Widget row(IconData icon, Color accent, String title, String why) =>
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x2),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: .18),
                  ),
                  child: Icon(icon, color: accent, fill: 1, size: 22),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      Text(
                        why,
                        style: tabular(
                          t.bodySmall!,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Section(
      key: const ValueKey('gear-section'),
      title: l.verdictGearTitle,
      trailing: Icon(Symbols.backpack_rounded, size: 20, color: scheme.primary),
      child: first == null
          ? Text(
              l.verdictGearTooFar,
              style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.verdictGearWeather(peakTemp.round(), feels.round()),
                  style: tabular(
                    t.bodyMedium!,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Space.x2),
                if (items.isEmpty)
                  row(
                    Symbols.check_circle_rounded,
                    FonColors.of(context).riskLow,
                    l.carryNothing,
                    l.verdictGearNothingBody,
                  )
                else
                  for (final i in items)
                    Builder(
                      key: ValueKey('gear-${i.kind.name}'),
                      builder: (context) {
                        final look = carryLook(l, i, moto: moto);
                        return row(
                          look.icon,
                          look.accent,
                          look.title,
                          look.why,
                        );
                      },
                    ),
              ],
            ),
    );
  }
}

/// Why this answer, right under it: the reason and the way around flooded
/// spots stay open; the full list of factors folds away.
class _WhySection extends StatefulWidget {
  const _WhySection({required this.explanation, required this.decision});
  final DecisionExplanation explanation;
  final Decision decision;

  @override
  State<_WhySection> createState() => _WhySectionState();
}

class _WhySectionState extends State<_WhySection> {
  bool _factorsOpen = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = widget.explanation;
    final d = widget.decision;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Section(
      title: l.verdictWhyTitle,
      trailing: GeminiMark(size: 22, fallback: d.generatedBy == 'fallback'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.reasonWhyTh.isNotEmpty) Text(e.reasonWhyTh, style: t.bodyLarge),
          if (e.routeAdviceTh.isNotEmpty) ...[
            const SizedBox(height: Space.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.alt_route_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.verdictRouteAdvice, style: t.titleSmall),
                      const SizedBox(height: Space.x1),
                      Text(e.routeAdviceTh, style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (e.avoidSpotsTh.isNotEmpty) ...[
            const SizedBox(height: Space.x3),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final spot in e.avoidSpotsTh)
                  RiskChip(risk: Risk.high, label: l.verdictAvoid(spot)),
              ],
            ),
          ],
          if (e.factorsTh.isNotEmpty) ...[
            const SizedBox(height: Space.x2),
            Semantics(
              expanded: _factorsOpen,
              child: TextButton.icon(
                onPressed: () => setState(() => _factorsOpen = !_factorsOpen),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                ),
                icon: Icon(
                  _factorsOpen
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                ),
                label: Text(
                  _factorsOpen
                      ? l.verdictHideFactors
                      : l.verdictShowFactors(e.factorsTh.length),
                ),
              ),
            ),
            if (_factorsOpen)
              for (final f in e.factorsTh)
                Padding(
                  padding: const EdgeInsets.only(
                    left: Space.x2,
                    top: Space.x1,
                    bottom: Space.x1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 9),
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Space.x3),
                      Expanded(child: Text(f, style: t.bodyMedium)),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

List<ReasoningStep> _traceStepsWithSynthesis(Decision d, AppLocalizations l) {
  if (d.reasoning.isEmpty) return const [];
  final alreadyHasSynthesis = d.reasoning.any(
    (s) => s.tool.startsWith('synthesize_decision'),
  );
  if (alreadyHasSynthesis) return d.reasoning;

  final guardrailFired = d.reasoning.any(
    (s) => s.tool.startsWith('guardrail'),
  );
  final isAi = d.generatedBy == 'gemini' && !guardrailFired && !d.refused;
  final synthesisStep = isAi
      ? ReasoningStep(
          'synthesize_decision',
          l.isThai
              ? 'สรุปคำแนะนำสุดท้าย (${d.headlineTh}) และเรียบเรียงคำอธิบายด้วย Gemini โดยผ่านการตรวจสอบความถูกต้องกับข้อมูลจริง'
              : 'Synthesized the final recommendation (${d.headlineTh}) and explanation with Gemini, verified against grounded tool data',
          'ai',
        )
      : ReasoningStep(
          'synthesize_decision_fallback',
          l.isThai
              ? 'สรุปคำแนะนำสุดท้าย (${d.headlineTh}) และคำอธิบายจากแบบจำลองความเสี่ยงโดยตรง'
              : 'Generated the final recommendation (${d.headlineTh}) and explanation directly from the deterministic risk model',
          'rule',
        );
  return [...d.reasoning, synthesisStep];
}

/// One tool call in the agent's trace: a numbered rail, a plain-words step title, classification badge, and summary.
class _TraceStep extends StatelessWidget {
  const _TraceStep({
    required this.step,
    required this.index,
    required this.last,
  });
  final ReasoningStep step;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final title = switch (step.tool) {
      'parse_question' => l.verdictToolParseQuestion,
      'get_trip' => l.verdictToolGetTrip,
      'get_route' => l.verdictToolGetRoute,
      'get_rain_along_route' => l.verdictToolRain,
      'get_flood_spots_on_route' => l.verdictToolFloodSpots,
      'get_canal_levels' => l.verdictToolCanals,
      'get_community_reports' => l.verdictToolReports,
      'evaluate_departure' => l.verdictToolEvaluate,
      'deterministic_baseline' =>
        l.isThai ? 'คำนวณความเสี่ยงด้วยแบบจำลอง' : 'Run deterministic risk model',
      'synthesize_decision' || 'synthesize_decision_fallback' =>
        l.isThai ? 'สรุปคำแนะนำสุดท้าย' : 'Synthesize final recommendation',
      final tool when tool.startsWith('guardrail') =>
        l.isThai ? 'ตรวจสอบความถูกต้องของคำตอบ' : 'Verify grounding guardrails',
      _ => null,
    };
    final (badgeLabel, badgeIcon) = switch (step.effectiveCategory) {
      'ai' => (
        l.isThai ? 'วิเคราะห์ด้วย AI' : 'Inferred by AI',
        Symbols.auto_awesome_rounded,
      ),
      'data_ai' => (
        l.isThai ? 'ข้อมูลจริง + AI' : 'Data + AI',
        Symbols.photo_camera_rounded,
      ),
      'rule' => (
        l.isThai ? 'กฎการคำนวณ' : 'Rule-based',
        Symbols.calculate_rounded,
      ),
      'data_rule' => (
        l.isThai ? 'ข้อมูลจริง + กฎคำนวณ' : 'Data + Rule-based',
        Symbols.analytics_rounded,
      ),
      _ => (
        l.isThai ? 'ข้อมูลจริง' : 'Data-based',
        Symbols.database_rounded,
      ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: tabular(
                      t.labelMedium!,
                    ).copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: t.labelLarge!.copyWith(color: scheme.primary),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.x2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badgeIcon,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badgeLabel,
                              style: t.labelSmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(step.summaryTh, style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _sourceIcon(String s) {
  if (s.contains('GPS') || s.contains('ตำแหน่ง')) {
    return Symbols.my_location_rounded;
  }
  if (s.contains('Calendar')) {
    return Symbols.calendar_month_rounded;
  }
  if (s.contains('Gmail')) {
    return Symbols.mail_rounded;
  }
  if (s.contains('Road Flood') ||
      s.contains('Sensor') ||
      s.contains('เซ็นเซอร์')) {
    return Symbols.sensors_rounded;
  }
  if (s.contains('WeatherNext') || s.contains('Wind')) {
    return Symbols.air_rounded;
  }
  if (s.contains('Weather API')) {
    return Symbols.rainy_rounded;
  }
  if (s.contains('Routes API')) {
    return Symbols.route_rounded;
  }
  if (s.contains('Tidal') || s.contains('Canal') || s.contains('คลอง') || s.contains('ThaiWater')) {
    return Symbols.waves_rounded;
  }
  if (s.contains('Vision') || s.contains('รายงานน้ำท่วม') || s.contains('Community flood')) {
    return Symbols.photo_camera_rounded;
  }
  if (s.contains('สายด่วน') || s.contains('Hotline') || s.contains('1784')) {
    return Symbols.phone_in_talk_rounded;
  }
  return Symbols.database_rounded;
}

/// Renders the route calculated for the selected travel mode, plus explicit
/// transit line and boarding/alighting stations for BTS/MRT.
class _CalculatedRouteSection extends StatelessWidget {
  const _CalculatedRouteSection({
    required this.decision,
    required this.trip,
    required this.selectedMode,
    this.onChangeOrigin,
  });

  final Decision decision;
  final Trip? trip;
  final TravelMode selectedMode;
  final VoidCallback? onChangeOrigin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final selectedOption = decision.modeOptions
        .where((o) => o.mode == selectedMode)
        .firstOrNull;
    final transitOption = decision.modeOptions
        .where((o) => o.mode == TravelMode.transit)
        .firstOrNull;
    final routeStep = decision.reasoning
        .where((r) => r.tool == 'get_route')
        .firstOrNull;

    final via = selectedOption?.viaTh ?? const <String>[];
    final transitLegs = transitOption?.transitLegs ?? const <TransitLeg>[];

    final originName = trip?.origin.nameTh ?? '';
    final destName = trip?.destination.nameTh ?? '';

    final nodes = <({String label, bool endpoint})>[
      if (originName.isNotEmpty) (label: originName, endpoint: true),
      for (final stop in via)
        if (stop != originName && stop != destName)
          (label: stop, endpoint: false),
      if (destName.isNotEmpty && destName != originName)
        (label: destName, endpoint: true),
    ];

    return Section(
      title: l.isThai ? 'เส้นทางที่ใช้คำนวณ' : 'Calculated route',
      trailing: Icon(selectedMode.icon, size: 20, color: scheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedOption != null) ...[
            Row(
              children: [
                Icon(
                  Symbols.route_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    '${selectedMode.label(l)} · ${l.partsTakesMin(selectedOption.etaMin)}',
                    style: tabular(
                      t.labelLarge!,
                    ).copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
          ],
          if (nodes.isNotEmpty)
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < nodes.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x3,
                      vertical: Space.x1 + 2,
                    ),
                    decoration: BoxDecoration(
                      color: nodes[i].endpoint
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      nodes[i].label,
                      style: t.labelLarge!.copyWith(
                        color: nodes[i].endpoint
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (i < nodes.length - 1)
                    Icon(
                      Symbols.arrow_forward_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ],
            )
          else if (routeStep != null)
            Text(routeStep.summaryTh, style: t.bodyMedium),
          if (onChangeOrigin != null) ...[
            const SizedBox(height: Space.x3),
            OutlinedButton.icon(
              icon: const Icon(Symbols.edit_location_alt_rounded, size: 18),
              label: Text(
                l.isThai ? 'เปลี่ยนจุดเริ่มต้น' : 'Change starting point',
              ),
              onPressed: onChangeOrigin,
            ),
          ],
          if (transitLegs.isNotEmpty) ...[
            const SizedBox(height: Space.x4),
            if (selectedMode != TravelMode.transit) ...[
              Row(
                children: [
                  Icon(Symbols.train_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text(
                      l.isThai
                          ? 'เส้นทางรถไฟฟ้า (สายและสถานีขึ้น-ลง)'
                          : 'Transit route (line & stations)',
                      style: t.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x2),
            ],
            for (var i = 0; i < transitLegs.length; i++) ...[
              _TransitLegTile(leg: transitLegs[i], index: i, isThai: l.isThai),
              if (i < transitLegs.length - 1) const SizedBox(height: Space.x2),
            ],
          ],
        ],
      ),
    );
  }
}

class _TransitLegTile extends StatelessWidget {
  const _TransitLegTile({
    required this.leg,
    required this.index,
    required this.isThai,
  });

  final TransitLeg leg;
  final int index;
  final bool isThai;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final boardLabel = index == 0
        ? (isThai ? 'ขึ้นที่สถานี' : 'Get on at')
        : (isThai ? 'เปลี่ยนสายที่สถานี' : 'Transfer at');
    final alightLabel = isThai ? 'ลงที่สถานี' : 'Get off at';

    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x2,
                  vertical: Space.x1,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.train_rounded,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: Space.x1),
                    Flexible(
                      child: Text(
                        leg.lineTh,
                        style: t.labelLarge!.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (leg.stopCount > 0)
                Text(
                  isThai ? '${leg.stopCount} สถานี' : '${leg.stopCount} stops',
                  style: tabular(
                    t.labelMedium!,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: Space.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boardLabel,
                      style: t.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(leg.fromStationTh, style: t.titleSmall),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x2,
                  vertical: Space.x2,
                ),
                child: Icon(
                  Symbols.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alightLabel,
                      style: t.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(leg.toStationTh, style: t.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
