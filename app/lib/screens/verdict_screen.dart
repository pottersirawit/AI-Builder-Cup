import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../models.dart';
import '../trip_controller.dart';
import 'ask_screen.dart';
import 'parts.dart';
import 'place_picker.dart';

/// One trip in full: drag the departure, compare modes, see why.
class VerdictScreen extends StatefulWidget {
  const VerdictScreen({super.key, required this.request, this.trip, this.departAt, this.mode});

  /// A trip id, an origin/destination pair, or a Thai question.
  final DecideRequest request;
  final Trip? trip;
  final DateTime? departAt;
  final TravelMode? mode;

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  late final TripController _c = TripController(
    api: AppScope.apiOf(context),
    state: AppScope.readState(context),
    request: widget.request,
    departAt: widget.departAt,
    mode: widget.mode,
  )..addListener(_changed);

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  void _changed() => setState(() {});

  Future<void> _savePlace(Place dest) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await showPlaceConfirmSheet(
      context,
      kind: PlaceKind.other,
      candidate: PlaceCandidate(nameTh: dest.nameTh, lat: dest.lat, lng: dest.lng),
    );
    if (r?.saved != null) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึก “${r!.saved!.labelTh}” แล้ว')));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final d = _c.decision;
    final trip = widget.trip ?? d?.trip;
    final store = AppScope.placesOf(context);
    final dest = trip?.destination;
    final unsaved = dest != null &&
        !trip!.unresolved &&
        (dest.lat != 0 || dest.lng != 0) &&
        store.duplicateOf(dest.lat, dest.lng) == null;
    final sky = state.flood ? SkyState.flood : _c.sky(home: state.homeLevel);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);

    final needs = _c.needsPlace;
    final Widget pass = needs != null
        ? NeedsPlacePass(needs: needs, onResolved: _c.resolvePlace)
        : _c.error != null && d == null
        ? Pass(sections: [
            PassSection(
              child: ErrorState(
                title: 'ยังตัดสินไม่ได้',
                message: 'ติดต่อ Gemini และข้อมูลตัวอย่างไม่ได้ ลองอีกครั้งในอีกสักครู่',
                onRetry: _c.load,
              ),
            ),
          ])
        : TripPass(
            controller: _c,
            now: state.now(),
            trip: trip,
            question: widget.request.questionTh,
            actions: [
              if (unsaved && store.canAddOther)
                ActionChip(
                  avatar: const Icon(Symbols.bookmark_add_rounded, size: 18),
                  label: const Text('บันทึกที่นี่ไว้'),
                  onPressed: () => _savePlace(dest),
                ),
            ],
          );

    final board = _c.board;
    return Scaffold(
      body: CustomScrollView(
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
                      back: true,
                      title: trip == null
                          ? 'คำถาม'
                          : trip.source == 'routine' || trip.titleTh == 'กลับบ้าน'
                              ? trip.titleTh
                              : 'ไป${trip.destination.nameTh}',
                      subtitle: trip == null ? 'Gemini แกะคำถามเป็นทริป' : '${trip.origin.nameTh} → ${trip.destination.nameTh}',
                      actions: [
                        if (state.usingSample) const Padding(
                          padding: EdgeInsets.only(right: Space.x3),
                          child: SampleBadge(onField: true),
                        ),
                      ],
                    ),
                    if (_c.loading)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: c.sky(sky).onField,
                        backgroundColor: Colors.transparent,
                      )
                    else
                      const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
                      child: pass,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (d != null) ...[
            SliverToBoxAdapter(
              child: Section(
                title: 'เทียบวิธีเดินทาง',
                source: 'ระยะพ้นน้ำตามประเภทรถ · Google Routes API',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModeSegmented(
                      selected: _c.mode,
                      onChanged: _c.setMode,
                      status: {
                        for (final o in board)
                          o.mode: ModeStatus(risk: o.risk, text: '${o.etaMin} น. · ${boardStatus(o.verdict, o.risk)}'),
                      },
                    ),
                    if (_c.selected != null) ...[
                      const SizedBox(height: Space.x3),
                      Text(_c.selected!.noteTh, style: t.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Section(
                title: 'จุดน้ำท่วมบนเส้นทาง',
                source: 'จุดเสี่ยงน้ำท่วม กทม. · ThaiWater · รายงานผู้ใช้',
                child: d.floodSpots.isEmpty
                    ? EmptyState(
                        icon: Symbols.check_circle_rounded,
                        title: 'ไม่มีจุดน้ำขังบนเส้นทางนี้',
                        message: 'เส้นทางนี้ไม่ผ่านจุดเสี่ยงน้ำท่วมของ กทม.',
                      )
                    : Column(
                        children: [
                          for (final s in d.floodSpots) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Symbols.flood_rounded, color: c.riskInk(s.risk)),
                              title: Text(s.nameTh),
                              subtitle: Text(
                                s.expectedDepthCm > 0 ? 'คาดน้ำสูง ${s.expectedDepthCm.round()} ซม.' : 'ยังแห้ง',
                                style: tabular(t.bodySmall!).copyWith(color: scheme.onSurfaceVariant),
                              ),
                              trailing: RiskChip(risk: s.risk, dense: true),
                            ),
                            if (s != d.floodSpots.last) const Divider(),
                          ],
                        ],
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Section(
                title: 'Gemini คิดแบบนี้',
                trailing: const GeminiMark(size: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < d.reasoning.length; i++)
                      _TraceStep(step: d.reasoning[i], index: i + 1, last: i == d.reasoning.length - 1),
                    const SizedBox(height: Space.x4),
                    ConfidenceMeter(value: d.confidence, color: scheme.onSurface),
                    const SizedBox(height: Space.x4),
                    Text('แหล่งข้อมูล', style: t.titleSmall),
                    const SizedBox(height: Space.x2),
                    Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [
                        for (final s in d.sources)
                          Chip(
                            avatar: const Icon(Symbols.database_rounded, size: 16),
                            label: Text(s),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.x4),
                    GeneratedBy(d.generatedBy),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x8, Space.gutter, Space.x10),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => AskScreen(trip: trip, opening: _c.headline),
                  )),
                  icon: const Icon(Symbols.chat_rounded),
                  label: const Text('ถามต่อ'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tool call in the agent's trace: a numbered rail, tool id, summary.
class _TraceStep extends StatelessWidget {
  const _TraceStep({required this.step, required this.index, required this.last});
  final ReasoningStep step;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                  child: Text('$index',
                      style: tabular(t.labelMedium!).copyWith(color: scheme.onSecondaryContainer)),
                ),
                if (!last) Expanded(child: VerticalDivider(width: 2, thickness: 2, color: scheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tool names are code identifiers, so they stay monospace.
                  Text(step.tool,
                      style: t.labelMedium!.copyWith(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['monospace', 'Courier'],
                        color: scheme.primary,
                      )),
                  const SizedBox(height: 2),
                  Text(step.summaryTh, style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
