import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../carry.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../trip_controller.dart';
import '../trips_repository.dart';
import 'ask_sheet.dart';
import 'event_cards.dart';
import 'parts.dart';
import 'place_picker.dart';
import 'settings_screen.dart';
import 'verdict_screen.dart';
import 'weather_cards.dart';
import '../time_th.dart';

/// At a glance: the next event and when to leave for it, the rain around
/// that departure, and the two events after it. Every card opens its detail.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.repo,
    required this.onRefresh,
    required this.onSeeAll,
  });

  final TripsRepository repo;
  final Future<void> Function() onRefresh;
  final VoidCallback onSeeAll;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  TripController? _ctrl;
  String? _ctrlFor;

  /// Packing covers the trip and a while at the event.
  static const _tripTail = Duration(hours: 2);

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    widget.repo.removeListener(_sync);
    _ctrl?.dispose();
    super.dispose();
  }

  /// Keeps one controller on the next event, replacing it when the next
  /// event changes.
  void _sync() {
    if (!mounted) return;
    final state = AppScope.readState(context);
    final now = state.now();
    final next = nextEvent(widget.repo.trips, now);
    final key = next == null || next.unresolved
        ? null
        : '${next.id}|${next.arriveBy}|${next.destination.lat},${next.destination.lng}|${state.locale.languageCode}|${state.demoClock}';
    if (key != _ctrlFor) {
      _ctrlFor = key;
      _ctrl?.dispose();
      _ctrl = next == null || key == null
          ? null
          : (TripController(
              api: AppScope.apiOf(context),
              state: state,
              request: widget.repo.requestFor(next),
              departAt: planDepartFor(next, now),
              mode: next.mode,
            )..addListener(_onTrip));
      _ctrl?.load();
    }
    setState(() {});
  }

  void _onTrip() {
    final c = _ctrl;
    final d = c?.decision;
    final id = c?.request.tripId;
    if (d != null && id != null && !c!.previewing) widget.repo.remember(id, d);
    setState(() {});
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTrip(Trip trip, {TravelMode? mode, DateTime? departAt}) => _push(
    VerdictScreen(
      request: widget.repo.requestFor(trip),
      trip: trip,
      departAt:
          departAt ?? planDepartFor(trip, AppScope.readState(context).now()),
      mode: mode,
    ),
  );

  /// An event whose location the server could not place.
  Future<void> _resolveTrip(Trip t) async {
    final saved = await pickPlace(
      context,
      kind: PlaceKind.other,
      initialQuery: t.locationTextTh,
    );
    if (saved == null || !mounted) return;
    _openTrip(
      Trip(
        id: 'app-${t.id}',
        titleTh: t.titleTh,
        source: 'app',
        origin: t.origin,
        destination: saved.asPlace,
        arriveBy: t.arriveBy,
        mode: t.mode,
      ),
    );
  }

  Future<void> _calibrateLocation() async {
    final candidate = await pickPoint(context);
    if (candidate == null || !mounted) return;
    final store = AppScope.readPlaces(context);
    store.setManualLocation(candidate);
    AppScope.readState(context).currentLocation = LocateResult(
      LocateStatus.ok,
      lat: candidate.lat,
      lng: candidate.lng,
      nameTh: candidate.nameTh,
      isManual: true,
      accuracyM: 10,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.homeUsingPinned(candidate.nameTh)),
        action: SnackBarAction(
          label: context.l10n.homeBackToGps,
          onPressed: () => store.setManualLocation(null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final repo = widget.repo;
    final l = context.l10n;
    final now = state.now();
    final ctrl = _ctrl;
    final d = ctrl?.decision;
    final next = nextEvent(repo.trips, now);
    final plan = d == null
        ? null
        : leavePlan(d, ctrl!.board, now, deadline: next?.arriveBy);
    final sky = state.flood
        ? SkyState.flood
        : (ctrl?.sky(home: state.homeLevel) ?? SkyState.clear);
    final here = state.currentLocation;

    final Widget hero;
    if (!repo.connected) {
      hero = ConnectCalendarCard(
        onConnect: () =>
            promptOAuth(context, service: OAuthService.calendar, store: store),
        onAsk: () => showAskSheet(context),
      );
    } else if (next == null && repo.loading) {
      hero = const _HeroSkeleton();
    } else if (next == null && repo.error != null) {
      hero = GlassSurface(
        padding: const EdgeInsets.all(Space.x5),
        child: ErrorState(
          title: l.summaryLoadErrorTitle,
          message: l.summaryLoadErrorBody,
          onRetry: widget.onRefresh,
        ),
      );
    } else if (next == null) {
      hero = GlassSurface(
        padding: const EdgeInsets.all(Space.x5),
        child: EmptyState(
          icon: Symbols.event_available_rounded,
          title: l.summaryNoEventsTitle,
          message: l.summaryNoEventsBody,
          action: FilledButton.tonalIcon(
            onPressed: () => showAskSheet(context),
            icon: const GeminiMark(size: 18),
            label: Text(l.summaryAskInstead),
          ),
        ),
      );
    } else {
      final unresolved = next.unresolved || ctrl?.needsPlace != null;
      final outlook = repo.outlook;
      final bring = outlook == null || plan == null
          ? const <CarryItem>[]
          : whatToCarry(
              outlook,
              now: now,
              until: next.arriveBy?.add(_tripTail),
              mode: plan.best?.mode,
            );
      hero = NextEventCard(
        key: ValueKey('hero-${next.id}'),
        trip: next,
        now: now,
        plan: plan,
        summary: d?.summaryTh,
        loading: ctrl?.loading ?? false,
        failed: ctrl?.error != null && d == null,
        unresolved: unresolved,
        footer: bring.isEmpty ? null : BringRow(items: bring),
        onTap: unresolved
            ? () => _resolveTrip(next)
            : () => _openTrip(
                next,
                mode: plan?.best?.mode,
                departAt: ctrl?.departAt,
              ),
        onRetry: ctrl?.load,
        onResolvePlace: () => _resolveTrip(next),
      );
    }

    final today = bangkokDay(now);
    final rest = upcoming(
      repo.trips,
      now,
    ).where((t) => t.id != next?.id && t.arriveBy != null).toList();
    final laterToday = rest
        .where((t) => bangkokDay(t.arriveBy!) == today)
        .toList();
    // With nothing left today, the plan looks at tomorrow instead.
    final tomorrow = laterToday.isNotEmpty
        ? const <Trip>[]
        : rest
              .where(
                (t) =>
                    bangkokDay(t.arriveBy!) ==
                    today.add(const Duration(days: 1)),
              )
              .toList();
    final todayLeft = [
      if (next != null &&
          next.arriveBy != null &&
          bangkokDay(next.arriveBy!) == today)
        next,
      ...laterToday,
    ].length;

    final home = repo.home;
    final savedHome = store.home;
    final lowGps = here != null && here.lowAccuracy;
    final outlook = repo.outlook;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: LargeTitleHeader(
                  onSky: true,
                  eyebrow: dayDate(l, now),
                  title: !repo.connected
                      ? l.summaryTitle
                      : todayLeft == 0
                      ? l.planTitleFree
                      : l.planTitleToday('$todayLeft'),
                  badges: [
                    if (store.demoProfile) const DemoBadge(onField: true),
                    if (state.usingSample) const SampleBadge(onField: true),
                  ],
                  actions: [
                    DemoClockChip(state: state, sky: sky),
                    IconButton(
                      tooltip: l.homeSettings,
                      onPressed: () => _push(const SettingsScreen()),
                      icon: const Icon(Symbols.settings_rounded),
                    ),
                  ],
                ),
              ),
            ),
            if (state.flood && home != null && savedHome != null)
              _pad(
                FloodAlertCard(
                  headline: home.headlineTh,
                  onWhatToDo: () => showFloodSheet(
                    context,
                    status: home,
                    placeName: savedHome.nameTh,
                  ),
                ),
                bottom: Space.x4,
              ),
            _pad(hero),
            if (lowGps)
              _pad(
                Notice(
                  icon: Symbols.location_searching_rounded,
                  tone: NoticeTone.warning,
                  text: l.homeGpsInaccurate(
                    approxDistance(l, here.accuracyM ?? 1000),
                  ),
                  action: TextButton(
                    onPressed: _calibrateLocation,
                    child: Text(l.homePinMyself),
                  ),
                ),
                top: Space.x4,
              ),
            if (laterToday.isNotEmpty || tomorrow.isNotEmpty)
              SliverToBoxAdapter(
                child: _Block(
                  title: laterToday.isNotEmpty ? l.planToday : l.planTomorrow,
                  trailing: TextButton(
                    onPressed: widget.onSeeAll,
                    child: Text(l.summarySeeAll),
                  ),
                  child: Column(
                    children: [
                      for (final (i, t) in [...laterToday, ...tomorrow].indexed)
                        _PlanStep(
                          key: ValueKey('plan-${t.id}'),
                          trip: t,
                          plan: _planFor(t, now),
                          weather: outlook,
                          now: now,
                          last: i == laterToday.length + tomorrow.length - 1,
                          onTap: t.unresolved
                              ? () => _resolveTrip(t)
                              : () => _openTrip(
                                  t,
                                  mode: _planFor(t, now)?.best?.mode,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            if (outlook != null)
              SliverToBoxAdapter(
                child: _Block(
                  title: l.planWeatherNow,
                  child: WeatherPeek(outlook: outlook, now: now),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: GlassNavBar.inset(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child, {double top = 0, double bottom = 0}) =>
      SliverPadding(
        padding: EdgeInsets.fromLTRB(Space.gutter, top, Space.gutter, bottom),
        sliver: SliverToBoxAdapter(child: child),
      );

  LeavePlan? _planFor(Trip t, DateTime now) {
    final d = widget.repo.decisionFor(t.id);
    return d == null
        ? null
        : planOf(d, planDepartFor(t, now), now, deadline: t.arriveBy);
  }
}

/// A titled block on the page surface below the sky.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x6,
        Space.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Space.target),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: t.titleMedium),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.designLoadingAnswer,
    child: const GlassSurface(
      padding: EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 140, height: 12),
          SizedBox(height: Space.x3),
          Skeleton(width: 220, height: 22),
          SizedBox(height: Space.x2),
          Skeleton(width: 160, height: 12),
          SizedBox(height: Space.x5),
          Skeleton(width: 96, height: 12),
          SizedBox(height: Space.x2),
          Skeleton(width: 168, height: 44, radius: Radii.sm),
          SizedBox(height: Space.x5),
          Skeleton(height: 36, radius: Radii.sm),
        ],
      ),
    ),
  );
}

/// Flood mode's checklist: the home's status and what to do, in order.
Future<void> showFloodSheet(
  BuildContext context, {
  required HomeStatus status,
  required String placeName,
}) {
  final now = AppScope.readState(context).now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final l = context.l10n;
      final t = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.x8,
        ),
        children: [
          HomeStatusPass(status: status, now: now, placeName: placeName),
          if (status.actions.isNotEmpty) ...[
            const SizedBox(height: Space.x6),
            Text(l.floodDoNow, style: t.titleMedium),
            const SizedBox(height: Space.x2),
            for (final a in status.actions)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Space.targetLarge),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        '${a.order}',
                        style: tabular(
                          t.titleMedium!,
                        ).copyWith(color: scheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: Space.x4),
                    Expanded(child: Text(a.textTh, style: t.bodyLarge)),
                  ],
                ),
              ),
          ],
        ],
      );
    },
  );
}

/// One later event on the day's plan: a timeline dot at the event time,
/// then when to leave, how, and the weather at that departure.
class _PlanStep extends StatelessWidget {
  const _PlanStep({
    super.key,
    required this.trip,
    required this.now,
    required this.last,
    this.plan,
    this.weather,
    this.onTap,
  });
  final Trip trip;
  final DateTime now;
  final bool last;
  final LeavePlan? plan;
  final Outlook? weather;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final at = trip.arriveBy!;
    final p = plan;
    final best = p?.best;
    final leave = p == null
        ? null
        : switch (p.kind) {
            LeaveKind.before || LeaveKind.at => p.time,
            _ => null,
          };
    final w = weather == null ? null : hourAt(weather!, leave ?? at);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                const SizedBox(height: Space.x4),
                Text(hhmm(at), style: tabular(t.titleSmall!)),
                const SizedBox(height: Space.x1),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E6BFF), Color(0xFF14A8DC)],
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: Space.x1),
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.x3),
              child: GlassSurface(
                radius: Radii.lg,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.titleTh,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium,
                          ),
                          Text(
                            trip.unresolved
                                ? (trip.locationTextTh ?? '')
                                : trip.destination.nameTh,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: Space.x2),
                          Wrap(
                            spacing: Space.x3,
                            runSpacing: Space.x2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (trip.unresolved)
                                Text(
                                  l.summarySetPlace,
                                  style: t.labelLarge!.copyWith(
                                    color: c.warning,
                                  ),
                                )
                              else if (p != null && best != null)
                                Text(
                                  p.kind == LeaveKind.avoid
                                      ? l.eventsAvoid
                                      : l.eventsLeaveAt(
                                          leave == null
                                              ? l.summaryLeaveNow
                                              : hhmm(leave),
                                          best.mode.label(l),
                                        ),
                                  style: tabular(t.labelLarge!),
                                ),
                              if (best != null)
                                RiskChip(risk: best.risk, dense: true),
                              if (w != null) WeatherTag(hour: w),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
