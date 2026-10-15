import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
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
    final key =
        '${AppScope.stateOf(context).locale.languageCode}|${AppScope.stateOf(context).demoClock ?? 'live'}|${h?.id},${h?.lat},${h?.lng}|${store.demoProfile}';
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
      final s = state.track(
        await api.homeStatus(home: store.demoProfile ? null : home),
      );
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
    final l = context.l10n;
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
      top = Pass(
        sections: [
          PassSection(
            child: EmptyState(
              icon: Symbols.home_pin_rounded,
              title: l.floodSetHomeTitle,
              message: l.floodSetHomeMsg,
              action: Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  FilledButton.icon(
                    onPressed: () => pickPlace(
                      context,
                      kind: PlaceKind.home,
                      locateNow: true,
                    ),
                    icon: const Icon(Symbols.my_location_rounded),
                    label: Text(l.floodUseLocation),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => pickPlace(context, kind: PlaceKind.home),
                    icon: const Icon(Symbols.search_rounded),
                    label: Text(l.floodSearch),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (_error != null) {
      top = Pass(
        sections: [
          PassSection(
            child: ErrorState(
              title: l.floodReadError,
              message: l.floodReadErrorMsg,
              retryLabel: l.floodRetry,
              onRetry: _load,
            ),
          ),
        ],
      );
    } else if (s == null) {
      top = const PassSkeleton();
    } else {
      top = HomeStatusPass(
        status: s,
        now: state.now(),
        placeName: home.addressTh.isEmpty
            ? home.nameTh
            : '${home.nameTh} · ${home.addressTh.split(' · ').first}',
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
                        title: danger ? l.floodModeTitle : l.floodHome,
                        subtitle: danger
                            ? l.floodSameQuestion
                            : home == null
                            ? l.floodNoHome
                            : home.addressTh.isEmpty
                            ? home.nameTh
                            : '${home.nameTh} · ${home.addressTh.split(' · ').last}',
                        actions: [
                          if (state.usingSample)
                            const SampleBadge(onField: true),
                          DemoClockChip(state: state, sky: sky),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          Space.x2,
                          Space.gutter,
                          0,
                        ),
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
                  title: danger ? l.floodDoNow : l.floodPrepare,
                  child: Column(
                    children: [
                      for (final a in s.actions)
                        _ActionRow(
                          action: a,
                          done: _done.contains(a.order),
                          large: danger,
                          onToggle: () => setState(
                            () => _done.contains(a.order)
                                ? _done.remove(a.order)
                                : _done.add(a.order),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (home == null) const SliverToBoxAdapter(child: _NearbyReports()),
            if (s != null && s.canal == null && s.inServiceArea)
              SliverToBoxAdapter(
                child: Section(
                  title: l.floodSpotsTitle,
                  child: s.floodSpots.isEmpty
                      ? EmptyState(
                          icon: Symbols.check_circle_rounded,
                          title: l.floodNoSpots,
                          message: l.floodNoSpotsMsg,
                        )
                      : Column(
                          children: [
                            for (final f in s.floodSpots)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Symbols.flood_rounded,
                                  color: c.riskInk(f.risk),
                                ),
                                title: Text(f.nameTh),
                                subtitle: f.distanceM == null
                                    ? null
                                    : Text(
                                        l.floodFromHome(
                                          (f.distanceM! / 10).round() * 10,
                                        ),
                                        style: tabular(
                                          Theme.of(
                                            context,
                                          ).textTheme.bodySmall!,
                                        ),
                                      ),
                                trailing: RiskChip(risk: f.risk, dense: true),
                              ),
                          ],
                        ),
                ),
              ),
            if (s != null && store.demoProfile)
              SliverToBoxAdapter(
                child: Section(
                  title: l.floodNeighborsTitle,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Symbols.groups_rounded,
                        color: danger ? c.warning : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              danger
                                  ? l.floodNeighborsDanger
                                  : l.floodNeighborsWatch,
                              style: tabular(t.titleMedium!),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              l.floodNeighborsNote,
                              style: t.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
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
  const _ActionRow({
    required this.action,
    required this.done,
    required this.large,
    required this.onToggle,
  });
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
      label: context.l10n.floodStepSemantics(action.order, action.textTh),
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: large ? Space.targetLarge : Space.target,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Space.x3,
              horizontal: Space.x1,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: tile,
                  height: tile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? scheme.surfaceContainerHighest
                        : scheme.primary,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: done
                      ? Icon(
                          Symbols.check_rounded,
                          color: scheme.onSurfaceVariant,
                        )
                      : Text(
                          '${action.order}',
                          style: tabular(
                            large ? t.titleLarge! : t.titleMedium!,
                          ).copyWith(color: scheme.onPrimary),
                        ),
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
  String? _where; // null: the phone's own position
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
      _where = here.source == 'gps' ? null : here.nameTh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final reports = _reports;
    return Section(
      title: l.floodNearbyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reports == null && !_loading)
            OutlinedButton.icon(
              onPressed: _look,
              icon: const Icon(Symbols.my_location_rounded),
              label: Text(l.floodNearbyButton),
            ),
          if (_loading) const SkeletonList(rows: 2),
          if (reports != null) ...[
            Text(l.floodAround(_where ?? l.floodHereNow), style: t.titleSmall),
            if (reports.isEmpty)
              EmptyState(
                icon: Symbols.check_circle_rounded,
                title: l.floodNoReports,
                message: l.floodNoReportsMsg,
              )
            else
              for (final r in reports)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.flood_rounded),
                  title: Text(
                    l.floodWaterDepth(r.depthCmMin, r.depthCmMax),
                    style: tabular(t.titleMedium!),
                  ),
                  subtitle: Text(
                    r.descriptionTh,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: r.passable[TravelMode.car] == null
                      ? null
                      : RiskChip(
                          risk: passableRisk(r.passable[TravelMode.car]!),
                          label: l.floodCarPassable(
                            passableText(l, r.passable[TravelMode.car]!),
                          ),
                          dense: true,
                        ),
                ),
            TextButton.icon(
              onPressed: _look,
              icon: const Icon(Symbols.refresh_rounded),
              label: Text(l.floodOtherSpot),
            ),
          ],
        ],
      ),
    );
  }
}
