import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../time_th.dart';
import '../widgets/common.dart';
import 'ask_screen.dart';
import 'flood_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'verdict_screen.dart';

/// Saved places shown as chips under the ask bar.
const savedPlaces = [
  (emoji: '🏠', name: 'บ้าน'),
  (emoji: '🛍', name: 'สยาม'),
  (emoji: '🍸', name: 'ทองหล่อ'),
  (emoji: '🎤', name: 'อิมแพ็ค'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _trips = const [];
  Decision? _decision;
  HomeStatus? _home;
  bool _loading = true;
  String? _loadedFor;
  TravelMode? _loadedMode;
  final _ask = TextEditingController();

  Trip? get _calendarTrip => _trips.where((t) => t.source == 'calendar').firstOrNull;
  Trip? get _gmailTrip => _trips.where((t) => t.source == 'gmail').firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.stateOf(context);
    final key = state.demoClock ?? 'live';
    if (key != _loadedFor || state.mode != _loadedMode) {
      _loadedFor = key;
      _loadedMode = state.mode;
      _load();
    }
  }

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    // Also called from didChangeDependencies, where the next build follows.
    _loading = true;
    final homeF = api.homeStatus();
    final tripsR = await api.trips();
    final trips = tripsR.data;
    final trip = trips.where((t) => t.source == 'calendar').firstOrNull ?? trips.firstOrNull;
    final decisionR = trip == null
        ? null
        : await api.decide(DecideRequest(
            tripId: trip.id,
            departAt: isoBangkok(state.now()),
            mode: state.mode,
          ));
    final homeR = await homeF;
    state.markSample(tripsR.isSample || homeR.isSample || (decisionR?.isSample ?? false));
    final decision = decisionR?.data;
    final home = homeR.data;
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _decision = decision;
      _home = home;
      _loading = false;
    });
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openTrip() {
    final trip = _calendarTrip;
    if (trip == null) return;
    _push(VerdictScreen(
      request: DecideRequest(tripId: trip.id, mode: AppScope.readState(context).mode),
      trip: trip,
    ));
  }

  void _askQuestion(String q) {
    if (q.trim().isEmpty) return;
    _push(VerdictScreen(request: DecideRequest(questionTh: q.trim())));
    _ask.clear();
  }

  void _openPlace(String name) {
    final trip = _calendarTrip;
    if (name == 'บ้าน' && trip != null) return _openTrip();
    _push(VerdictScreen(request: DecideRequest(questionTh: 'ไป$nameตอนนี้')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final p = Palette.of(context);
    final trip = _calendarTrip;
    final d = _decision;
    final home = _home;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ClockBar(),
            SizedBox(height: 2, child: _loading ? const LinearProgressIndicator(minHeight: 2) : null),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    if (d != null && trip != null && !state.pushDismissed)
                      _PushBanner(
                        title: '${d.headlineTh} · ${trip.titleTh}',
                        body: d.summaryTh,
                        onTap: _openTrip,
                        onClose: state.dismissPush,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow('${trip?.origin.nameTh ?? 'สีลม'} · ตอนนี้ครึ้ม 30°'),
                              Text('สวัสดีพลอย', style: txt(context, size: 24, weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const Logo(),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'ตั้งค่า',
                          onPressed: () => _push(const SettingsScreen()),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    _AskBar(controller: _ask, onSubmit: _askQuestion),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final place in savedPlaces)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PlaceChip(
                                label: '${place.emoji} ${place.name}',
                                onTap: () => _openPlace(place.name),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SourceLabel(
                      'Gemini แกะคำถามภาษาคนเป็นทริป · สถานที่จาก Google Maps ที่บันทึกไว้',
                      padding: EdgeInsets.only(top: 8, left: 4),
                    ),
                    if (home != null && home.level == HomeLevel.danger)
                      _FloodAlertCard(home: home, onTap: () => _push(const FloodScreen())),
                    if (d != null && trip != null) ...[
                      VerdictCard(
                        tone: Tone.ofVerdict(d.verdict),
                        eyebrow: 'กลับ${trip.destination.nameTh} · ${state.mode.labelTh}',
                        headline: d.headlineTh,
                        summary: d.summaryTh,
                        confidence: d.confidence,
                        actions: [
                          OnColorButton(
                            label: 'ดูเหตุผล / เลื่อนเวลา',
                            solidColor: Tone.ofVerdict(d.verdict).fg,
                            onPressed: _openTrip,
                          ),
                          OnColorButton(
                            label: 'ถามต่อ',
                            solid: false,
                            onPressed: () => _push(AskScreen(trip: trip, opening: d.headlineTh)),
                          ),
                        ],
                      ),
                      SourceLabel(
                        '${d.generatedBy == 'fallback' ? 'กฎสำรอง' : 'Gemini'} ตัดสินจาก '
                        '${d.sources.join(' + ')} · อัปเดต ${hhmm(state.now())}',
                        padding: const EdgeInsets.only(top: 10, left: 4),
                      ),
                    ],
                    if (d != null && d.rainTimeline.isNotEmpty)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ฝนบนเส้นทาง ${hhmm(d.rainTimeline.first.time)} ถึง '
                                    '${hhmm(d.rainTimeline.last.time.add(const Duration(minutes: 15)))}',
                                    style: txt(context, size: 15, weight: FontWeight.w700),
                                  ),
                                ),
                                Pill('ตอนนี้ ${hhmm(state.now())}'),
                              ],
                            ),
                            RainTimeline(d.rainTimeline),
                            const SourceLabel('Google Weather API รายชั่วโมง 3 กม. · กรมอุตุฯ NWP'),
                          ],
                        ),
                      ),
                    if (trip != null && state.toggles['calendar']!)
                      _CalendarCard(trip: trip),
                    if (home != null)
                      AppCard(
                        onTap: () => _push(const FloodScreen()),
                        child: _HomeRiskSummary(
                          placeName: trip?.destination.nameTh ?? 'บ้าน',
                          home: home,
                        ),
                      ),
                    if (_gmailTrip != null && state.toggles['gmail']!)
                      _GmailCard(trip: _gmailTrip!),
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: () => _push(const ReportScreen()),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('📷 เจอน้ำท่วม? ถ่ายรูปบอกเพื่อนร่วมทาง',
                          style: txt(context, weight: FontWeight.w600, color: p.accent)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In-app stand-in for the 16:10 push notification.
class _PushBanner extends StatelessWidget {
  const _PushBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onClose,
  });
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Material(
        color: Colors.white.withValues(alpha: .95),
        elevation: 8,
        shadowColor: const Color(0x55000000),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Logo(),
                    const Spacer(),
                    Text('ตอนนี้', style: txt(context, size: 12, color: p.muted)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'ปิด',
                      onPressed: onClose,
                      icon: Icon(Icons.close, size: 18, color: p.muted),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: txt(context, size: 16, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(body, style: txt(context, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AskBar extends StatelessWidget {
  const _AskBar({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x14143C78), blurRadius: 24, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmit,
              textInputAction: TextInputAction.send,
              style: txt(context),
              decoration: InputDecoration.collapsed(
                hintText: 'ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม',
                hintStyle: txt(context, color: const Color(0xFF8A99B3)),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => onSubmit(controller.text),
            child: Ink(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(colors: [kBlue2, kViolet]),
              ),
              child: const Icon(Icons.send_rounded, size: 18, color: Colors.white, semanticLabel: 'ถาม'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('ทำไมถึงเตือนตอนนี้'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(monthShortTh(trip.arriveBy),
                        style: txt(context, size: 11, weight: FontWeight.w700, color: p.accent)),
                    Text('${dayOfMonth(trip.arriveBy)}',
                        style: txt(context, size: 16, weight: FontWeight.w700, color: p.accent, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${hhmm(trip.arriveBy)} ${trip.titleTh}', style: txt(context, weight: FontWeight.w700)),
                    Text('${trip.destination.nameTh} · ต้องถึงก่อน ${hhmm(trip.arriveBy)}',
                        style: txt(context, size: 13, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SourceLabel('Google Calendar'),
        ],
      ),
    );
  }
}

class _HomeRiskSummary extends StatelessWidget {
  const _HomeRiskSummary({required this.placeName, required this.home});
  final String placeName;
  final HomeStatus home;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final canal = home.canal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(placeName),
                  const SizedBox(height: 4),
                  Text(home.headlineTh, style: txt(context, weight: FontWeight.w700)),
                  if (canal != null)
                    Text(canalSummary(canal), style: txt(context, size: 13, color: p.muted)),
                ],
              ),
            ),
            Pill(homeLevelLabel(home.level), tone: Tone.ofHomeLevel(home.level)),
          ],
        ),
        SourceLabel(home.sources.join(' · ')),
      ],
    );
  }
}

String homeLevelLabel(HomeLevel l) => switch (l) {
      HomeLevel.normal => 'ปกติ',
      HomeLevel.watch => 'จับตา',
      HomeLevel.danger => 'อันตราย',
    };

String canalSummary(Canal c) {
  final gap = c.bankM - c.levelM;
  final vsBank = gap > 0.05 ? 'ต่ำกว่าตลิ่ง ${gap.toStringAsFixed(1)} ม.' : 'ถึงตลิ่งแล้ว';
  return '${c.nameTh} ${c.levelM.toStringAsFixed(1)} ม. $vsBank '
      'ขึ้น ${c.riseCm2h.round()} ซม. ใน 2 ชั่วโมง';
}

class _FloodAlertCard extends StatelessWidget {
  const _FloodAlertCard({required this.home, required this.onTap});
  final HomeStatus home;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: VerdictCard(
          tone: Tone.bad,
          eyebrow: 'โหมดน้ำท่วม · บ้าน',
          headline: home.headlineTh,
          summary: home.canal == null ? '' : canalSummary(home.canal!),
          actions: [OnColorButton(label: 'ดูสิ่งที่ต้องทำ', solidColor: Tone.bad.fg, onPressed: onTap)],
        ),
      );
}

class _GmailCard extends StatelessWidget {
  const _GmailCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('เจอในอีเมล'),
                    const SizedBox(height: 4),
                    Text('${trip.titleTh} ${dayTimeTh(trip.arriveBy)}',
                        style: txt(context, weight: FontWeight.w700)),
                    Text('${trip.destination.nameTh} · จะเตือนก่อนวันเดินทางว่าออกกี่โมงดี',
                        style: txt(context, size: 13, color: p.muted)),
                  ],
                ),
              ),
              const Pill('เพิ่มแล้ว'),
            ],
          ),
          const SourceLabel('Gmail · อ่านเฉพาะอีเมลยืนยันตั๋วเมื่ออนุญาต'),
        ],
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: p.card,
      shape: StadiumBorder(side: BorderSide(color: p.line, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: txt(context, size: 13, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
