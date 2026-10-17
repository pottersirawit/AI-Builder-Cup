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
import 'all_day_sheet.dart';
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
  final Set<String> _readIds = {};
  final Set<String> _dismissedBannerIds = {};

  /// Packing covers the trip and a while at the event.
  static const _tripTail = Duration(hours: 2);

  /// Small cards after the hero.
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
    final key =
        next == null || next.unresolved || !next.destination.resolved
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
      previousTrip: previousEventFor(widget.repo.trips, trip),
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
      initialQuery: t.locationTextTh ?? inferPlaceQueryFromTitle(t.titleTh),
    );
    if (saved == null || !mounted) return;
    final updated = await widget.repo.saveTripDestination(t, saved.asPlace);
    if (!mounted) return;
    _openTrip(updated);
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
        : leavePlan(
            d,
            ctrl!.board,
            now,
            deadline: next != null && !next.allDay ? next.arriveBy : null,
          );
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
      final bring = outlook == null || (plan == null && !next.allDay)
          ? const <CarryItem>[]
          : whatToCarry(
              outlook,
              now: now,
              until: next.allDay
                  ? now.add(const Duration(hours: 6))
                  : next.arriveBy?.add(_tripTail),
              mode: plan?.best?.mode ?? next.mode,
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
        footer: bring.isEmpty
            ? null
            : BringRow(
                items: bring,
                moto: (plan?.best?.mode ?? next.mode) == TravelMode.moto,
              ),
        aside: next.allDay
            ? null
            : switch (leaveTimeOf(plan)) {
                final leave? when leave.difference(now) <= planningWindow =>
                  CountdownRing(leaveAt: leave, now: now),
                _ => null,
              },
        onTap: unresolved
            ? () => _resolveTrip(next)
            : (next.allDay && !next.destination.resolved)
            ? () => showAllDaySheet(
                context,
                trip: next,
                now: now,
                outlook: outlook,
              )
            : () => _openTrip(
                next,
                mode: plan?.best?.mode,
                departAt: ctrl?.departAt,
              ),
        onDismiss: () => dismissTripWithUndo(context, repo, next),
        onRetry: ctrl?.load,
        onResolvePlace: () => _resolveTrip(next),
        onAsk: () => showAskSheet(context),
      );
    }

    final today = bangkokDay(now);
    LeavePlan? planFor(Trip t) => t.id == next?.id ? plan : _planFor(t, now);
    DateTime? leaveAt(Trip t) => departureOf(planFor(t), now);
    final upNext = upcoming(repo.trips, now)
        .where((t) => t.id != next?.id && t.arriveBy != null)
        .take(_upNextLimit)
        .toList();
    // Online and all-day events still fill the day.
    final todayLeft = upcoming(
      repo.trips,
      now,
    ).where((t) => onDay(t, today)).length;
    final pending = repo.trips.isEmpty && (repo.loading || repo.error != null);
    final skeleton = repo.connected && repo.loading && repo.trips.isEmpty;
    final alerts = planAlerts(
      trips: repo.trips,
      now: now,
      leaveAt: leaveAt,
      modeOf: (t) => planFor(t)?.best?.mode,
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
    final notifications = state.notificationsDenied
        ? const <AppNotification>[]
        : buildNotifications(
            l: l,
            colors: FonColors.of(context),
            now: now,
            next: next,
            nextPlan: plan,
            nextDecision: d,
            alerts: alerts,
            home: home,
            homeName: savedHome?.nameTh,
            floodMode: state.flood,
          );
    final hasUnread = notifications.any((n) => !_readIds.contains(n.id));
    final activeBanner = notifications
        .where(
          (n) =>
              n.liveBanner &&
              !_readIds.contains(n.id) &&
              !_dismissedBannerIds.contains(n.id),
        )
        .firstOrNull;

    void openNotification(AppNotification n) {
      setState(() {
        _readIds.add(n.id);
        _dismissedBannerIds.add(n.id);
      });
      if (n.kind == NotificationKind.flood &&
          home != null &&
          savedHome != null) {
        showFloodSheet(context, status: home, placeName: savedHome.nameTh);
        return;
      }
      final t = n.trip;
      if (t == null) return;
      if (n.alert?.kind == AlertKind.needsPlace || t.unresolved) {
        _resolveTrip(t);
      } else {
        _openTrip(
          t,
          mode: n.mode ?? _planFor(t, now)?.best?.mode,
          departAt: t.id == next?.id ? ctrl?.departAt : null,
        );
      }
    }

    final header = SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: LargeTitleHeader(
          onSky: true,
          eyebrow: dayDate(l, now),
          title: summaryHeaderTitle(
            l: l,
            connected: repo.connected,
            pending: pending,
            todayLeft: todayLeft,
            next: next,
            now: now,
          ),
          badges: [
            if (store.demoProfile) const DemoBadge(onField: true),
            if (state.usingSample) const SampleBadge(onField: true),
          ],
          actions: [
            if (state.demoTools || state.demoClock != null)
              DemoClockChip(state: state, sky: sky),
            NotificationBellButton(
              hasUnread: hasUnread,
              onPressed: () => showNotificationsSheet(
                context,
                notifications: notifications,
                readIds: _readIds,
                onMarkAllRead: () => setState(() {
                  for (final n in notifications) {
                    _readIds.add(n.id);
                    _dismissedBannerIds.add(n.id);
                  }
                }),
                onSelect: openNotification,
              ),
            ),
            IconButton(
              tooltip: l.eventsRefresh,
              onPressed: widget.onRefresh,
              icon: const Icon(Symbols.refresh_rounded),
            ),
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
                    _pad(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (activeBanner != null) ...[
                            NotificationBanner(
                              time: activeBanner.time,
                              title: activeBanner.title,
                              body: activeBanner.body,
                              onOpen: () => openNotification(activeBanner),
                              onDismiss: () => setState(
                                () => _dismissedBannerIds.add(activeBanner.id),
                              ),
                            ),
                            const SizedBox(height: Space.x4),
                          ],
                          hero,
                        ],
                      ),
                    ),
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
                                      onDismiss: () => dismissTripWithUndo(
                                        context,
                                        repo,
                                        t,
                                      ),
                                      onTap: t.unresolved
                                          ? () => _resolveTrip(t)
                                          : (t.travels ||
                                                  (t.allDay &&
                                                      t.destination.resolved))
                                          ? () => _openTrip(
                                              t,
                                              mode: _planFor(
                                                t,
                                                now,
                                              )?.best?.mode,
                                            )
                                          : t.allDay
                                          ? () => showAllDaySheet(
                                              context,
                                              trip: t,
                                              now: now,
                                              outlook: outlook,
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
                          child: WeatherPeek(
                            outlook: outlook,
                            now: now,
                            placeName: weatherPlaceLabel(
                              l,
                              here: here,
                              home: savedHome,
                              work: store.work,
                              demoProfile: store.demoProfile,
                            ),
                          ),
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
        : planOf(
            d,
            planDepartFor(t, now),
            now,
            deadline: t.allDay ? null : t.arriveBy,
          );
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

/// Calculates the context-aware header title based on when the next trip is scheduled.
String summaryHeaderTitle({
  required AppLocalizations l,
  required bool connected,
  required bool pending,
  required int todayLeft,
  required Trip? next,
  required DateTime now,
}) {
  if (!connected || pending) {
    return l.summaryTitle;
  }
  if (next != null && next.arriveBy != null) {
    final today = bangkokDay(now);
    final nextDay = bangkokDay(next.arriveBy!);
    final diffDays = nextDay.difference(today).inDays;
    if (diffDays == 1) {
      return todayLeft > 0 ? l.planTitleNextTripTomorrow : l.planTitleTomorrow;
    }
    if (diffDays > 1) {
      return l.planTitleUpcoming;
    }
  }
  if (todayLeft == 0) {
    return l.planTitleFree;
  }
  return l.planTitleToday('$todayLeft');
}

/// Names the place the outlook was fetched for: a pinned location, a matched
/// saved place, current GPS, or the saved home.
String weatherPlaceLabel(
  AppLocalizations l, {
  LocateResult? here,
  SavedPlace? home,
  SavedPlace? work,
  bool demoProfile = false,
}) {
  String savedLabel(SavedPlace p) =>
      p.nameTh.isNotEmpty && p.nameTh != p.labelTh && p.labelTh.isNotEmpty
      ? '${p.labelTh} · ${p.nameTh}'
      : (p.nameTh.isNotEmpty ? p.nameTh : p.labelTh);

  if (here != null && here.isManual && (here.nameTh ?? '').isNotEmpty) {
    return here.nameTh!;
  }
  if (!demoProfile && here != null && here.ok) {
    if ((here.nameTh ?? '').isNotEmpty) return here.nameTh!;
    if (home != null &&
        (here.lat - home.lat).abs() < 0.005 &&
        (here.lng - home.lng).abs() < 0.005) {
      return savedLabel(home);
    }
    if (work != null &&
        (here.lat - work.lat).abs() < 0.005 &&
        (here.lng - work.lng).abs() < 0.005) {
      return savedLabel(work);
    }
    return l.locationCurrent;
  }
  if (home != null) return savedLabel(home);
  if (here != null && here.ok && (here.nameTh ?? '').isNotEmpty) {
    return here.nameTh!;
  }
  return l.locationCurrent;
}

