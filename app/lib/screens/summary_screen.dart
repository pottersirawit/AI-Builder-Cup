import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../carry.dart';
import '../design/design.dart';
import '../events.dart';
import '../plan.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../trip_controller.dart';
import '../trips_repository.dart';
import 'ask_sheet.dart';
import 'event_cards.dart';
import 'parts.dart';
import 'plan_cards.dart';
import 'place_picker.dart';
import 'settings_screen.dart';
import 'verdict_screen.dart';
import 'weather_cards.dart';

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

  /// Small cards after the hero, up to [alertHorizon] ahead.
  static const _upNextLimit = 6;

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
        endsAt: t.endsAt,
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
        onConnect: () => promptOAuth(context),
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
        aside: switch (leaveTimeOf(plan)) {
          final leave? when leave.difference(now) <= planningWindow =>
            CountdownRing(leaveAt: leave, now: now),
          _ => null,
        },
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
    DateTime? leaveAt(Trip t) =>
        t.id == next?.id ? leaveTimeOf(plan) : leaveTimeOf(_planFor(t, now));
    final upNext = upcoming(repo.trips, now)
        .where(
          (t) =>
              t.id != next?.id &&
              t.arriveBy != null &&
              t.arriveBy!.difference(now) <= alertHorizon,
        )
        .take(_upNextLimit)
        .toList();
    // Online and all-day events still fill the day.
    final todayLeft = upcoming(repo.trips, now)
        .where((t) => t.arriveBy != null && bangkokDay(t.arriveBy!) == today)
        .length;
    final pending = repo.trips.isEmpty && (repo.loading || repo.error != null);
    final skeleton = repo.connected && repo.loading && repo.trips.isEmpty;
    final alerts = planAlerts(
      trips: repo.trips,
      now: now,
      leaveAt: leaveAt,
      outlook: repo.outlook,
    );
    final todayTrips = upcoming(
      repo.trips,
      now,
    ).where((t) => t.travels && bangkokDay(t.arriveBy!) == today).toList();

    final home = repo.home;
    final savedHome = store.home;
    final lowGps = here != null && here.lowAccuracy;
    final outlook = repo.outlook;

    final header = SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: LargeTitleHeader(
          onSky: true,
          eyebrow: dayDate(l, now),
          title: !repo.connected || pending
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
    );
    final bottomInset = SliverToBoxAdapter(
      child: SizedBox(height: GlassNavBar.inset(context)),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        // One scroll view: the header stays put and only the page under it
        // swaps from the skeleton to the loaded plan, which fades in.
        child: CustomScrollView(
          slivers: [
            header,
            if (skeleton)
              SliverMainAxisGroup(
                key: const ValueKey('summary-skeleton'),
                slivers: [_pad(const _SummarySkeleton())],
              )
            else
              _FadeIn(
                key: const ValueKey('summary'),
                duration: Motion.of(
                  context,
                ).d(const Duration(milliseconds: 250)),
                sliver: SliverMainAxisGroup(
                  slivers: [
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
                    if (alerts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _Block(
                          title: l.alertsTitle,
                          child: AlertsCard(
                            alerts: alerts,
                            onTap: (a) => a.kind == AlertKind.needsPlace
                                ? _resolveTrip(a.trip)
                                : _openTrip(
                                    a.trip,
                                    mode: _planFor(a.trip, now)?.best?.mode,
                                  ),
                          ),
                        ),
                      ),
                    if (upNext.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _Block(
                          title: l.upNextTitle,
                          trailing: TextButton(
                            onPressed: widget.onSeeAll,
                            child: Text(l.summarySeeAll),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, t) in upNext.indexed) ...[
                                    if (i > 0) const SizedBox(width: Space.x3),
                                    UpNextCard(
                                      key: ValueKey('next-${t.id}'),
                                      trip: t,
                                      now: now,
                                      plan: _planFor(t, now),
                                      weather: outlook,
                                      onTap: t.unresolved
                                          ? () => _resolveTrip(t)
                                          : t.travels
                                          ? () => _openTrip(
                                              t,
                                              mode: _planFor(
                                                t,
                                                now,
                                              )?.best?.mode,
                                            )
                                          : widget.onSeeAll,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (todayTrips.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _Block(
                          title: l.stripTitle,
                          child: DayStrip(
                            trips: todayTrips,
                            now: now,
                            leaveAt: leaveAt,
                            outlook: outlook,
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
                  ],
                ),
              ),
            bottomInset,
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

/// Fades [sliver] in once, when it first appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.duration, required this.sliver});
  final Duration duration;
  final Widget sliver;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    builder: (_, v, child) => SliverOpacity(opacity: v, sliver: child),
    child: sliver,
  );
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

/// The hero ticket's shape: date stub, countdown and title above the
/// perforation, the leave answer below.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.designLoadingAnswer,
    child: const GlassTicket(
      top: Padding(
        padding: EdgeInsets.all(Space.x4),
        child: Row(
          children: [
            Skeleton(width: 64, height: 68, radius: Radii.lg),
            SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 96, height: 12),
                  SizedBox(height: Space.x2),
                  Skeleton(width: 200, height: 20),
                  SizedBox(height: Space.x2),
                  Skeleton(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: Padding(
        padding: EdgeInsets.fromLTRB(Space.x5, Space.x4, Space.x5, Space.x5),
        child: LeaveSkeleton(),
      ),
    ),
  );
}

/// The whole page while the first events load: the hero, then where
/// Before you go, Up next and the weather will be.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(Widget child, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: Space.target,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 120, height: 16),
            ),
          ),
          child,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroSkeleton(),
        block(const Skeleton(height: 72, radius: Radii.lg)),
        block(
          key: const ValueKey('skeleton-up-next'),
          const Row(
            children: [
              Skeleton(width: 160, height: 96, radius: Radii.lg),
              SizedBox(width: Space.x3),
              Skeleton(width: 160, height: 96, radius: Radii.lg),
            ],
          ),
        ),
        block(
          key: const ValueKey('skeleton-weather'),
          const Skeleton(height: 88, radius: Radii.lg),
        ),
      ],
    );
  }
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
