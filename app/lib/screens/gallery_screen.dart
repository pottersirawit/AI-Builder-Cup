import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/design.dart';
import '../models.dart';
import '../time_th.dart';

/// The design system, live: every token and component in each sky state.
/// It is also the system's documentation (see DESIGN.md).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

DateTime _bkk(String hhmm) => DateTime.parse('2026-09-29T$hhmm:00+07:00');

final _rain = [
  for (final (i, mm) in [0.0, 0, 0, .1, .3, 1.2, 2.1, 5.4, 12, 16.5, 11.2, 6, 4.8, 1.9, 1.1, .4, .2, 0, 0, 0].indexed)
    RainPoint(_bkk('16:00').add(Duration(minutes: 15 * i)), mm.toDouble()),
];

class _GalleryScreenState extends State<GalleryScreen> {
  SkyState _sky = SkyState.clear;
  DateTime _depart = _bkk('16:45');
  bool _shuffled = false;
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final flood = _sky == SkyState.flood;
    return Theme(
      data: buildTheme(flood: flood),
      child: Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: scheme.surface,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SkyField(
                  state: _sky,
                  height: double.infinity,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        FieldHeader(state: _sky, back: true, title: 'ระบบดีไซน์', subtitle: 'ฝนตกไหม · โทเคนและคอมโพเนนต์'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
                          child: SegmentedButton<SkyState>(
                            style: SegmentedButton.styleFrom(
                              backgroundColor: scheme.surfaceContainerLowest,
                              selectedBackgroundColor: scheme.secondaryContainer,
                            ),
                            segments: const [
                              ButtonSegment(value: SkyState.clear, label: Text('ฟ้าใส'), icon: Icon(Symbols.sunny_rounded)),
                              ButtonSegment(value: SkyState.storm, label: Text('พายุ'), icon: Icon(Symbols.thunderstorm_rounded)),
                              ButtonSegment(value: SkyState.flood, label: Text('น้ำท่วม'), icon: Icon(Symbols.flood_rounded)),
                            ],
                            selected: {_sky},
                            onSelectionChanged: (s) => setState(() => _sky = s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList.list(children: [
                _Block('พื้นท้องฟ้า', child: _SkySwatches()),
                _Block('พาสในแต่ละท้องฟ้า', child: _PassTriptych(depart: _depart)),
                _Block('สี', child: const _ColorTokens()),
                _Block('ตัวอักษร · Chakra Petch', child: const _TypeScale()),
                _Block('ระยะ · รัศมี · เงา', child: const _SpaceTokens()),
                _Block('การเคลื่อนไหว', child: _MotionTokens(
                  flipped: _flipped,
                  onFlip: () => setState(() => _flipped = !_flipped),
                )),
                _Block('RainBand · ลากได้', child: Pass(sections: [
                  PassSection(
                    child: RainBand(
                      points: _rain,
                      departAt: _depart,
                      earliest: _bkk('16:10'),
                      etaMin: 50,
                      now: _bkk('16:10'),
                      onChanged: (t) => setState(() => _depart = t),
                      onChangeEnd: (t) => setState(() => _depart = t),
                    ),
                  ),
                ])),
                _Block('DepartureBoard · BoardRow', child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DepartureBoard(rows: [
                      for (final r in _shuffled ? _rows.reversed : _rows) r,
                    ]),
                    TextButton.icon(
                      onPressed: () => setState(() => _shuffled = !_shuffled),
                      icon: const Icon(Symbols.swap_vert_rounded),
                      label: const Text('จัดอันดับใหม่'),
                    ),
                  ],
                )),
                _Block('ModeSegmented', child: _ModeDemo()),
                _Block('RiskChip · ConfidenceMeter · SourceLabel', child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
                      RiskChip(risk: Risk.low),
                      RiskChip(risk: Risk.medium),
                      RiskChip(risk: Risk.high),
                      RiskChip(risk: Risk.low, label: 'ออกได้', dense: true),
                      SampleBadge(),
                    ]),
                    const SizedBox(height: Space.x4),
                    ConfidenceMeter(value: .84, color: scheme.onSurface),
                    const SizedBox(height: Space.x4),
                    const SourceLabel('Google Weather API · กรมอุตุฯ NWP'),
                    const SizedBox(height: Space.x3),
                    const GeneratedBy('gemini'),
                    const SizedBox(height: Space.x2),
                    const GeneratedBy('fallback'),
                  ],
                )),
                _Block('AskBar', child: AskBar(onSubmit: (_) {})),
                _Block('NotificationBanner', child: NotificationBanner(
                  time: '16:10',
                  title: 'ออกก่อน 16:45 · กินข้าวเย็นกับที่บ้าน',
                  body: 'ฝนถึงพระราม 4 ประมาณ 17:30 ถ้าออกตอนนี้ถึงบ้านก่อนฝน',
                  onOpen: () {},
                  onDismiss: () {},
                )),
                _Block('สถานะ: กำลังโหลด', child: const PassSkeleton()),
                _Block('สถานะ: ผิดพลาด', child: ErrorState(
                  title: 'โหลดทริปไม่ได้',
                  message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
                  onRetry: () {},
                )),
                _Block('สถานะ: ว่าง', child: EmptyState(
                  icon: Symbols.event_available_rounded,
                  title: 'วันนี้ยังไม่มีทริป',
                  message: 'พิมพ์ถามได้เลย เช่น “ห้าโมงไปสยาม”',
                  action: OutlinedButton(onPressed: () {}, child: const Text('เชื่อม Calendar')),
                )),
                const SizedBox(height: Space.x12),
              ]),
            ],
          ),
        );
      }),
    );
  }
}

final _rows = [
  BoardRow(
    key: const ValueKey('g-transit'),
    time: '16:55',
    timeCaption: 'ถึง',
    icon: Symbols.train_rounded,
    title: 'BTS / MRT · 40 นาที',
    subtitle: 'ศาลาแดง → ลาดพร้าว ไม่ต้องพกร่ม',
    risk: Risk.low,
    status: 'ออกได้',
    selected: true,
    onTap: () {},
  ),
  BoardRow(
    key: const ValueKey('g-car'),
    time: '17:05',
    timeCaption: 'ถึง',
    icon: Symbols.directions_car_rounded,
    title: 'รถยนต์ · 50 นาที',
    subtitle: 'ถึงก่อนฝน ทันนัด 18:30',
    risk: Risk.low,
    status: 'ออกได้',
    onTap: () {},
  ),
  BoardRow(
    key: const ValueKey('g-moto'),
    time: '16:45',
    timeCaption: 'ถึง',
    icon: Symbols.two_wheeler_rounded,
    title: 'มอเตอร์ไซค์ · 30 นาที',
    subtitle: 'ทันพอดี ช้ากว่านี้จะโดนฝน',
    risk: Risk.medium,
    status: 'เผื่อเวลา',
    onTap: () {},
  ),
];

class _Block extends StatelessWidget {
  const _Block(this.title, {required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x8, Space.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.x3),
            child,
          ],
        ),
      );
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _SkySwatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (s, name) in [(SkyState.clear, 'ฟ้าใส'), (SkyState.storm, 'พายุ'), (SkyState.flood, 'น้ำท่วม')]) ...[
          if (s != SkyState.clear) const SizedBox(width: Space.x2),
          Expanded(
            child: Container(
              height: 112,
              padding: const EdgeInsets.all(Space.x3),
              decoration: BoxDecoration(
                gradient: c.sky(s).gradient,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.titleMedium!.copyWith(color: c.sky(s).onField)),
                  const Spacer(),
                  Text(_hex(c.sky(s).top), style: tabular(t.labelSmall!).copyWith(color: c.sky(s).onFieldMuted)),
                  Text(_hex(c.sky(s).bottom), style: tabular(t.labelSmall!).copyWith(color: c.sky(s).onFieldMuted)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PassTriptych extends StatelessWidget {
  const _PassTriptych({required this.depart});
  final DateTime depart;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final (s, head, risk, status) in [
            (SkyState.clear, 'ออกก่อน 16:45', Risk.low, 'ออกได้'),
            (SkyState.storm, 'อย่าเพิ่งออก', Risk.high, 'รอก่อน'),
            (SkyState.flood, 'น้ำจะถึงหน้าบ้านใน 40 นาที', Risk.high, 'อันตราย'),
          ])
            Theme(
              data: buildTheme(flood: s == SkyState.flood),
              child: Builder(builder: (context) {
                final c = FonColors.of(context);
                final t = Theme.of(context).textTheme;
                return Padding(
                  padding: const EdgeInsets.only(bottom: Space.x3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg + Space.x3),
                    child: SkyField(
                      state: s,
                      height: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.x3),
                        child: Pass(sections: [
                          PassSection(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(head,
                                    style: tabular(s == SkyState.flood ? t.headlineMedium! : t.displaySmall!)
                                        .copyWith(color: s == SkyState.flood ? c.warning : c.paperInk)),
                                const SizedBox(height: Space.x2),
                                RiskChip(risk: risk, label: status),
                              ],
                            ),
                          ),
                          PassSection(
                            child: PassSegments([
                              PassSegment('ออก', hhmm(depart)),
                              const PassSegment('ถึง', '17:35'),
                              const PassSegment('โหมด', 'รถยนต์'),
                              const PassSegment('มั่นใจ', '78%'),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      );
}

class _ColorTokens extends StatelessWidget {
  const _ColorTokens();

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final s = Theme.of(context).colorScheme;
    final groups = <String, List<(String, Color)>>{
      'พาส': [('paper', c.paper), ('paperInk', c.paperInk), ('paperMuted', c.paperMuted), ('perforation', c.perforation)],
      'ฝน (ไม่มี → หนัก)': [for (final (i, r) in c.rain.indexed) ('rain$i', r)],
      'ความเสี่ยง': [
        ('riskLow', c.riskLow),
        ('riskMedium', c.riskMedium),
        ('riskHigh', c.riskHigh),
        ('warning', c.warning),
      ],
      'Material roles': [
        ('primary', s.primary),
        ('onPrimary', s.onPrimary),
        ('secondaryContainer', s.secondaryContainer),
        ('surface', s.surface),
        ('surfaceContainerLow', s.surfaceContainerLow),
        ('surfaceContainerHighest', s.surfaceContainerHighest),
        ('onSurface', s.onSurface),
        ('onSurfaceVariant', s.onSurfaceVariant),
        ('outlineVariant', s.outlineVariant),
        ('error', s.error),
      ],
    };
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups.entries) ...[
          Text(g.key, style: t.titleSmall),
          const SizedBox(height: Space.x2),
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              for (final (name, color) in g.value)
                SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(Radii.sm),
                          border: Border.all(color: s.outlineVariant),
                        ),
                      ),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall),
                      Text(_hex(color), style: tabular(t.labelSmall!).copyWith(color: s.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.x4),
        ],
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final roles = {
      'displayMedium · คำตัดสิน': t.displayMedium!,
      'displaySmall': t.displaySmall!,
      'headlineSmall': t.headlineSmall!,
      'titleLarge': t.titleLarge!,
      'titleMedium': t.titleMedium!,
      'bodyLarge': t.bodyLarge!,
      'bodyMedium': t.bodyMedium!,
      'bodySmall': t.bodySmall!,
      'labelLarge': t.labelLarge!,
      'labelSmall': t.labelSmall!,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in roles.entries) ...[
          Text('${e.key} · ${e.value.fontSize!.round()}/${e.value.height} · w${e.value.fontWeight!.value}',
              style: tabular(t.labelSmall!).copyWith(color: s.onSurfaceVariant)),
          Text(e.value.fontSize! > 24 ? 'ออกก่อน 16:45' : 'ฝนถึงพระราม 4 ราว 17:30 น้ำขัง 25 ซม.',
              style: tabular(e.value)),
          const SizedBox(height: Space.x3),
        ],
        Text('ตัวเลขเท่ากัน (Petch Tabular) เทียบตัวเลขปกติ', style: t.labelSmall!.copyWith(color: s.onSurfaceVariant)),
        Text('11:11 · 18:08', style: tabular(t.headlineSmall!)),
        Text('11:11 · 18:08', style: t.headlineSmall),
      ],
    );
  }
}

class _SpaceTokens extends StatelessWidget {
  const _SpaceTokens();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in [Space.x1, Space.x2, Space.x3, Space.x4, Space.x6, Space.x8, Space.x12])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x1),
            child: Row(children: [
              SizedBox(width: 40, child: Text('${v.round()}', style: tabular(t.labelMedium!))),
              Container(width: v * 3, height: 10, color: s.primary),
            ]),
          ),
        const SizedBox(height: Space.x4),
        Wrap(
          spacing: Space.x3,
          runSpacing: Space.x3,
          children: [
            for (final (name, r) in [('xs', Radii.xs), ('sm', Radii.sm), ('md', Radii.md), ('lg/pass', Radii.lg)])
              Column(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: s.secondaryContainer,
                    borderRadius: BorderRadius.circular(r),
                  ),
                ),
                Text('$name ${r.round()}', style: tabular(t.labelSmall!)),
              ]),
            Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  boxShadow: c.passShadow,
                ),
              ),
              Text('pass shadow', style: t.labelSmall),
            ]),
          ],
        ),
      ],
    );
  }
}

class _MotionTokens extends StatelessWidget {
  const _MotionTokens({required this.flipped, required this.onFlip});
  final bool flipped;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final motion = Motion.of(context);
    final rows = [
      ('tap', Motion.tap, 'สถานะปุ่มและการเลือก'),
      ('flap', Motion.flap, 'คำตัดสินพลิกตัวอักษร'),
      ('rerank', Motion.rerank, 'กระดานเลื่อนอันดับ'),
      ('enter', Motion.enter, 'แจ้งเตือนเลื่อนลง'),
      ('sky', Motion.sky, 'สีท้องฟ้าเปลี่ยนสถานะ'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, d, use) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x1),
            child: Row(children: [
              SizedBox(width: 64, child: Text(name, style: t.labelLarge)),
              SizedBox(width: 72, child: Text('${d.inMilliseconds} ms', style: tabular(t.labelLarge!))),
              Expanded(child: Text(use, style: t.bodySmall)),
            ]),
          ),
        Text(motion.enabled ? 'เส้นโค้ง: standard (0.2, 0, 0, 1) · emphasized decelerate (0.05, 0.7, 0.1, 1)'
            : 'ลดการเคลื่อนไหวเปิดอยู่: ทุกระยะเวลาเป็น 0', style: t.bodySmall),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: motion.d(Motion.flap),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: Text(flipped ? 'อย่าเพิ่งออก' : 'ออก 16:45 ได้',
                    key: ValueKey(flipped), style: tabular(t.headlineMedium!)),
              ),
            ),
            OutlinedButton(onPressed: onFlip, child: const Text('พลิก')),
          ],
        ),
      ],
    );
  }
}

class _ModeDemo extends StatefulWidget {
  @override
  State<_ModeDemo> createState() => _ModeDemoState();
}

class _ModeDemoState extends State<_ModeDemo> {
  TravelMode _m = TravelMode.car;

  @override
  Widget build(BuildContext context) => ModeSegmented(
        selected: _m,
        onChanged: (m) => setState(() => _m = m),
        status: const {
          TravelMode.car: ModeStatus(risk: Risk.high, text: '95 น. · รอก่อน'),
          TravelMode.transit: ModeStatus(risk: Risk.medium, text: '50 น. · เผื่อเวลา'),
          TravelMode.moto: ModeStatus(risk: Risk.high, text: '60 น. · งดไป'),
        },
      );
}
