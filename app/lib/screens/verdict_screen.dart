import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import '../trip_controller.dart';
import 'ask_screen.dart';
import 'parts.dart';
import 'place_picker.dart';

/// One trip in full: drag the departure, compare modes, see why.
class VerdictScreen extends StatefulWidget {
  const VerdictScreen({
    super.key,
    required this.request,
    this.trip,
    this.departAt,
    this.mode,
  });

  /// A trip id, an origin/destination pair, or a Thai question.
  final DecideRequest request;
  final Trip? trip;
  final DateTime? departAt;
  final TravelMode? mode;

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  late final TripController _c = TripController(
    api: AppScope.apiOf(context),
    state: AppScope.readState(context),
    request: widget.request,
    departAt: widget.departAt,
    mode: widget.mode,
  )..addListener(_changed);

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  void _changed() => setState(() {});

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
    final trip = widget.trip ?? d?.trip;
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
    final Widget pass = needs != null
        ? NeedsPlacePass(needs: needs, onResolved: _c.resolvePlace)
        : _c.error != null && d == null
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
        : TripPass(
            controller: _c,
            now: state.now(),
            trip: trip,
            question: widget.request.questionTh,
            actions: [
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
                      title: trip == null
                          ? l.verdictQuestionTitle
                          : trip.source == 'routine' ||
                                trip.titleTh == 'กลับบ้าน'
                          ? trip.titleTh
                          : l.verdictGoTo(trip.destination.nameTh),
                      subtitle: trip == null
                          ? l.verdictReadingQuestion
                          : '${trip.origin.nameTh} → ${trip.destination.nameTh}',
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
          if (d != null) ...[
            if (d.explanation case final e? when !e.isEmpty)
              SliverToBoxAdapter(
                child: _WhySection(explanation: e, decision: d),
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
                            text: l.verdictModeStatus(
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
                trailing: const GeminiMark(size: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < d.reasoning.length; i++)
                      _TraceStep(
                        step: d.reasoning[i],
                        index: i + 1,
                        last: i == d.reasoning.length - 1,
                      ),
                    const SizedBox(height: Space.x4),
                    ConfidenceMeter(
                      value: d.confidence,
                      color: scheme.onSurface,
                    ),
                    const SizedBox(height: Space.x4),
                    Text(l.verdictSources, style: t.titleSmall),
                    const SizedBox(height: Space.x2),
                    Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        for (final s in d.sources)
                          Chip(
                            avatar: Icon(
                              _sourceIcon(s),
                              size: 16,
                            ),
                            label: Text(
                              s == gpsSourceLabel ? l.verdictSourceGps : s,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.x4),
                    GeneratedBy(d.generatedBy),
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

/// One tool call in the agent's trace: a numbered rail, a plain-words step title, summary.
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
      _ => null,
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
                  if (title != null)
                    Text(
                      title,
                      style: t.labelLarge!.copyWith(color: scheme.primary),
                    ),
                  const SizedBox(height: 2),
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
  if (s.contains('Road Flood') || s.contains('Sensor') || s.contains('เซ็นเซอร์')) {
    return Symbols.sensors_rounded;
  }
  if (s.contains('WeatherNext') || s.contains('Wind')) {
    return Symbols.air_rounded;
  }
  if (s.contains('Tidal') || s.contains('Canal') || s.contains('คลอง')) {
    return Symbols.waves_rounded;
  }
  return Symbols.database_rounded;
}

