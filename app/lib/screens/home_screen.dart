import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
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
    String sig(SavedPlace? p) => p == null ? '-' : '${p.id},${p.lat},${p.lng},${p.days},${p.leaveTime}';
    final key = '${state.demoClock ?? 'live'}|${sig(store.home)}|${sig(store.work)}|${store.calendar}|${store.demoProfile}';
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
    try {
      final homeF = home == null ? null : api.homeStatus(home: store.demoProfile ? null : home);
      final tripsR = store.calendar == LinkState.connected ? await api.trips() : null;
      final homeR = await homeF;
      if (!mounted) return;
      state
        ..markSample((tripsR?.isSample ?? false) || (homeR?.isSample ?? false))
        ..homeLevel = homeR?.data.level ?? HomeLevel.normal;
      final trips = tripsR?.data ?? const <Trip>[];
      final now = state.now();
      if (store.manualLocation != null) {
        state.currentLocation = LocateResult(
          LocateStatus.ok,
          lat: store.manualLocation!.lat,
          lng: store.manualLocation!.lng,
          nameTh: store.manualLocation!.nameTh,
          isManual: true,
          accuracyM: 10,
        );
      } else {
        final locator = AppScope.locatorOf(context);
        try {
          final loc = await locator.locate(prompt: false);
          if (loc.ok && mounted) {
            state.currentLocation = loc;
          }
        } catch (_) {}
      }
      final resolved = trips.where((t) => !t.unresolved).toList();
      final headsHomeToday = home != null &&
          resolved.any((t) =>
              home.distanceTo(t.destination.lat, t.destination.lng) <= PlacesStore.duplicateRadiusM &&
              t.arriveBy != null &&
              toBangkok(t.arriveBy!).day == toBangkok(now).day);
      final commute = headsHomeToday ? null : commuteFor(home: home, work: store.work, now: now);
      final routine = commute != null && !commute.fromCurrentLocation ? commute.trip : null;
      final top = resolved.where((t) => t.source == 'calendar').firstOrNull ?? routine ?? resolved.firstOrNull;
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

  /// Server trips go by id; the app's own trips send their endpoints.
  DecideRequest _requestFor(Trip t) => t.source == 'routine' || t.source == 'app'
      ? DecideRequest(origin: t.origin, destination: t.destination)
      : DecideRequest(tripId: t.id);

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTrip(Trip trip, {TravelMode? mode, DateTime? departAt}) {
    final c = _ctrl;
    final same = c != null && trip.id == _top?.id;
    _push(VerdictScreen(
      request: _requestFor(trip),
      trip: trip,
      departAt: departAt ?? (same ? c.departAt : null),
      mode: mode ?? (same ? c.mode : null),
    ));
  }

  void _ask(String q) {
    final loc = AppScope.readState(context).currentLocation;
    final origin = loc?.ok == true
        ? Place(nameTh: loc!.nameTh ?? 'ตำแหน่งตอนนี้', lat: loc.lat, lng: loc.lng)
        : null;
    _push(VerdictScreen(
      request: DecideRequest(
        questionTh: q,
        origin: origin,
        places: AppScope.readPlaces(context).places,
      ),
    ));
  }

  Future<void> _calibrateLocation() async {
    final candidate = await pickPoint(context);
    if (candidate == null || !mounted) return;
    final store = AppScope.readPlaces(context);
    store.setManualLocation(candidate);
    final state = AppScope.readState(context);
    state.currentLocation = LocateResult(
      LocateStatus.ok,
      lat: candidate.lat,
      lng: candidate.lng,
      nameTh: candidate.nameTh,
      isManual: true,
      accuracyM: 10,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ปักหมุดตำแหน่งปัจจุบันที่ “${candidate.nameTh}” แล้ว'),
          action: SnackBarAction(
            label: 'ใช้ GPS แทน',
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
    final here = state.currentLocation?.ok == true
        ? PlaceCandidate(
            nameTh: state.currentLocation!.nameTh ?? 'ตำแหน่งตอนนี้',
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
        titleTh: 'กลับบ้าน',
        source: 'app',
        origin: Place(nameTh: here.source == 'gps' || here.source == 'manual' ? (state.currentLocation?.nameTh ?? 'ตำแหน่งตอนนี้') : here.nameTh, lat: here.lat, lng: here.lng),
        destination: home.asPlace,
        arriveBy: null,
        mode: TravelMode.car,
      ),
      departAt: commute?.departAt,
    );
  }

  /// A Calendar event whose location the server could not place.
  Future<void> _resolveTrip(Trip t) async {
    final saved = await pickPlace(context, kind: PlaceKind.other, initialQuery: t.locationTextTh);
    if (saved == null || !mounted) return;
    _openTrip(Trip(
      id: 'app-${t.id}',
      titleTh: t.titleTh,
      source: 'app',
      origin: t.origin,
      destination: saved.asPlace,
      arriveBy: t.arriveBy,
      mode: t.mode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ctrl = _ctrl;
    final trip = _top;
    final home = _home;
    final savedHome = store.home;
    final work = store.work;
    final now = state.now();
    final sky = state.flood ? SkyState.flood : (ctrl?.sky(home: state.homeLevel) ?? SkyState.clear);
    final d = ctrl?.decision;
    final showPush = d != null && trip != null && !state.pushDismissed && !state.flood;
    final heroAsk = !_loading && _error == null && trip == null && savedHome == null && _commute == null;

    Widget top;
    if (_error != null) {
      top = Pass(sections: [
        PassSection(
          child: ErrorState(
            title: 'โหลดทริปไม่ได้',
            message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้และไม่มีข้อมูลตัวอย่างในเครื่อง ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
            onRetry: _load,
          ),
        ),
      ]);
    } else if (_loading) {
      top = const PassSkeleton();
    } else if (state.flood && home != null && savedHome != null) {
      top = HomeStatusPass(status: home, now: now, placeName: _homeName(savedHome), actions: [
        FilledButton.icon(
          onPressed: () => Shell.goTo(context, ShellTab.home),
          icon: const Icon(Symbols.checklist_rounded),
          label: const Text('ดูสิ่งที่ต้องทำตอนนี้'),
        ),
      ]);
    } else if (trip != null && ctrl != null) {
      top = ctrl.error != null && d == null
          ? Pass(sections: [
              PassSection(
                child: ErrorState(title: 'ยังตัดสินไม่ได้', message: 'Gemini ไม่ตอบในรอบนี้', onRetry: ctrl.load),
              ),
            ])
          : TripPass(
              controller: ctrl,
              now: now,
              trip: trip,
              compact: true,
              onTap: () => _openTrip(trip),
              actions: [
                FilledButton(onPressed: () => _openTrip(trip), child: const Text('ดูเหตุผลและทางเลือก')),
                OutlinedButton(
                  onPressed: () => _push(AskScreen(trip: trip, opening: ctrl.headline)),
                  child: const Text('ถามต่อ'),
                ),
              ],
            );
    } else if (_commute?.fromCurrentLocation ?? false) {
      top = _FromHerePass(departAt: _commute!.departAt, onCheck: _checkFromHere);
    } else if (savedHome == null) {
      top = Pass(sections: [
        PassSection(
          child: EmptyState(
            icon: Symbols.home_pin_rounded,
            title: 'ยังไม่มีทริป',
            message: 'ตั้งบ้านไว้ แอปจะเตือนก่อนเวลาเลิกงานทุกวัน หรือพิมพ์ถามด้านบนได้เลย',
            action: FilledButton.icon(
              onPressed: () => _setPlace(PlaceKind.home),
              icon: const Icon(Symbols.home_rounded),
              label: const Text('ตั้งบ้าน'),
            ),
          ),
        ),
      ]);
    } else {
      final weekday = toBangkok(now).weekday;
      final workDay = (work?.days ?? SavedPlace.defaultWorkDays).contains(weekday);
      top = Pass(sections: [
        PassSection(
          child: EmptyState(
            icon: Symbols.event_available_rounded,
            title: 'วันนี้ไม่มีทริปกลับบ้าน',
            message: store.workFromHome
                ? 'ทำงานที่บ้าน แอปจะเตือนเฉพาะทริปอื่น พิมพ์ถามด้านล่างได้เลย เช่น “ห้าโมงไปสยาม”'
                : !workDay
                    ? 'วันนี้ไม่ใช่วันทำงาน ถ้าจะออกไปไหน พิมพ์ถามด้านล่างได้เลย'
                    : 'เลยเวลากลับบ้านปกติมาแล้ว พรุ่งนี้แอปจะเช็กให้ก่อนเลิกงาน',
          ),
        ),
      ]);
    }

    final hints = <Widget>[
      if (!_loading && state.currentLocation != null && state.currentLocation!.lowAccuracy)
        Notice(
          icon: Symbols.location_searching_rounded,
          tone: NoticeTone.warning,
          text: 'ตำแหน่งจาก Wi-Fi/IP อาจคลาดเคลื่อน (~${((state.currentLocation!.accuracyM ?? 1000) / 10).round() * 10} ม.)',
          action: TextButton(
            onPressed: _calibrateLocation,
            child: const Text('ระบุจุดเอง'),
          ),
        ),
      if (!_loading && savedHome == null && work != null)
        Notice(
          icon: Symbols.home_rounded,
          text: 'ตั้งบ้านเพื่อให้เตือนตอนกลับ',
          action: TextButton(onPressed: () => _setPlace(PlaceKind.home), child: const Text('ตั้งบ้าน')),
        ),
      if (!_loading && savedHome != null && work == null)
        Notice(
          icon: Symbols.work_rounded,
          text: 'ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น',
          action: TextButton(onPressed: () => _setPlace(PlaceKind.work), child: const Text('ตั้งที่ทำงาน')),
        ),
      if (!_loading && store.workFromHome)
        const Notice(icon: Symbols.home_work_rounded, text: 'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น'),
      if (!_loading && store.calendar != LinkState.connected && !store.calendarHintDismissed)
        Notice(
          icon: Symbols.calendar_month_rounded,
          text: 'เชื่อม Calendar เพื่อให้แอปเห็นนัด',
          action: TextButton(onPressed: () => _push(const SettingsScreen()), child: const Text('เชื่อมต่อ')),
          onDismiss: store.dismissCalendarHint,
        ),
      if (!_loading && store.calendar == LinkState.connected && !_hasCalendarSoon(now))
        const Notice(icon: Symbols.event_busy_rounded, text: 'ไม่มีนัดที่มีสถานที่ใน 24 ชม.'),
    ];

    final others = _trips.where((x) => x.id != trip?.id).toList();

    final askBar = AskBar(onSubmit: _ask, hint: heroAsk ? 'ไปไหน กี่โมง?' : 'ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม');

    return Scaffold(
      bottomNavigationBar: heroAsk
          ? null
          : ColoredBox(
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x2),
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
                            title: store.demoProfile ? 'สวัสดีมิว' : 'สวัสดี',
                            subtitle: [
                              dayTimeTh(now).split(' ').take(3).join(' '),
                              if (trip != null && trip.origin.nameTh.isNotEmpty)
                                trip.origin.nameTh
                              else if (state.currentLocation?.ok == true)
                                state.currentLocation!.nameTh ?? 'ตำแหน่งปัจจุบัน',
                            ].join(' · '),
                            onSubtitleTap: _calibrateLocation,
                            badge: store.demoProfile ? const DemoBadge(onField: true) : null,
                            actions: [
                              if (state.usingSample) const SampleBadge(onField: true),
                              DemoClockChip(state: state, sky: sky),
                              IconButton(
                                tooltip: 'ตั้งค่า',
                                onPressed: () => _push(const SettingsScreen()),
                                icon: const Icon(Symbols.settings_rounded),
                              ),
                            ],
                          ),
                          if (heroAsk)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x4),
                              child: askBar,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
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
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x6, Space.gutter, 0),
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
                      title: 'ทางกลับ${trip.destination.nameTh}',
                      trailing: Text(
                        ctrl.previewing ? 'พรีวิว ${hhmm(ctrl.departAt)}' : 'ออก ${hhmm(ctrl.departAt)}',
                        style: tabular(t.labelLarge!).copyWith(color: scheme.onSurfaceVariant),
                      ),
                      source: 'Google Routes API · จุดน้ำท่วม กทม. · จัดอันดับ: ไปได้ก่อน เสี่ยงน้อยก่อน ถึงก่อนก่อน',
                      child: DepartureBoard(rows: [
                        for (final o in ctrl.board)
                          BoardRow(
                            key: ValueKey('mode-${o.mode.wire}'),
                            time: hhmm(o.arriveAt),
                            timeCaption: 'ถึง',
                            icon: o.mode.icon,
                            title: '${o.mode.labelTh} · ${o.etaMin} นาที',
                            subtitle: o.noteTh,
                            risk: o.risk,
                            status: boardStatus(o.verdict, o.risk),
                            selected: o.mode == ctrl.mode,
                            onTap: () => _openTrip(trip, mode: o.mode),
                          ),
                      ]),
                    ),
                  ),
                if (others.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Section(
                      title: 'ทริปถัดไป',
                      source: others.map((x) => sourceTitle(x.source)).toSet().join(' · '),
                      child: Column(
                        children: [
                          for (final x in others)
                            SizedBox(
                              height: BoardRow.heightFor(MediaQuery.textScalerOf(context)),
                              child: x.unresolved
                                  ? BoardRow(
                                      key: ValueKey('trip-${x.id}'),
                                      time: x.arriveBy == null ? '–' : hhmm(x.arriveBy!),
                                      timeCaption: x.arriveBy == null ? null : '${dayOfMonth(x.arriveBy!)} ${monthShortTh(x.arriveBy!)}',
                                      icon: sourceIcon(x.source),
                                      title: x.titleTh,
                                      subtitle: '“${x.locationTextTh}” · แตะเพื่อเลือกสถานที่',
                                      risk: Risk.medium,
                                      status: 'ไม่รู้ว่าที่ไหน',
                                      onTap: () => _resolveTrip(x),
                                    )
                                  : BoardRow(
                                      key: ValueKey('trip-${x.id}'),
                                      time: x.arriveBy == null ? '–' : '${dayOfMonth(x.arriveBy!)} ${monthShortTh(x.arriveBy!)}',
                                      timeCaption: x.arriveBy == null ? null : hhmm(x.arriveBy!),
                                      icon: sourceIcon(x.source),
                                      title: x.titleTh,
                                      subtitle: '${x.destination.nameTh} · จะเตือนวันเดินทางว่าออกกี่โมงดี',
                                      risk: Risk.low,
                                      status: 'รอวัน',
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
                      title: 'ที่บ้านคืนนี้',
                      source: home.sources.join(' · '),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: Space.x3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                        leading: const Icon(Symbols.home_rounded),
                        title: Text(home.headlineTh),
                        subtitle: Text(
                            home.canal == null
                                ? (home.inServiceArea ? 'ไม่มีสถานีวัดระดับคลองใกล้บ้าน' : 'นอกพื้นที่ที่รองรับ · มีเฉพาะข้อมูลฝน')
                                : '${home.canal!.nameTh} ${home.canal!.levelM.toStringAsFixed(1)} จาก ${home.canal!.bankM.toStringAsFixed(1)} ม.',
                            style: tabular(t.bodySmall!).copyWith(color: scheme.onSurfaceVariant)),
                        trailing: RiskChip(risk: riskOfHomeLevel(home.level), label: homeLevelLabel(home.level), dense: true),
                        onTap: () => Shell.goTo(context, ShellTab.home),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Section(
                    title: 'ถามเร็ว',
                    source: 'Gemini แกะคำถามภาษาคนเป็นทริป · สถานที่ที่บันทึกไว้ในเครื่องนี้',
                    child: Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        if (savedHome != null)
                          ActionChip(
                            avatar: const Icon(Symbols.home_rounded, size: 18),
                            label: const Text('กลับบ้านตอนนี้'),
                            onPressed: () => _ask('กลับบ้านตอนนี้'),
                          ),
                        for (final p in store.others)
                          ActionChip(
                            avatar: Icon(placeIcon(p.icon), size: 18),
                            label: Text('ไป${p.labelTh}ตอนนี้'),
                            onPressed: () => _ask('ไป${p.labelTh}ตอนนี้'),
                          ),
                        if (savedHome == null) _GhostChip(label: 'บ้าน', onPressed: () => _setPlace(PlaceKind.home)),
                        if (work == null) _GhostChip(label: 'ที่ทำงาน', onPressed: () => _setPlace(PlaceKind.work)),
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

  bool _hasCalendarSoon(DateTime now) => _trips.any((x) =>
      x.source == 'calendar' &&
      !x.unresolved &&
      x.arriveBy != null &&
      x.arriveBy!.isAfter(now) &&
      x.arriveBy!.difference(now) <= const Duration(hours: 24));
}

String _homeName(SavedPlace home) =>
    home.addressTh.isEmpty ? home.nameTh : '${home.nameTh} · ${home.addressTh.split(' · ').first}';

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
      tooltip: 'ตั้ง$label',
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
    return Pass(semanticLabel: 'กลับบ้าน จากตำแหน่งตอนนี้', sections: [
      PassSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Symbols.repeat_rounded, size: 18, color: c.paperMuted),
              const SizedBox(width: Space.x2),
              Expanded(child: Text('กลับบ้าน · จากตำแหน่งตอนนี้', style: t.titleSmall!.copyWith(color: c.paperInk))),
              Text('ออกราว ${hhmm(departAt)}', style: tabular(t.labelLarge!).copyWith(color: c.paperMuted)),
            ]),
            const SizedBox(height: Space.x3),
            Text('เช็กฝนบนทางกลับบ้าน', style: t.headlineMedium!.copyWith(color: c.paperInk)),
            const SizedBox(height: Space.x2),
            Text('แอปใช้ตำแหน่งตอนกดเท่านั้น เพื่อเป็นจุดเริ่มต้นของทาง',
                style: t.bodyMedium!.copyWith(color: c.paperMuted)),
            const SizedBox(height: Space.x4),
            FilledButton.icon(
              onPressed: onCheck,
              icon: const Icon(Symbols.near_me_rounded),
              label: const Text('เช็กทางกลับบ้าน'),
            ),
          ],
        ),
      ),
    ]);
  }
}
