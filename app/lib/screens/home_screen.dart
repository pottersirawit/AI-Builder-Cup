import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../models.dart';
import '../time_th.dart';
import '../trip_controller.dart';
import 'ask_screen.dart';
import 'parts.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'verdict_screen.dart';

/// Saved places offered as one-tap questions.
const savedPlaces = [
  (icon: Symbols.storefront_rounded, name: 'สยาม'),
  (icon: Symbols.nightlife_rounded, name: 'ทองหล่อ'),
  (icon: Symbols.stadium_rounded, name: 'อิมแพ็ค'),
];

/// Personal departure board: the sky, the top trip's pass, then the board.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _trips = const [];
  HomeStatus? _home;
  TripController? _ctrl;
  Object? _error;
  bool _loading = true;
  String? _loadedFor;

  Trip? get _topTrip =>
      _trips.where((t) => t.source == 'calendar').firstOrNull ?? _trips.firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = AppScope.stateOf(context).demoClock ?? 'live';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeF = api.homeStatus();
      final tripsR = await api.trips();
      final homeR = await homeF;
      if (!mounted) return;
      state
        ..markSample(tripsR.isSample || homeR.isSample)
        ..homeLevel = homeR.data.level;
      final trips = tripsR.data;
      final top = trips.where((t) => t.source == 'calendar').firstOrNull ?? trips.firstOrNull;
      _ctrl?.dispose();
      _ctrl = top == null
          ? null
          : (TripController(
              api: api,
              state: state,
              request: DecideRequest(tripId: top.id),
            )..addListener(_onTrip));
      setState(() {
        _trips = trips;
        _home = homeR.data;
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

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTrip(Trip trip, {TravelMode? mode}) {
    final c = _ctrl;
    final same = c != null && trip.id == _topTrip?.id;
    _push(VerdictScreen(
      request: DecideRequest(tripId: trip.id),
      trip: trip,
      departAt: same ? c.departAt : null,
      mode: mode ?? (same ? c.mode : null),
    ));
  }

  void _ask(String q) => _push(VerdictScreen(request: DecideRequest(questionTh: q)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ctrl = _ctrl;
    final trip = _topTrip;
    final home = _home;
    final now = state.now();
    final sky = state.flood ? SkyState.flood : (ctrl?.sky(home: state.homeLevel) ?? SkyState.clear);
    final d = ctrl?.decision;
    final showPush = d != null && trip != null && !state.pushDismissed && !state.flood;

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
    } else if (state.flood && home != null) {
      top = HomeStatusPass(status: home, now: now, actions: [
        FilledButton.icon(
          onPressed: () => Shell.goTo(context, ShellTab.home),
          icon: const Icon(Symbols.checklist_rounded),
          label: const Text('ดูสิ่งที่ต้องทำตอนนี้'),
        ),
      ]);
    } else if (trip == null || ctrl == null) {
      top = Pass(sections: [
        PassSection(
          child: EmptyState(
            icon: Symbols.event_available_rounded,
            title: 'วันนี้ยังไม่มีทริป',
            message: 'พิมพ์ถามด้านล่างได้เลย เช่น “ห้าโมงไปสยาม” หรือเชื่อม Google Calendar ให้แอปหาทริปเอง',
            action: OutlinedButton(
              onPressed: () => _push(const SettingsScreen()),
              child: const Text('เชื่อม Calendar'),
            ),
          ),
        ),
      ]);
    } else if (ctrl.error != null && d == null) {
      top = Pass(sections: [
        PassSection(
          child: ErrorState(title: 'ยังตัดสินไม่ได้', message: 'Gemini ไม่ตอบในรอบนี้', onRetry: ctrl.load),
        ),
      ]);
    } else {
      top = TripPass(
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
    }

    final others = _trips.where((x) => x.id != trip?.id).toList();

    return Scaffold(
      bottomNavigationBar: ColoredBox(
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x2),
          child: AskBar(onSubmit: _ask),
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
                            title: 'สวัสดีพลอย',
                            subtitle: '${dayTimeTh(now).split(' ').take(3).join(' ')} · ${trip?.origin.nameTh ?? 'สีลม'}',
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
                            child: top,
                          ),
                        ],
                      ),
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
                              child: BoardRow(
                                key: ValueKey('trip-${x.id}'),
                                time: '${dayOfMonth(x.arriveBy)} ${monthShortTh(x.arriveBy)}',
                                timeCaption: hhmm(x.arriveBy),
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
                if (home != null && !state.flood)
                  SliverToBoxAdapter(
                    child: Section(
                      title: 'ที่บ้านคืนนี้',
                      source: home.sources.join(' · '),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: Space.x3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                        leading: const Icon(Symbols.home_rounded),
                        title: Text(home.headlineTh),
                        subtitle: home.canal == null
                            ? null
                            : Text('${home.canal!.nameTh} ${home.canal!.levelM.toStringAsFixed(1)} จาก ${home.canal!.bankM.toStringAsFixed(1)} ม.',
                                style: tabular(t.bodySmall!).copyWith(color: scheme.onSurfaceVariant)),
                        trailing: RiskChip(risk: riskOfHomeLevel(home.level), label: homeLevelLabel(home.level), dense: true),
                        onTap: () => Shell.goTo(context, ShellTab.home),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Section(
                    title: 'ถามเร็ว',
                    source: 'Gemini แกะคำถามภาษาคนเป็นทริป · สถานที่จาก Google Maps ที่บันทึกไว้',
                    child: Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        for (final p in savedPlaces)
                          ActionChip(
                            avatar: Icon(p.icon, size: 18),
                            label: Text('ไป${p.name}ตอนนี้'),
                            onPressed: () => _ask('ไป${p.name}ตอนนี้'),
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
}
