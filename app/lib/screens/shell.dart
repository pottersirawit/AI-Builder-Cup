import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import 'flood_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import '../l10n/l10n.dart';

enum ShellTab { board, report, home }

/// Root: Material navigation bar over three destinations.
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    this.initialTab = ShellTab.board,
    this.autoSubmitReport = false,
  });
  final ShellTab initialTab;

  /// Demo hook: the report tab submits a sample report on open.
  final bool autoSubmitReport;

  static void goTo(BuildContext context, ShellTab tab) =>
      context.findAncestorStateOfType<_ShellState>()?._go(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late ShellTab _tab = widget.initialTab;
  late final Set<ShellTab> _visited = {_tab};

  void _go(ShellTab t) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() {
      _tab = t;
      _visited.add(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          const HomeScreen(),
          if (_visited.contains(ShellTab.report))
            ReportScreen(autoSubmit: widget.autoSubmitReport)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.home))
            const FloodScreen()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _go(ShellTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Symbols.departure_board_rounded),
            label: context.l10n.shellTabTrip,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.photo_camera_rounded),
            label: context.l10n.shellTabReport,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.flood,
              backgroundColor: FonColors.of(context).warning,
              textColor: const Color(0xFF2A1A00),
              label: const Text('!'),
              child: const Icon(Symbols.home_rounded),
            ),
            label: context.l10n.shellTabHome,
          ),
        ],
      ),
    );
  }
}
