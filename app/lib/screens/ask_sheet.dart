import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import 'verdict_screen.dart';

/// Ask about any trip in words. The trip home lives here now, as a
/// suggestion, instead of on the summary.
Future<void> showAskSheet(BuildContext context) {
  final nav = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => _AskSheet(
      onAsk: (q) {
        Navigator.of(sheet).pop();
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => VerdictScreen(request: askRequest(context, q)),
          ),
        );
      },
    ),
  );
}

/// A question asked from the phone's position, against the saved places.
DecideRequest askRequest(BuildContext context, String question) {
  final loc = AppScope.readState(context).currentLocation;
  return DecideRequest(
    questionTh: question,
    origin: loc?.ok == true
        ? Place(
            nameTh: loc!.nameTh ?? context.l10n.homeCurrentPlace,
            lat: loc.lat,
            lng: loc.lng,
          )
        : null,
    places: AppScope.readPlaces(context).places,
  );
}

class _AskSheet extends StatelessWidget {
  const _AskSheet({required this.onAsk});
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final store = AppScope.placesOf(context);
    final suggestions = [
      if (store.home != null) (Symbols.home_rounded, l.homeQuestionHomeNow),
      for (final p in store.others)
        (placeIcon(p.icon), l.homeQuestionToNow(p.labelFor(l))),
      (Symbols.wb_twilight_rounded, l.askTomorrowMorning),
      (Symbols.camping_rounded, l.askActivitySuggestion),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.askSheetTitle, style: t.headlineSmall),
          const SizedBox(height: Space.x4),
          AskBar(onSubmit: onAsk, hint: l.designAskHint),
          const SizedBox(height: Space.x4),
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              for (final (icon, q) in suggestions)
                ActionChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(q),
                  onPressed: () => onAsk(q),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
