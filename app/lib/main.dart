import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'app_state.dart';
import 'config.dart';
import 'design/design.dart';
import 'l10n/l10n.dart';
import 'location.dart';
import 'models.dart';
import 'places.dart';
import 'screens/ask_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/place_picker.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/verdict_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final clock = initialDemoClock();
  final launch = DemoLaunch.fromEnvironment();
  final state = AppState(demoClock: clock);
  await state.restoreLocale();
  final places = await PlacesStore.open(demoByDefault: clock != null);
  if (launch != null) {
    if (launch.screen == 'onboarding') {
      places.resetToFirstRun();
    } else if (firstRunScreens.contains(launch.screen)) {
      places
        ..resetToFirstRun()
        ..completeOnboarding();
    } else {
      places.useDemoProfile();
    }
    // Settings screenshots show the notifications-off banner (stubbed check).
    state.notificationsDenied = launch.screen == 'settings_places';
  }
  final api = FonTokMaiApi(
    baseUrl: resolveApiBaseUrl(),
    demoClock: () => state.demoClock,
    language: () => state.locale.languageCode,
  );
  runApp(
    FonTokMaiApp(
      state: state,
      places: places,
      api: api,
      launch: launch,
      locator: launch?.screen == 'location_denied'
          ? const StagedLocator(LocateStatus.deniedForever)
          : const Locator(),
    ),
  );
}

class FonTokMaiApp extends StatefulWidget {
  const FonTokMaiApp({
    super.key,
    required this.state,
    required this.places,
    required this.api,
    this.launch,
    this.locator = const Locator(),
  });

  final AppState state;
  final PlacesStore places;
  final FonTokMaiApi api;
  final Locator locator;

  /// Opens a demo state on start (screenshots, demo video).
  final DemoLaunch? launch;

  @override
  State<FonTokMaiApp> createState() => _FonTokMaiAppState();
}

class _FonTokMaiAppState extends State<FonTokMaiApp> {
  final _nav = GlobalKey<NavigatorState>();
  static final _night = buildTheme(night: true);
  static final _flood = buildTheme(flood: true);

  @override
  void initState() {
    super.initState();
    final l = widget.launch;
    if (l != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(l));
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
        nav.push(
          route(
            VerdictScreen(
              request: DecideRequest(tripId: trip.id),
              trip: trip,
              departAt: hhmm == null
                  ? null
                  : DateTime.parse('${demoDate}T$hhmm:00+07:00'),
              mode: l.mode == null ? null : TravelMode.parse(l.mode),
            ),
          ),
        );
      case 'ask':
        nav.push(route(const AskScreen(opening: 'ออกก่อน 16:45')));
      case 'settings' || 'settings_places':
        nav.push(route(const SettingsScreen()));
      case 'gallery':
        nav.push(route(const SettingsScreen()));
        nav.push(route(const GalleryScreen()));
      case 'place_search':
        nav.push(
          route(
            const PlacePickerScreen(kind: PlaceKind.home, initialQuery: 'สยาม'),
          ),
        );
      case 'location_denied':
        nav.push(
          route(const PlacePickerScreen(kind: PlaceKind.home, locateNow: true)),
        );
      case 'place_confirm':
        nav.push(
          route(
            const PlacePickerScreen(kind: PlaceKind.work, initialQuery: 'สีลม'),
          ),
        );
        final hits = (await widget.api.searchPlaces('สีลม')).data;
        final ctx = _nav.currentContext;
        if (hits.isEmpty || ctx == null || !ctx.mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!ctx.mounted) return;
        showPlaceConfirmSheet(ctx, kind: PlaceKind.work, candidate: hits.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.launch;
    return AppScope(
      state: widget.state,
      places: widget.places,
      api: widget.api,
      locator: widget.locator,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          navigatorKey: _nav,
          onGenerateTitle: (context) => context.l10n.appTitle,
          locale: widget.state.locale,
          supportedLocales: AppState.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: widget.state.flood ? _flood : _night,
          themeAnimationDuration: Motion.sky,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 2,
            child: child!,
          ),
          home: _Root(
            initialTab: l?.screen == 'events'
                ? ShellTab.events
                : ShellTab.summary,
          ),
        ),
      ),
    );
  }
}

/// First launch shows onboarding; after it (or a skip) the tabs.
class _Root extends StatelessWidget {
  const _Root({required this.initialTab});
  final ShellTab initialTab;

  @override
  Widget build(BuildContext context) => AppScope.placesOf(context).onboarded
      ? Shell(initialTab: initialTab)
      : const OnboardingScreen();
}
