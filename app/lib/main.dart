import 'package:flutter/material.dart';

import 'api.dart';
import 'app_state.dart';
import 'config.dart';
import 'design/design.dart';
import 'models.dart';
import 'screens/ask_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/verdict_screen.dart';

void main() {
  final state = AppState(demoClock: initialDemoClock());
  final api = FonTokMaiApi(baseUrl: resolveApiBaseUrl(), demoClock: () => state.demoClock);
  runApp(FonTokMaiApp(state: state, api: api, launch: DemoLaunch.fromEnvironment()));
}

class FonTokMaiApp extends StatefulWidget {
  const FonTokMaiApp({super.key, required this.state, required this.api, this.launch});

  final AppState state;
  final FonTokMaiApi api;

  /// Opens a demo state on start (screenshots, demo video).
  final DemoLaunch? launch;

  @override
  State<FonTokMaiApp> createState() => _FonTokMaiAppState();
}

class _FonTokMaiAppState extends State<FonTokMaiApp> {
  final _nav = GlobalKey<NavigatorState>();
  static final _light = buildTheme();
  static final _flood = buildTheme(flood: true);

  @override
  void initState() {
    super.initState();
    final l = widget.launch;
    if (l != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(l));
  }

  Future<void> _open(DemoLaunch l) async {
    final nav = _nav.currentState!;
    Route<void> route(Widget w) => MaterialPageRoute<void>(builder: (_) => w);
    switch (l.screen) {
      case 'verdict':
        final trips = (await widget.api.trips()).data;
        final trip = trips.where((t) => t.source == 'calendar').firstOrNull;
        if (trip == null) return;
        final hhmm = l.departHhmm;
        nav.push(route(VerdictScreen(
          request: DecideRequest(tripId: trip.id),
          trip: trip,
          departAt: hhmm == null ? null : DateTime.parse('${demoDate}T$hhmm:00+07:00'),
          mode: l.mode == null ? null : TravelMode.parse(l.mode),
        )));
      case 'ask':
        nav.push(route(const AskScreen(opening: 'ออกก่อน 16:45')));
      case 'settings':
        nav.push(route(const SettingsScreen()));
      case 'gallery':
        nav.push(route(const SettingsScreen()));
        nav.push(route(const GalleryScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.launch;
    return AppScope(
      state: widget.state,
      api: widget.api,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          navigatorKey: _nav,
          title: 'ฝนตกไหม',
          debugShowCheckedModeBanner: false,
          theme: widget.state.flood ? _flood : _light,
          themeAnimationDuration: Motion.sky,
          builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child!),
          home: Shell(
            initialTab: switch (l?.screen) {
              'report' || 'report_result' => ShellTab.report,
              'home_tab' => ShellTab.home,
              _ => ShellTab.board,
            },
            autoSubmitReport: l?.screen == 'report_result',
          ),
        ),
      ),
    );
  }
}
