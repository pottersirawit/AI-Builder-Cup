import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../models.dart';
import 'parts.dart';
import 'place_picker.dart';

/// Home: the same "what should I do" answer, at its most severe in flood
/// mode. Without a saved home it asks for one, and still shows reports near
/// the phone.
class FloodScreen extends StatefulWidget {
  const FloodScreen({super.key});

  @override
  State<FloodScreen> createState() => _FloodScreenState();
}

class _FloodScreenState extends State<FloodScreen> {
  HomeStatus? _status;
  Object? _error;
  String? _loadedFor;
  final _done = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.placesOf(context);
    final h = store.home;
    final key = '${AppScope.stateOf(context).demoClock ?? 'live'}|${h?.id},${h?.lat},${h?.lng}|${store.demoProfile}';
    if (key != _loadedFor) {
      _loadedFor = key;
      _load();
    }
  }

  Future<void> _load() async {
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final store = AppScope.readPlaces(context);
    final home = store.home;
    setState(() {
      _error = null;
      if (home == null) _status = null;
    });
    if (home == null) {
      state.homeLevel = HomeLevel.normal;
      return;
    }
    try {
      final s = state.track(await api.homeStatus(home: store.demoProfile ? null : home));
      if (!mounted) return;
      state.homeLevel = s.level;
      setState(() {
        _status = s;
        _done.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final home = store.home;
    final s = _status;
    final sky = switch (s?.level) {
      HomeLevel.danger => SkyState.flood,
      HomeLevel.watch => SkyState.storm,
      _ => SkyState.clear,
    };
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final danger = s?.level == HomeLevel.danger;

    final Widget top;
    if (home == null) {
      top = Pass(sections: [
        PassSection(
          child: EmptyState(
            icon: Symbols.home_pin_rounded,
            title: 'ตั้งบ้านเพื่อดูความเสี่ยงน้ำท่วมหน้า\u2060บ้าน',
            message: 'แอปจะดูระดับคลองใกล้บ้าน จุดน้ำท่วมของ กทม. และรายงานจากเพื่อนบ้าน แล้วเตือนแม้ไม่ได้เปิดแอป',
            action: Wrap(spacing: Space.x2, runSpacing: Space.x2, children: [
              FilledButton.icon(
                onPressed: () => pickPlace(context, kind: PlaceKind.home, locateNow: true),
                icon: const Icon(Symbols.my_location_rounded),
                label: const Text('ใช้ตำแหน่งตอนนี้'),
              ),
              OutlinedButton.icon(
                onPressed: () => pickPlace(context, kind: PlaceKind.home),
                icon: const Icon(Symbols.search_rounded),
                label: const Text('ค้นหา'),
              ),
            ]),
          ),
        ),
      ]);
    } else if (_error != null) {
      top = Pass(sections: [
        PassSection(
          child: ErrorState(
            title: 'อ่านระดับน้ำไม่ได้',
            message: 'เชื่อมต่อ ThaiWater ผ่านเซิร์ฟเวอร์ไม่ได้ ถ้าน้ำขึ้นเร็วให้ยกของขึ้นที่สูงไว้ก่อน',
            onRetry: _load,
          ),
        ),
      ]);
    } else if (s == null) {
      top = const PassSkeleton();
    } else {
      top = HomeStatusPass(
        status: s,
        now: state.now(),
        placeName: home.addressTh.isEmpty ? home.nameTh : '${home.nameTh} · ${home.addressTh.split(' · ').first}',
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
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
                        title: danger ? 'โหมดน้ำท่วม' : 'บ้าน',
                        subtitle: danger
                            ? 'คำถามเดิม ระดับใหม่'
                            : home == null
                                ? 'ยังไม่ได้ตั้งบ้าน'
                                : home.addressTh.isEmpty
                                    ? home.nameTh
                                    : '${home.nameTh} · ${home.addressTh.split(' · ').last}',
                        actions: [
                          if (state.usingSample) const SampleBadge(onField: true),
                          DemoClockChip(state: state, sky: sky),
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
            if (s != null && s.actions.isNotEmpty)
              SliverToBoxAdapter(
                child: Section(
                  title: danger ? 'ทำตอนนี้ เรียงตามลำดับ' : 'เตรียมไว้ก่อน',
                  source: 'Gemini เรียงตามเวลาที่เหลือและระยะทางจากบ้าน',
                  child: Column(
                    children: [
                      for (final a in s.actions)
                        _ActionRow(
                          action: a,
                          done: _done.contains(a.order),
                          large: danger,
                          onToggle: () => setState(() =>
                              _done.contains(a.order) ? _done.remove(a.order) : _done.add(a.order)),
                        ),
                    ],
                  ),
                ),
              ),
            if (home == null)
              const SliverToBoxAdapter(child: _NearbyReports()),
            if (s != null && s.canal == null && s.inServiceArea)
              SliverToBoxAdapter(
                child: Section(
                  title: 'จุดเสี่ยงน้ำท่วม กทม. ใกล้บ้าน',
                  source: 'จุดเสี่ยงน้ำท่วม กทม. ในรัศมี 2 กม.',
                  child: s.floodSpots.isEmpty
                      ? const EmptyState(
                          icon: Symbols.check_circle_rounded,
                          title: 'ไม่มีจุดเสี่ยงใน 2 กม.',
                          message: 'บ้านไม่อยู่ใกล้จุดน้ำท่วมซ้ำซากที่ กทม. ประกาศไว้',
                        )
                      : Column(children: [
                          for (final f in s.floodSpots)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Symbols.flood_rounded, color: c.riskInk(f.risk)),
                              title: Text(f.nameTh),
                              subtitle: f.distanceM == null
                                  ? null
                                  : Text('ห่างบ้าน ${(f.distanceM! / 10).round() * 10} ม.',
                                      style: tabular(Theme.of(context).textTheme.bodySmall!)),
                              trailing: RiskChip(risk: f.risk, dense: true),
                            ),
                        ]),
                ),
              ),
            if (s != null && store.demoProfile)
              SliverToBoxAdapter(
                child: Section(
                  title: 'เพื่อนบ้านในซอย',
                  source: 'Pub/Sub → LINE / SMS / โทรอ่านข้อความ · จำนวนคนเป็นตัวเลขจำลองสำหรับเดโม',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.groups_rounded, color: danger ? c.warning : scheme.onSurfaceVariant),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(danger ? '11 คนได้รับเตือนเดียวกัน' : '3 คนรายงานน้ำขังใน 20 นาที',
                                style: tabular(t.titleMedium!)),
                            const SizedBox(height: Space.x1),
                            Text('คนที่ไม่มีสมาร์ทโฟนได้รับข้อความทาง LINE / SMS หรือโทรอ่านให้ฟัง',
                                style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x10)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.done, required this.large, required this.onToggle});
  final HomeAction action;
  final bool done;
  final bool large;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final tile = large ? 44.0 : 36.0;
    return Semantics(
      checked: done,
      button: true,
      label: 'ขั้นที่ ${action.order} ${action.textTh}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: large ? Space.targetLarge : Space.target),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x3, horizontal: Space.x1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: tile,
                  height: tile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? scheme.surfaceContainerHighest : scheme.primary,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: done
                      ? Icon(Symbols.check_rounded, color: scheme.onSurfaceVariant)
                      : Text('${action.order}',
                          style: tabular(large ? t.titleLarge! : t.titleMedium!)
                              .copyWith(color: scheme.onPrimary)),
                ),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Text(
                    action.textTh,
                    style: (large ? t.bodyLarge : t.bodyMedium)!.copyWith(
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
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

/// Community reports around the phone, for someone without a saved home.
class _NearbyReports extends StatefulWidget {
  const _NearbyReports();

  @override
  State<_NearbyReports> createState() => _NearbyReportsState();
}

class _NearbyReportsState extends State<_NearbyReports> {
  List<FloodReport>? _reports;
  String? _where;
  bool _loading = false;

  Future<void> _look() async {
    final api = AppScope.apiOf(context);
    final here = await locateOrSearch(context);
    if (here == null || !mounted) return;
    setState(() => _loading = true);
    final r = await api.reportsNear(lat: here.lat, lng: here.lng, radiusM: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reports = r.data;
      _where = here.source == 'gps' ? 'ตำแหน่งตอนนี้' : here.nameTh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reports = _reports;
    return Section(
      title: 'รายงานน้ำท่วมใกล้ฉัน',
      source: 'รายงานจากผู้ใช้ใน 24 ชม. · ประเมินระดับน้ำจากรูปโดย Gemini · รัศมี 500 ม.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reports == null && !_loading)
            OutlinedButton.icon(
              onPressed: _look,
              icon: const Icon(Symbols.my_location_rounded),
              label: const Text('ดูรายงานน้ำท่วมใกล้ฉัน'),
            ),
          if (_loading) const SkeletonList(rows: 2),
          if (reports != null) ...[
            Text('รอบ $_where', style: t.titleSmall),
            if (reports.isEmpty)
              const EmptyState(
                icon: Symbols.check_circle_rounded,
                title: 'ไม่มีรายงานใน 500 ม.',
                message: 'ยังไม่มีใครรายงานน้ำขังแถวนี้ใน 24 ชั่วโมง',
              )
            else
              for (final r in reports)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.flood_rounded),
                  title: Text('น้ำ ${r.depthCmMin}–${r.depthCmMax} ซม.', style: tabular(t.titleMedium!)),
                  subtitle: Text(r.descriptionTh, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: r.passable[TravelMode.car] == null
                      ? null
                      : RiskChip(
                          risk: passableRisk(r.passable[TravelMode.car]!),
                          label: 'รถยนต์ ${passableLabel(r.passable[TravelMode.car]!)}',
                          dense: true,
                        ),
                ),
            TextButton.icon(
              onPressed: _look,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('ดูจุดอื่น'),
            ),
          ],
        ],
      ),
    );
  }
}
