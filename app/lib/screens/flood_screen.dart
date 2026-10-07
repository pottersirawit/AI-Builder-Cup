import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../time_th.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Flood mode: the same "should I…" answer at home, at its most severe.
class FloodScreen extends StatefulWidget {
  const FloodScreen({super.key});

  @override
  State<FloodScreen> createState() => _FloodScreenState();
}

class _FloodScreenState extends State<FloodScreen> {
  HomeStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final s = state.track(await api.homeStatus());
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: floodTheme(Theme.of(context)),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = AppScope.stateOf(context);
    final s = _status;
    final canal = s?.canal;
    return SubScreen(
      title: 'โหมดน้ำท่วม',
      loading: _loading,
      onRefresh: _load,
      children: [
        Eyebrow('บ้านลาดพร้าว · ${hhmm(state.now())}'),
        if (s != null) ...[
          VerdictCard(
            tone: Tone.ofHomeLevel(s.level),
            eyebrow: 'คำถามเดิม ระดับใหม่ · ${homeLevelLabel(s.level)}',
            headline: s.headlineTh,
            summary: canal == null ? '' : canalSummary(canal),
          ),
          SourceLabel(s.sources.join(' · '), padding: const EdgeInsets.only(top: 10, left: 4)),
          if (canal != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('ระดับน้ำ${canal.nameTh}', style: txt(context))),
                      Pill('${canal.levelM.toStringAsFixed(1)} / ${canal.bankM.toStringAsFixed(1)} ม.',
                          tone: Tone.ofHomeLevel(s.level)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Gauge(fill: canal.fill),
                  const SizedBox(height: 6),
                  Text('ขึ้น ${canal.riseCm2h.round()} ซม. ใน 2 ชั่วโมง',
                      style: txt(context, size: 13, color: Palette.of(context).muted)),
                  const SourceLabel('ThaiWater (HII) · ระดับตลิ่งจากสำนักการระบายน้ำ'),
                ],
              ),
            ),
          if (s.actions.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ทำตอนนี้ เรียงตามลำดับ', style: txt(context, size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  for (final a in s.actions) _ActionRow(action: a),
                  const SourceLabel('Gemini เรียงตามเวลาที่เหลือและระยะทางจากบ้าน'),
                ],
              ),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('เพื่อนบ้านในซอย'),
                          const SizedBox(height: 4),
                          Text('11 คนได้รับเตือนเดียวกัน', style: txt(context, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Pill('แชร์'),
                  ],
                ),
                const SizedBox(height: 6),
                Text('คนที่ไม่มีสมาร์ทโฟนได้รับข้อความทาง LINE / SMS / โทรอ่านข้อความ',
                    style: txt(context, size: 13, color: Palette.of(context).muted)),
                const SourceLabel('Pub/Sub → LINE / SMS สำหรับคนที่เข้าไม่ถึงแอป'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.fill});
  final double fill;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 10,
          color: Palette.of(context).bg2,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .2, end: fill),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF4A8FF5), Color(0xFFFF8A80)]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final HomeAction action;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.srcDot, shape: BoxShape.circle),
            child: Text('${action.order}',
                style: txt(context, size: 12, weight: FontWeight.w700, color: p.bg)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(action.textTh, style: txt(context, height: 1.45))),
        ],
      ),
    );
  }
}
