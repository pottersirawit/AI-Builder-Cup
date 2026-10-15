import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../places.dart';
import '../time_th.dart';
import '../trip_controller.dart';
import 'ask_screen.dart';
import 'parts.dart';
import 'place_picker.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'verdict_screen.dart';

/// Personal departure board: the sky, the top trip's pass, then the board.
/// Trips come from Calendar/Gmail when connected and from the daily trip
/// home the app builds out of saved home and work.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _trips = const [];
  HomeStatus? _home;
  CommutePlan? _commute;
  Trip? _top;
  TripController? _ctrl;
  Object? _error;
  bool _loading = true;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    String sig(SavedPlace? p) =>
        p == null ? '-' : '${p.id},${p.lat},${p.lng},${p.days},${p.leaveTime}';
    final key =
        '${state.locale.languageCode}|${state.demoClock ?? 'live'}|${sig(store.home)}|${sig(store.work)}|${store.calendar}|${store.demoProfile}';
    if (key != _loadedFor) {
      _loadedFor = key;
      _load();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final store = AppScope.readPlaces(context);
    final home = store.home;
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_refreshLocation());
    try {
      final homeF = home == null
          ? null
          : api.homeStatus(home: store.demoProfile ? null : home);
      final isWorkspaceConnected =
          store.calendar == LinkState.connected ||
          store.gmail == LinkState.connected;
      final email = store.calendar == LinkState.connected
          ? store.calendarAccount
          : store.gmailAccount;
      final tripsR = isWorkspaceConnected
          ? await api.trips(email: email)
          : null;
      final homeR = await homeF;
      if (!mounted) return;
      state
        ..markSample((tripsR?.isSample ?? false) || (homeR?.isSample ?? false))
        ..homeLevel = homeR?.data.level ?? HomeLevel.normal;
      final trips = tripsR?.data ?? const <Trip>[];
      final now = state.now();
      final resolved = trips.where((t) => !t.unresolved).toList();
      final headsHomeToday =
          home != null &&
          resolved.any(
            (t) =>
                home.distanceTo(t.destination.lat, t.destination.lng) <=
                    PlacesStore.duplicateRadiusM &&
                t.arriveBy != null &&
                toBangkok(t.arriveBy!).day == toBangkok(now).day,
          );
      final commute = headsHomeToday
          ? null
          : commuteFor(home: home, work: store.work, now: now);
      final routine = commute != null && !commute.fromCurrentLocation
          ? commute.trip
          : null;
      final top =
          resolved.where((t) => t.source == 'calendar').firstOrNull ??
          resolved.where((t) => t.source == 'gmail').firstOrNull ??
          routine ??
          resolved.firstOrNull;
      _ctrl?.dispose();
      _ctrl = top == null
          ? null
          : (TripController(
              api: api,
              state: state,
              request: _requestFor(top),
              departAt: top == routine ? commute!.departAt : null,
            )..addListener(_onTrip));
      setState(() {
        _trips = trips;
        _home = homeR?.data;
        _commute = commute;
        _top = top;
        _loading = false;
      });
      await _ctrl?.load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onTrip() => setState(() {});

  /// Where questions asked from Home start. A pinned spot wins over GPS, and
  /// the trip pass never waits for a fix.
  Future<void> _refreshLocation() async {
    final state = AppScope.readState(context);
    final pin = AppScope.readPlaces(context).manualLocation;
    if (pin != null) {
      state.currentLocation = _pinned(pin);
      return;
    }
    final loc = await AppScope.locatorOf(context).locate(prompt: false);
    if (!mounted) return;
    if (loc.ok) {
      state.currentLocation = loc;
    } else if (state.currentLocation?.isManual ?? false) {
      state.currentLocation = null;
    }
  }

  /// Server trips go by id; the app's own trips send their endpoints.
  DecideRequest _requestFor(Trip t) =>
      t.source == 'routine' || t.source == 'app'
      ? DecideRequest(origin: t.origin, destination: t.destination)
      : DecideRequest(tripId: t.id);

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTrip(Trip trip, {TravelMode? mode, DateTime? departAt}) {
    final c = _ctrl;
    final same = c != null && trip.id == _top?.id;
    _push(
      VerdictScreen(
        request: _requestFor(trip),
        trip: trip,
        departAt: departAt ?? (same ? c.departAt : null),
        mode: mode ?? (same ? c.mode : null),
      ),
    );
  }

  void _ask(String q) {
    final loc = AppScope.readState(context).currentLocation;
    final origin = loc?.ok == true
        ? Place(
            nameTh: loc!.nameTh ?? context.l10n.homeCurrentPlace,
            lat: loc.lat,
            lng: loc.lng,
          )
        : null;
    _push(
      VerdictScreen(
        request: DecideRequest(
          questionTh: q,
          origin: origin,
          places: AppScope.readPlaces(context).places,
        ),
      ),
    );
  }

  Future<void> _calibrateLocation() async {
    final candidate = await pickPoint(context);
    if (candidate == null || !mounted) return;
    final store = AppScope.readPlaces(context);
    store.setManualLocation(candidate);
    AppScope.readState(context).currentLocation = _pinned(candidate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.homeUsingPinned(candidate.nameTh)),
          action: SnackBarAction(
            label: context.l10n.homeBackToGps,
            onPressed: () {
              store.setManualLocation(null);
              _load();
            },
          ),
        ),
      );
      _load();
    }
  }

  Future<void> _setPlace(PlaceKind kind) => pickPlace(context, kind: kind);

  /// Home saved but no work: the trip home starts wherever the phone is.
  Future<void> _checkFromHere() async {
    final home = AppScope.readPlaces(context).home;
    final commute = _commute;
    if (home == null) return;
    final state = AppScope.readState(context);
    final herePlaceName = context.l10n.homeCurrentPlace;
    final here = state.currentLocation?.ok == true
        ? PlaceCandidate(
            nameTh: state.currentLocation!.nameTh ?? herePlaceName,
            lat: state.currentLocation!.lat,
            lng: state.currentLocation!.lng,
            source: state.currentLocation!.isManual ? 'manual' : 'gps',
            accuracyM: state.currentLocation!.accuracyM,
          )
        : await locateOrSearch(context);
    if (here == null || !mounted) return;
    _openTrip(
      Trip(
        id: 'app-home',
        titleTh: context.l10n.homeTripGoHome,
        source: 'app',
        origin: Place(
          nameTh: here.source == 'gps' || here.source == 'manual'
              ? (state.currentLocation?.nameTh ?? herePlaceName)
              : here.nameTh,
          lat: here.lat,
          lng: here.lng,
        ),
        destination: home.asPlace,
        arriveBy: null,
        mode: TravelMode.car,
      ),
      departAt: commute?.departAt,
    );
  }

  /// A Calendar event whose location the server could not place.
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final ctrl = _ctrl;
    final trip = _top;
    final home = _home;
    final savedHome = store.home;
    final work = store.work;
    final now = state.now();
    final sky = state.flood
        ? SkyState.flood
        : (ctrl?.sky(home: state.homeLevel) ?? SkyState.clear);
    final d = ctrl?.decision;
    final showPush =
        d != null && trip != null && !state.pushDismissed && !state.flood;
    final heroAsk =
        !_loading &&
        _error == null &&
        trip == null &&
        savedHome == null &&
        _commute == null;
    final here = state.currentLocation;
    final origin = trip != null && trip.origin.nameTh.isNotEmpty
        ? trip.origin.nameTh
        : null;
    final hereName = origin == null && here != null && here.ok
        ? here.nameTh ?? l.homeCurrentPlaceAlt
        : null;

    Widget top;
    if (_error != null) {
      top = Pass(
        sections: [
          PassSection(
            child: ErrorState(
              title: l.homeLoadErrorTitle,
              message: l.homeLoadErrorBody,
              onRetry: _load,
            ),
          ),
        ],
      );
    } else if (_loading) {
      top = const PassSkeleton();
    } else if (state.flood && home != null && savedHome != null) {
      top = HomeStatusPass(
        status: home,
        now: now,
        placeName: _homeName(savedHome),
        actions: [
          FilledButton.icon(
            onPressed: () => Shell.goTo(context, ShellTab.home),
            icon: const Icon(Symbols.checklist_rounded),
            label: Text(l.homeSeeWhatToDo),
          ),
        ],
      );
    } else if (trip != null && ctrl != null) {
      top = ctrl.error != null && d == null
          ? Pass(
              sections: [
                PassSection(
                  child: ErrorState(
                    title: l.homeDecideErrorTitle,
                    message: l.homeDecideErrorBody,
                    onRetry: ctrl.load,
                  ),
                ),
              ],
            )
          : TripPass(
              controller: ctrl,
              now: now,
              trip: trip,
              compact: true,
              onTap: () => _openTrip(trip),
              actions: [
                FilledButton(
                  onPressed: () => _openTrip(trip),
                  child: Text(l.homeSeeReasons),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _push(AskScreen(trip: trip, opening: ctrl.headline)),
                  child: Text(l.homeAskMore),
                ),
              ],
            );
    } else if (_commute?.fromCurrentLocation ?? false) {
      top = _FromHerePass(
        departAt: _commute!.departAt,
        onCheck: _checkFromHere,
      );
    } else if (savedHome == null) {
      top = Pass(
        sections: [
          PassSection(
            child: EmptyState(
              icon: Symbols.home_pin_rounded,
              title: l.homeNoTripTitle,
              message: l.homeNoTripBody,
              action: FilledButton.icon(
                onPressed: () => _setPlace(PlaceKind.home),
                icon: const Icon(Symbols.home_rounded),
                label: Text(l.homeSetHome),
              ),
            ),
          ),
        ],
      );
    } else {
      final weekday = toBangkok(now).weekday;
      final workDay = (work?.days ?? SavedPlace.defaultWorkDays).contains(
        weekday,
      );
      top = Pass(
        sections: [
          PassSection(
            child: EmptyState(
              icon: Symbols.event_available_rounded,
              title: l.homeNoHomeTripTitle,
              message: store.workFromHome
                  ? l.homeWfhBody
                  : !workDay
                  ? l.homeNotWorkdayBody
                  : l.homePastCommuteBody,
            ),
          ),
        ],
      );
    }

    final hints = <Widget>[
      if (!_loading && here != null && here.lowAccuracy)
        Notice(
          icon: Symbols.location_searching_rounded,
          tone: NoticeTone.warning,
          text: l.homeGpsInaccurate(approxDistance(l, here.accuracyM ?? 1000)),
          action: TextButton(
            onPressed: _calibrateLocation,
            child: Text(l.homePinMyself),
          ),
        ),
      if (!_loading && savedHome == null && work != null)
        Notice(
          icon: Symbols.home_rounded,
          text: l.homeSetHomeHint,
          action: TextButton(
            onPressed: () => _setPlace(PlaceKind.home),
            child: Text(l.homeSetHome),
          ),
        ),
      if (!_loading && savedHome != null && work == null)
        Notice(
          icon: Symbols.work_rounded,
          text: l.homeSetWorkHint,
          action: TextButton(
            onPressed: () => _setPlace(PlaceKind.work),
            child: Text(l.homeSetWork),
          ),
        ),
      if (!_loading && store.workFromHome)
        Notice(icon: Symbols.home_work_rounded, text: l.homeWfhNotice),
      if (!_loading &&
          store.calendar != LinkState.connected &&
          !store.calendarHintDismissed)
        Notice(
          icon: Symbols.calendar_month_rounded,
          text: l.homeCalendarHint,
          action: TextButton(
            onPressed: () => _push(const SettingsScreen()),
            child: Text(l.homeConnect),
          ),
          onDismiss: store.dismissCalendarHint,
        ),
      if (!_loading &&
          (store.calendar == LinkState.connected ||
              store.gmail == LinkState.connected) &&
          !_hasCalendarSoon(now))
        Notice(icon: Symbols.event_busy_rounded, text: l.homeNoCalendarSoon),
    ];

    final others = _trips.where((x) => x.id != trip?.id).toList();

    final askBar = AskBar(
      onSubmit: _ask,
      hint: heroAsk ? l.homeAskHintHero : l.designAskHint,
    );

    return Scaffold(
      bottomNavigationBar: heroAsk
          ? null
          : ColoredBox(
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x2,
                  Space.gutter,
                  Space.x2,
                ),
                child: askBar,
              ),
            ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            edgeOffset: MediaQuery.paddingOf(context).top,
            child: CustomScrollView(
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
                            title: store.demoProfile
                                ? l.homeGreetingDemo
                                : l.homeGreeting,
                            subtitle: [
                              dayTime(l, now).split(' ').take(3).join(' '),
                              ?origin,
                              ?hereName,
                            ].join(' · '),
                            onSubtitleTap: hereName == null
                                ? null
                                : _calibrateLocation,
                            subtitleTapLabel: l.homeHereSemantics('$hereName'),
                            badge: store.demoProfile
                                ? const DemoBadge(onField: true)
                                : null,
                            actions: [
                              if (state.usingSample)
                                const SampleBadge(onField: true),
                              DemoClockChip(state: state, sky: sky),
                              IconButton(
                                tooltip: l.homeSettings,
                                onPressed: () => _push(const SettingsScreen()),
                                icon: const Icon(Symbols.settings_rounded),
                              ),
                            ],
                          ),
                          if (heroAsk)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.gutter,
                                Space.x4,
                                Space.gutter,
                                Space.x4,
                              ),
                              child: askBar,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.gutter,
                              Space.x2,
                              Space.gutter,
                              0,
                            ),
                            child: top,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hints.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.x6,
                        Space.gutter,
                        0,
                      ),
                      child: Column(
                        children: [
                          for (final (i, h) in hints.indexed) ...[
                            if (i > 0) const SizedBox(height: Space.x2),
                            h,
                          ],
                        ],
                      ),
                    ),
                  ),
                if (ctrl != null && d != null && trip != null)
                  SliverToBoxAdapter(
                    child: Section(
                      title: l.homeRouteTo(trip.destination.nameTh),
                      trailing: Text(
                        ctrl.previewing
                            ? l.homePreview(hhmm(ctrl.departAt))
                            : l.homeDepart(hhmm(ctrl.departAt)),
                        style: tabular(
                          t.labelLarge!,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                      child: DepartureBoard(
                        rows: [
                          for (final o in ctrl.board)
                            BoardRow(
                              key: ValueKey('mode-${o.mode.wire}'),
                              time: hhmm(o.arriveAt),
                              timeCaption: l.homeArriveCaption,
                              icon: o.mode.icon,
                              title: l.homeModeEta(o.mode.label(l), o.etaMin),
                              subtitle: o.noteTh,
                              risk: o.risk,
                              status: boardStatusText(l, o.verdict, o.risk),
                              selected: o.mode == ctrl.mode,
                              onTap: () => _openTrip(trip, mode: o.mode),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (others.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Section(
                      title: l.homeNextTrips,
                      child: Column(
                        children: [
                          for (final x in others)
                            SizedBox(
                              height: BoardRow.heightFor(
                                MediaQuery.textScalerOf(context),
                              ),
                              child: x.unresolved
                                  ? BoardRow(
                                      key: ValueKey('trip-${x.id}'),
                                      time: x.arriveBy == null
                                          ? '–'
                                          : hhmm(x.arriveBy!),
                                      timeCaption: x.arriveBy == null
                                          ? null
                                          : '${dayOfMonth(x.arriveBy!)} ${monthShort(l, x.arriveBy!)}',
                                      icon: sourceIcon(x.source),
                                      title: x.titleTh,
                                      subtitle: l.homeUnresolvedSubtitle(
                                        x.locationTextTh ?? '',
                                      ),
                                      risk: Risk.medium,
                                      status: l.homeUnresolvedStatus,
                                      onTap: () => _resolveTrip(x),
                                    )
                                  : BoardRow(
                                      key: ValueKey('trip-${x.id}'),
                                      time: x.arriveBy == null
                                          ? '–'
                                          : '${dayOfMonth(x.arriveBy!)} ${monthShort(l, x.arriveBy!)}',
                                      timeCaption: x.arriveBy == null
                                          ? null
                                          : hhmm(x.arriveBy!),
                                      icon: sourceIcon(x.source),
                                      title: x.titleTh,
                                      subtitle: l.homeFutureSubtitle(
                                        x.destination.nameTh,
                                      ),
                                      risk: Risk.low,
                                      status: l.homeFutureStatus,
                                      onTap: () => _openTrip(x),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (home != null && savedHome != null && !state.flood)
                  SliverToBoxAdapter(
                    child: Section(
                      title: l.homeTonightTitle,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Space.x3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        leading: const Icon(Symbols.home_rounded),
                        title: Text(home.headlineTh),
                        subtitle: Text(
                          home.canal == null
                              ? (home.inServiceArea
                                    ? l.homeNoCanalStation
                                    : l.homeOutOfArea)
                              : l.homeCanalLevel(
                                  home.canal!.nameTh,
                                  home.canal!.levelM.toStringAsFixed(1),
                                  home.canal!.bankM.toStringAsFixed(1),
                                ),
                          style: tabular(
                            t.bodySmall!,
                          ).copyWith(color: scheme.onSurfaceVariant),
                        ),
                        trailing: RiskChip(
                          risk: riskOfHomeLevel(home.level),
                          label: homeLevelText(l, home.level),
                          dense: true,
                        ),
                        onTap: () => Shell.goTo(context, ShellTab.home),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Section(
                    title: l.homeQuickAsk,
                    child: Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        if (savedHome != null)
                          ActionChip(
                            avatar: const Icon(Symbols.home_rounded, size: 18),
                            label: Text(l.homeQuestionHomeNow),
                            onPressed: () => _ask(l.homeQuestionHomeNow),
                          ),
                        for (final p in store.others)
                          ActionChip(
                            avatar: Icon(placeIcon(p.icon), size: 18),
                            label: Text(l.homeQuestionToNow(p.labelFor(l))),
                            onPressed: () =>
                                _ask(l.homeQuestionToNow(p.labelFor(l))),
                          ),
                        if (savedHome == null)
                          _GhostChip(
                            label: l.homeDefaultPlaceHome,
                            onPressed: () => _setPlace(PlaceKind.home),
                          ),
                        if (work == null)
                          _GhostChip(
                            label: l.homeDefaultPlaceWork,
                            onPressed: () => _setPlace(PlaceKind.work),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Space.x8)),
              ],
            ),
          ),
          if (showPush)
            Positioned(
              left: Space.x2,
              right: Space.x2,
              top: MediaQuery.paddingOf(context).top + Space.x1,
              child: NotificationBanner(
                time: hhmm(now),
                title: '${d.headlineTh} · ${trip.titleTh}',
                body: d.summaryTh,
                onOpen: () {
                  state.dismissPush();
                  _openTrip(trip);
                },
                onDismiss: state.dismissPush,
              ),
            ),
        ],
      ),
    );
  }

  bool _hasCalendarSoon(DateTime now) => _trips.any(
    (x) =>
        (x.source == 'calendar' || x.source == 'gmail') &&
        !x.unresolved &&
        x.arriveBy != null &&
        x.arriveBy!.isAfter(now) &&
        x.arriveBy!.difference(now) <= const Duration(hours: 24),
  );
}

LocateResult _pinned(PlaceCandidate c) => LocateResult(
  LocateStatus.ok,
  lat: c.lat,
  lng: c.lng,
  nameTh: c.nameTh,
  isManual: true,
  accuracyM: 10,
);

String _homeName(SavedPlace home) => home.addressTh.isEmpty
    ? home.nameTh
    : '${home.nameTh} · ${home.addressTh.split(' · ').first}';

/// A missing place, offered where it would appear: "+ บ้าน".
class _GhostChip extends StatelessWidget {
  const _GhostChip({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(Symbols.add_rounded, size: 18, color: scheme.primary),
      label: Text(label, style: TextStyle(color: scheme.primary)),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: scheme.primary.withValues(alpha: .5)),
      tooltip: context.l10n.homeSetPlaceTooltip(label),
      onPressed: onPressed,
    );
  }
}

/// Home saved, work not: the trip home starts from wherever the phone is,
/// so the app asks for the position only when the user taps.
class _FromHerePass extends StatelessWidget {
  const _FromHerePass({required this.departAt, required this.onCheck});
  final DateTime departAt;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    return Pass(
      semanticLabel: l.homeFromHereSemantics,
      sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.repeat_rounded, size: 18, color: c.paperMuted),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text(
                      l.homeFromHereTitle,
                      style: t.titleSmall!.copyWith(color: c.paperInk),
                    ),
                  ),
                  Text(
                    l.homeLeaveAround(hhmm(departAt)),
                    style: tabular(t.labelLarge!).copyWith(color: c.paperMuted),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              Text(
                l.homeCheckRainHome,
                style: t.headlineMedium!.copyWith(color: c.paperInk),
              ),
              const SizedBox(height: Space.x2),
              Text(
                l.homeLocationOnTap,
                style: t.bodyMedium!.copyWith(color: c.paperMuted),
              ),
              const SizedBox(height: Space.x4),
              FilledButton.icon(
                onPressed: onCheck,
                icon: const Icon(Symbols.near_me_rounded),
                label: Text(l.homeCheckWayHome),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
