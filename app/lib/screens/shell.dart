import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../carry.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../trips_repository.dart';
import 'ask_sheet.dart';
import 'events_screen.dart';
import 'summary_screen.dart';

enum ShellTab { summary, events }

/// Root: Summary and Events under a floating glass pill, with Ask beside it.
/// Both tabs read one [TripsRepository].
class Shell extends StatefulWidget {
  const Shell({super.key, this.initialTab = ShellTab.summary});
  final ShellTab initialTab;

  static void goTo(BuildContext context, ShellTab tab) =>
      context.findAncestorStateOfType<_ShellState>()?._go(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late ShellTab _tab = widget.initialTab;
  TripsRepository? _repo;
  String? _loadedFor;
  String? _accountFor;

  TripsRepository get repo => _repo!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    _repo ??= TripsRepository(
      api: AppScope.apiOf(context),
      state: AppScope.readState(context),
      places: AppScope.readPlaces(context),
    );
    String sig(SavedPlace? p) => p == null ? '-' : '${p.id},${p.lat},${p.lng}';
    final key =
        '${state.locale.languageCode}|${state.demoClock ?? 'live'}|${sig(store.home)}|${store.calendar}|${store.gmail}|${store.demoProfile}';
    final account = '${store.calendarAccount}|${store.gmailAccount}';
    if (key != _loadedFor || account != _accountFor) {
      _loadedFor = key;
      _accountFor = account;
      _refresh(sync: AppScope.readPlaces(context).takeSyncDue());
    }
  }

  @override
  void dispose() {
    _repo?.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool sync = false}) async {
    unawaited(_refreshLocation());
    await repo.refresh(sync: sync);
    unawaited(repo.decideSoon());
  }

  /// Where questions start. A pinned spot wins over GPS.
  Future<void> _refreshLocation() async {
    final state = AppScope.readState(context);
    final pin = AppScope.readPlaces(context).manualLocation;
    if (pin != null) {
      state.currentLocation = LocateResult(
        LocateStatus.ok,
        lat: pin.lat,
        lng: pin.lng,
        nameTh: pin.nameTh,
        isManual: true,
        accuracyM: 10,
      );
      return;
    }
    final loc = await AppScope.locatorOf(context).locate(prompt: false);
    if (!mounted) return;
    if (loc.ok) {
      state.currentLocation = loc;
    } else if (state.currentLocation?.isManual ?? false) {
      state.currentLocation = null;
    }
  }

  void _go(ShellTab t) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _tab = t);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = AppScope.stateOf(context).now();
    final state = AppScope.stateOf(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => CrystalBackdrop(
        state: state.flood ? SkyState.flood : _sky(now),
        warm: state.flood ? 0 : _warmth(now),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: IndexedStack(
            index: _tab.index,
            children: [
              SummaryScreen(
                repo: repo,
                onRefresh: () => _refresh(sync: true),
                onSeeAll: () => _go(ShellTab.events),
              ),
              EventsScreen(repo: repo, onRefresh: () => _refresh(sync: true)),
            ],
          ),
          bottomNavigationBar: GlassNavBar(
            selected: _tab.index,
            onSelected: (i) => _go(ShellTab.values[i]),
            items: [
              GlassNavItem(icon: Symbols.today_rounded, label: l.navSummary),
              GlassNavItem(
                icon: Symbols.event_list_rounded,
                label: l.navEvents,
                badge: upcoming(repo.trips, now).any((t) => t.unresolved),
              ),
            ],
            action: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: geminiGradient.createShader,
              child: const Icon(
                Symbols.auto_awesome_rounded,
                fill: 1,
                size: 26,
              ),
            ),
            actionTooltip: l.navAsk,
            onAction: () => showAskSheet(context),
          ),
        ),
      ),
    );
  }

  /// Storm light while it rains or will within the hour.
  SkyState _sky(DateTime now) {
    final o = repo.outlook;
    if (o == null) return SkyState.clear;
    final soon = hoursAhead(
      o,
      now: now,
      until: now.add(const Duration(hours: 1)),
    );
    return soon.any(isRaining) ? SkyState.storm : SkyState.clear;
  }

  /// A hot sun glows in the corner.
  double _warmth(DateTime now) {
    final o = repo.outlook;
    final h = o == null ? null : hoursAhead(o, now: now).firstOrNull;
    if (h == null || isRaining(h)) return 0;
    return ((h.uvIndex - 3) / 6).clamp(0, 1).toDouble();
  }
}
