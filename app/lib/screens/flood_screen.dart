import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../models.dart';
import 'parts.dart';

/// Home: the same "what should I do" answer, at its most severe in flood mode.
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
    final key = AppScope.stateOf(context).demoClock ?? 'live';
    if (key != _loadedFor) {
      _loadedFor = key;
      _load();
    }
  }

  Future<void> _load() async {
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    setState(() => _error = null);
    try {
      final s = state.track(await api.homeStatus());
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
    if (_error != null) {
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
      top = HomeStatusPass(status: s, now: state.now());
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
                        subtitle: danger ? 'คำถามเดิม ระดับใหม่' : 'บ้านลาดพร้าว ใกล้คลองลาดพร้าว',
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
            if (s != null)
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
