import 'package:flutter/material.dart';

import 'api.dart';
import 'app_state.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  final state = AppState(demoClock: initialDemoClock());
  final api = FonTokMaiApi(baseUrl: resolveApiBaseUrl(), demoClock: () => state.demoClock);
  runApp(FonTokMaiApp(state: state, api: api));
}

class FonTokMaiApp extends StatelessWidget {
  const FonTokMaiApp({
    super.key,
    required this.state,
    required this.api,
    this.useGoogleFonts = true,
  });

  final AppState state;
  final FonTokMaiApi api;

  /// Tests turn this off so they never fetch fonts over the network.
  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        api: api,
        child: MaterialApp(
          title: 'ฝนตกไหม',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(useGoogleFonts: useGoogleFonts),
          home: const HomeScreen(),
        ),
      );
}
