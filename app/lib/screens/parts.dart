import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../config.dart';
import '../design/design.dart';
import '../models.dart';
import '../places.dart';
import '../time_th.dart';
import '../trip_controller.dart';
import 'place_picker.dart';

/// The top trip printed as a pass: verdict, segments, rain band.
class TripPass extends StatelessWidget {
  const TripPass({
    super.key,
    required this.controller,
    required this.now,
    this.trip,
    this.question,
    this.compact = false,
    this.actions = const [],
    this.onTap,
  });

  final TripController controller;
  final DateTime now;
  final Trip? trip;
  final String? question;

  /// Home's version: summary clipped to three lines.
  final bool compact;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = controller.decision;
    if (d == null) return const PassSkeleton();
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final sel = controller.selected;
    final mode = controller.mode;
    final trip = this.trip;
    final verdict = controller.verdict ?? d.verdict;
    final risk = sel?.risk ?? riskOfVerdict(verdict);
    final motion = Motion.of(context);

    final header = Row(
      children: [
        Icon(trip == null ? Symbols.chat_rounded : sourceIcon(trip.source), size: 18, color: c.paperMuted),
        const SizedBox(width: Space.x2),
        Expanded(
          child: Text(
            trip == null ? 'คำถาม: “${question ?? ''}”' : trip.titleTh,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.titleSmall!.copyWith(color: c.paperInk),
          ),
        ),
        if (trip?.arriveBy != null)
          Text('ถึงก่อน ${hhmm(trip!.arriveBy!)}', style: tabular(t.labelLarge!).copyWith(color: c.paperMuted)),
      ],
    );

    final headline = AnimatedSwitcher(
      duration: motion.d(Motion.flap),
      switchInCurve: Motion.emphasizedDecelerate,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: Text(
        keepLastWordTogether(controller.headline),
        key: ValueKey(controller.headline),
        style: tabular(t.displayMedium!).copyWith(color: c.paperInk),
      ),
    );

    final summary = controller.previewing
        ? Row(
            children: [
              const GeminiMark(size: 16),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  controller.loading
                      ? 'Gemini กำลังตรวจเวลานี้…'
                      : 'ประเมินจากฝนบนเส้นทาง ปล่อยนิ้วเพื่อให้ Gemini ยืนยัน',
                  style: t.bodyMedium!.copyWith(color: c.paperMuted),
                ),
              ),
            ],
          )
        : Text(
            d.summaryTh,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: t.bodyMedium!.copyWith(color: c.paperInk),
          );

    final arrive = sel?.arriveAt;
    final departIsNow = controller.departAt.difference(now).inMinutes.abs() < 5;

    return Pass(
      onTap: onTap,
      semanticLabel: '${controller.headline} ${trip?.titleTh ?? ''}',
      sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (trip != null)
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text('${trip.origin.nameTh} → ${trip.destination.nameTh}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(color: c.paperMuted)),
                ),
              const SizedBox(height: Space.x3),
              MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: headline),
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  RiskChip(risk: risk, label: boardStatus(verdict, risk)),
                  const SizedBox(width: Space.x3),
                  if (sel != null)
                    Flexible(
                      child: Text('ใช้เวลา ${sel.etaMin} นาที',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tabular(t.labelLarge!).copyWith(color: c.paperMuted)),
                    ),
                ],
              ),
              const SizedBox(height: Space.x3),
              summary,
            ],
          ),
        ),
        PassSection(
          child: PassSegments([
            PassSegment('ออก', departIsNow && !controller.previewing ? 'ตอนนี้' : hhmm(controller.departAt)),
            PassSegment('ถึง', arrive == null ? '–' : hhmm(arrive)),
            PassSegment('โหมด', mode.shortTh),
            PassSegment('มั่นใจ', percent(d.confidence)),
          ]),
        ),
        PassSection(
          padding: const EdgeInsets.fromLTRB(Space.x5, Space.x3, Space.x5, Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.swipe_rounded, size: 16, color: c.paperMuted),
                  const SizedBox(width: Space.x1),
                  Expanded(
                    child: Text('ลากหมุดเพื่อลองเวลาออก',
                        style: t.labelMedium!.copyWith(color: c.paperMuted)),
                  ),
                  if (!departIsNow)
                    TextButton(
                      onPressed: controller.resetDeparture,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(Space.target, 36),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                      ),
                      child: const Text('ออกตอนนี้'),
                    ),
                ],
              ),
              const SizedBox(height: Space.x2),
              RainBand(
                key: const ValueKey('rain-band'),
                points: d.rainTimeline,
                departAt: controller.departAt,
                earliest: controller.earliest,
                etaMin: controller.etaMin,
                now: now,
                onChanged: controller.drag,
                onChangeEnd: controller.commit,
              ),
              const SizedBox(height: Space.x3),
              SourceLabel('ฝนบนเส้นทาง: Google Weather API · ตัดสินจาก ${d.sources.join(' + ')}'),
              const SizedBox(height: Space.x2),
              GeneratedBy(d.generatedBy),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.x4),
                Wrap(spacing: Space.x2, runSpacing: Space.x2, children: actions),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Flood at home, printed as a pass.
class HomeStatusPass extends StatelessWidget {
  const HomeStatusPass({
    super.key,
    required this.status,
    required this.now,
    required this.placeName,
    this.actions = const [],
  });
  final HomeStatus status;
  final DateTime now;

  /// The saved home, e.g. "บ้านลาดพร้าว · ซอยลาดพร้าว 32".
  final String placeName;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final canal = status.canal;
    final risk = riskOfHomeLevel(status.level);
    final danger = status.level == HomeLevel.danger;
    return Pass(
      semanticLabel: status.headlineTh,
      sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.home_rounded, size: 18, color: c.paperMuted),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text(placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall!.copyWith(color: c.paperInk)),
                  ),
                  Text(hhmm(now), style: tabular(t.labelLarge!).copyWith(color: c.paperMuted)),
                ],
              ),
              const SizedBox(height: Space.x3),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: Text(
                  keepLastWordTogether(status.headlineTh),
                  style: tabular(danger ? t.displaySmall! : t.headlineLarge!)
                      .copyWith(color: danger ? c.warning : c.paperInk),
                ),
              ),
              const SizedBox(height: Space.x2),
              Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
                RiskChip(risk: risk, label: homeLevelLabel(status.level)),
                if (!status.inServiceArea) const RiskChip(risk: Risk.medium, label: 'นอกพื้นที่ที่รองรับ'),
              ]),
            ],
          ),
        ),
        if (canal == null && status.rainTodayMm != null)
          PassSection(
            child: PassSegments([
              PassSegment('ฝนวันนี้', '${status.rainTodayMm!.round()} มม.'),
              if (status.inServiceArea) ...[
                PassSegment('จุดเสี่ยง 2 กม.', '${status.floodSpots.length}'),
                PassSegment('รายงาน 500 ม.', '${status.reportsNearby ?? 0}'),
              ],
            ]),
          ),
        if (canal != null)
          PassSection(
            child: PassSegments([
              PassSegment('ระดับคลอง',
                  '${canal.levelM.toStringAsFixed(1)}/${canal.bankM.toStringAsFixed(1)} ม.'),
              PassSegment('ขึ้นใน 2 ชม.', '${canal.riseCm2h.round()} ซม.'),
              PassSegment('ถึงตลิ่ง', canal.fill >= .99 ? 'ถึงแล้ว' : 'อีก ${((canal.bankM - canal.levelM) * 100).round()} ซม.',
                  color: canal.fill >= .99 ? c.warning : null),
            ]),
          ),
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceLabel(status.sources.join(' · ')),
              if (canal == null && status.inServiceArea) ...[
                const SizedBox(height: Space.x1),
                SourceLabel('ไม่มีสถานีวัดระดับคลองใกล้บ้าน (ThaiWater ในรัศมี 3 กม.)',
                    icon: Symbols.water_damage_rounded),
              ],
              if (!status.inServiceArea) ...[
                const SizedBox(height: Space.x1),
                const SourceLabel('บ้านอยู่นอกกรุงเทพฯ ข้อมูลระดับคลองและจุดน้ำท่วมยังไม่ครอบคลุม แอปเตือนได้เฉพาะฝน',
                    icon: Symbols.travel_explore_rounded),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.x4),
                Wrap(spacing: Space.x2, runSpacing: Space.x2, children: actions),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Joins the last two words so a wrapped headline never orphans one word
/// ("…ใน 40 นาที" breaks before "40", not before "นาที").
String keepLastWordTogether(String s) {
  final i = s.lastIndexOf(' ');
  // With a single space the pair is the whole line; leave it breakable.
  if (i <= 0 || s.indexOf(' ') == i) return s;
  return '${s.substring(0, i)}\u00A0${s.substring(i + 1)}';
}

/// A titled block on the page surface (no card): more space above than below.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing, this.source});
  final String title;
  final Widget child;
  final Widget? trailing;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x8, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.titleLarge)),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.x3),
          child,
          if (source != null) ...[
            const SizedBox(height: Space.x3),
            SourceLabel(source!),
          ],
        ],
      ),
    );
  }
}

/// Demo time as a chip on the field; tapping opens the demo-clock sheet.
class DemoClockChip extends StatelessWidget {
  const DemoClockChip({super.key, required this.state, required this.sky});
  final AppState state;
  final SkyState sky;

  @override
  Widget build(BuildContext context) {
    final colors = FonColors.of(context).sky(sky);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'เวลาสาธิต ${hhmm(state.now())} แตะเพื่อเปลี่ยน',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showDemoClockPicker(context),
        borderRadius: BorderRadius.circular(Radii.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.target),
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(
                color: colors.onField.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.schedule_rounded, size: 16, color: colors.onField),
                  const SizedBox(width: 4),
                  Text(state.demoClock == null ? 'เวลาจริง' : hhmm(state.now()),
                      style: tabular(t.labelLarge!).copyWith(color: colors.onField)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDemoClockPicker(BuildContext context) {
  final state = AppScope.readState(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เวลาสาธิต', style: t.titleLarge),
                  Text('เล่นซ้ำพายุ อังคาร 29 ก.ย. 2026 · ส่งเป็น X-Demo-Clock',
                      style: t.bodySmall!.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            for (final p in [...demoPresets, null])
              ListTile(
                leading: Icon(p == null ? Symbols.public_rounded : Symbols.schedule_rounded),
                title: Text(p ?? 'เวลาจริง (ไม่ส่ง header)', style: tabular(t.titleMedium!)),
                subtitle: Text(switch (p) {
                  '16:10' => 'ก่อนเลิกงาน ฝนยังไม่มา',
                  '18:52' => 'พายุบนรัชดา น้ำรอระบาย',
                  '21:40' => 'โหมดน้ำท่วมที่บ้าน',
                  _ => 'ใช้นาฬิกาเครื่อง',
                }),
                trailing: (p == null ? null : demoClockIso(p)) == state.demoClock
                    ? const Icon(Symbols.check_rounded)
                    : null,
                onTap: () {
                  state.demoClock = p == null ? null : demoClockIso(p);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Space.x2),
          ],
        ),
      );
    },
  );
}

/// The answer card when the question's place is unknown: save home or work
/// inline, or choose among the server's candidates; then the caller re-runs
/// the same question.
class NeedsPlacePass extends StatelessWidget {
  const NeedsPlacePass({super.key, required this.needs, required this.onResolved});
  final NeedsPlace needs;

  /// The place to ask about, and the user's places after any save.
  final void Function(Place destination, List<SavedPlace> places) onResolved;

  Future<void> _pick(BuildContext context, PlaceKind kind, {bool locate = false, String? query}) async {
    final store = AppScope.readPlaces(context);
    final saved = await pickPlace(context, kind: kind, locateNow: locate, initialQuery: query);
    if (saved != null) onResolved(saved.asPlace, store.places);
  }

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final kind = needs.kind;
    final store = AppScope.readPlaces(context);

    if (kind != null && kind != PlaceKind.other) {
      final label = kindLabelTh(kind);
      return Pass(semanticLabel: 'ยังไม่รู้ว่า$labelอยู่ไหน', sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(kind == PlaceKind.home ? Symbols.home_rounded : Symbols.work_rounded, size: 18, color: c.paperMuted),
                const SizedBox(width: Space.x2),
                Text('ต้องรู้ก่อนตอบ', style: t.titleSmall!.copyWith(color: c.paperMuted)),
              ]),
              const SizedBox(height: Space.x3),
              Text('ยังไม่รู้ว่า$labelอยู่ไหน', style: t.headlineMedium!.copyWith(color: c.paperInk)),
              const SizedBox(height: Space.x2),
              Text('บันทึกไว้ครั้งเดียว แล้วแอปจะตอบคำถามนี้ต่อทันที',
                  style: t.bodyMedium!.copyWith(color: c.paperInk)),
              const SizedBox(height: Space.x4),
              Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
                FilledButton.icon(
                  onPressed: () => _pick(context, kind, locate: true),
                  icon: const Icon(Symbols.my_location_rounded),
                  label: const Text('ใช้ตำแหน่งตอนนี้'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(context, kind),
                  icon: const Icon(Symbols.search_rounded),
                  label: const Text('ค้นหา'),
                ),
              ]),
            ],
          ),
        ),
      ]);
    }

    return Pass(semanticLabel: 'หมายถึงที่ไหน', sections: [
      PassSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('หมายถึงที่ไหน', style: t.headlineMedium!.copyWith(color: c.paperInk)),
            const SizedBox(height: Space.x1),
            Text(
              needs.candidates.isEmpty
                  ? 'หา “${needs.queryTh}” ไม่เจอ ลองค้นด้วยชื่ออื่น'
                  : 'เจอหลายที่ที่ชื่อคล้าย “${needs.queryTh}”',
              style: t.bodyMedium!.copyWith(color: c.paperMuted),
            ),
          ],
        ),
      ),
      if (needs.candidates.isNotEmpty)
        PassSection(
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Column(
            children: [
              for (final p in needs.candidates)
                ListTile(
                  leading: Icon(Symbols.location_on_rounded, color: c.paperMuted),
                  title: Text(p.nameTh, style: t.titleSmall!.copyWith(color: c.paperInk)),
                  subtitle: Text(p.addressTh, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(color: c.paperMuted)),
                  onTap: () => onResolved(Place(nameTh: p.nameTh, lat: p.lat, lng: p.lng), store.places),
                ),
            ],
          ),
        ),
      PassSection(
        child: OutlinedButton.icon(
          onPressed: () => _pick(context, PlaceKind.other, query: needs.queryTh),
          icon: const Icon(Symbols.search_rounded),
          label: Text(needs.candidates.isEmpty ? 'ค้นหา “${needs.queryTh}”' : 'ไม่ใช่ทั้งหมด · ค้นหาเอง'),
        ),
      ),
    ]);
  }
}
