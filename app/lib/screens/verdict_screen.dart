import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../time_th.dart';
import '../widgets/common.dart';
import 'ask_screen.dart';

/// Departure slider runs 16:00 to 20:00 in 15-minute steps, as in the prototype.
const _sliderStartHour = 16;
const _sliderSteps = 16;

class VerdictScreen extends StatefulWidget {
  const VerdictScreen({super.key, required this.request, this.trip});

  /// Either a trip id or a Thai question; departure and mode are filled in here.
  final DecideRequest request;
  final Trip? trip;

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  late TravelMode _mode;
  late int _step;
  Decision? _decision;
  bool _loading = false;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    final state = AppScope.readState(context);
    _mode = widget.request.mode ?? state.mode;
    final now = toBangkok(state.now());
    final minutes = (now.hour - _sliderStartHour) * 60 + now.minute;
    _step = (minutes / 15).ceil().clamp(0, _sliderSteps);
    _load();
  }

  DateTime get _departAt {
    final day = toBangkok(AppScope.readState(context).now());
    // Bangkok wall-clock on the scenario day, expressed in UTC.
    return DateTime.utc(day.year, day.month, day.day, _sliderStartHour, _step * 15)
        .subtract(const Duration(hours: 7));
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() => _loading = true);
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final req = widget.request.copyWith(departAt: isoBangkok(_departAt), mode: _mode);
    final d = state.track(await api.decide(req));
    if (!mounted || seq != _requestSeq) return;
    setState(() {
      _decision = d;
      _loading = false;
    });
  }

  void _setMode(TravelMode m) {
    if (m == _mode) return;
    _mode = m;
    _load();
  }

  String get _tripLine {
    final t = widget.trip;
    if (t != null) {
      return '${t.origin.nameTh} → ${t.destination.nameTh} · '
          'นัด ${hhmm(t.arriveBy)} ${t.titleTh} (${t.source == 'gmail' ? 'Gmail' : 'Calendar'})';
    }
    return 'คำถาม: “${widget.request.questionTh ?? ''}”';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final d = _decision;
    final depart = hhmm(_departAt);
    final trip = widget.trip;

    return SubScreen(
      title: 'ฝนตกไหม',
      loading: _loading,
      onRefresh: _load,
      children: [
        const SizedBox(height: 6),
        Eyebrow(_tripLine),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('ถ้าออก ', style: txt(context, size: 20, weight: FontWeight.w700)),
            GeminiText(depart, style: txt(context, size: 20)),
            Text(' ล่ะ?', style: txt(context, size: 20, weight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: _step.toDouble(),
          min: 0,
          max: _sliderSteps.toDouble(),
          divisions: _sliderSteps,
          label: depart,
          onChanged: (v) => setState(() => _step = v.round()),
          onChangeEnd: (_) => _load(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var h = _sliderStartHour; h <= _sliderStartHour + _sliderSteps ~/ 4; h++)
                Text('$h:00', style: txt(context, size: 11, color: p.muted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ModeToggle(selected: _mode, onChanged: _setMode),
        if (d == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          VerdictCard(
            tone: Tone.ofVerdict(d.verdict),
            eyebrow: 'ออก $depart · ${_mode.emoji} ${_mode.labelTh}'
                '${d.leaveBy == null ? '' : ' · ควรออกก่อน ${hhmm(d.leaveBy!)}'}',
            headline: d.headlineTh,
            summary: d.summaryTh,
            confidence: d.confidence,
            actions: [
              if (trip != null)
                OnColorButton(
                  label: 'ถามต่อ',
                  solidColor: Tone.ofVerdict(d.verdict).fg,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => AskScreen(trip: trip, opening: d.headlineTh),
                  )),
                ),
            ],
          ),
          if (d.modeOptions.isNotEmpty) _ModeOptionsCard(options: d.modeOptions, selected: _mode, onPick: _setMode),
          _FloodSpotsCard(
            title: trip == null
                ? 'จุดน้ำท่วมบนเส้นทาง'
                : 'เส้นทาง ${trip.origin.nameTh} → ${trip.destination.nameTh}',
            spots: d.floodSpots,
            eta: d.modeOptions.where((o) => o.mode == _mode).firstOrNull,
          ),
          _ReasoningCard(decision: d),
        ],
      ],
    );
  }
}

class _ModeOptionsCard extends StatelessWidget {
  const _ModeOptionsCard({required this.options, required this.selected, required this.onPick});
  final List<ModeOption> options;
  final TravelMode selected;
  final ValueChanged<TravelMode> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('เทียบทุกวิธีเดินทาง', style: txt(context, size: 15, weight: FontWeight.w700)),
          for (final o in options)
            InkWell(
              onTap: () => onPick(o.mode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 4), child: Dot(Tone.ofRisk(o.risk))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${o.mode.emoji} ${o.mode.labelTh} · ${o.etaMin} นาที',
                              style: txt(context,
                                  size: 13,
                                  weight: o.mode == selected ? FontWeight.w700 : FontWeight.w600)),
                          Text(o.noteTh, style: txt(context, size: 13, color: p.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SourceLabel('ระยะพ้นน้ำตามประเภทรถ · Google Routes API'),
        ],
      ),
    );
  }
}

class _FloodSpotsCard extends StatelessWidget {
  const _FloodSpotsCard({required this.title, required this.spots, this.eta});
  final String title;
  final List<FloodSpot> spots;
  final ModeOption? eta;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: txt(context, size: 15, weight: FontWeight.w700))),
              if (eta != null) Pill('${eta!.etaMin} นาที', tone: Tone.ofRisk(eta!.risk)),
            ],
          ),
          const SizedBox(height: 6),
          if (spots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Dot(Tone.ok),
                  const SizedBox(width: 10),
                  Expanded(child: Text('ไม่มีจุดน้ำขังบนเส้นทางนี้', style: txt(context, size: 13))),
                ],
              ),
            ),
          for (final s in spots)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Row(
                children: [
                  Dot(Tone.ofRisk(s.risk)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.nameTh, style: txt(context, size: 13))),
                  Text(
                    s.expectedDepthCm > 0 ? 'คาดน้ำ ${s.expectedDepthCm.round()} ซม.' : 'ยังแห้ง',
                    style: txt(context, size: 12, color: p.muted),
                  ),
                ],
              ),
            ),
          const SourceLabel('Google Routes API (traffic aware) · จุดน้ำท่วม กทม. · รายงานผู้ใช้'),
        ],
      ),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({required this.decision});
  final Decision decision;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fallback = decision.generatedBy == 'fallback';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeminiText('Gemini คิดแบบนี้', style: txt(context, size: 15)),
          const SizedBox(height: 4),
          for (final r in decision.reasoning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(6)),
                    child: Text(r.tool,
                        style: txt(context, size: 11, color: p.accent).copyWith(fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 3),
                  Text(r.summaryTh, style: txt(context, size: 13, height: 1.45)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in decision.sources) Pill(s)],
          ),
          SourceLabel(fallback
              ? 'กฎสำรองเมื่อ Gemini ไม่ตอบ · ความมั่นใจ ${percent(decision.confidence)}'
              : 'Gemini on Vertex AI · เหตุผลจากข้อมูลจริง · ความมั่นใจ ${percent(decision.confidence)}'),
        ],
      ),
    );
  }
}
