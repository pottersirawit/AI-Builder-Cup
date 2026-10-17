import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'ask_sheet.dart';
import 'event_cards.dart';
import 'verdict_screen.dart';
import 'weather_cards.dart';

/// An all-day event has no time to leave by: the sheet says which days it
/// covers and where, and, on one of those days, asks the way there now.
Future<void> showAllDaySheet(
  BuildContext context, {
  required Trip trip,
  required DateTime now,
  Outlook? outlook,
}) {
  final nav = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) {
      final l = sheet.l10n;
      final t = Theme.of(sheet).textTheme;
      final scheme = Theme.of(sheet).colorScheme;
      final place = trip.destination.nameTh.trim();
      final today = onDay(trip, bangkokDay(now));

      Widget line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: Space.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(
                text,
                style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.x8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trip.titleTh, style: t.headlineSmall),
            line(Symbols.event_rounded, allDayLabel(l, trip, dated: true)),
            if (place.isNotEmpty) line(Symbols.location_on_rounded, place),
            const SizedBox(height: Space.x4),
            Notice(icon: Symbols.info_rounded, text: l.allDayNote),
            if (today && outlook != null) ...[
              const SizedBox(height: Space.x3),
              WeatherPeek(outlook: outlook, now: now),
            ],
            if (today && place.isNotEmpty) ...[
              const SizedBox(height: Space.x4),
              FilledButton.icon(
                icon: const Icon(Symbols.directions_rounded),
                label: Text(l.allDayAskRoute(place)),
                onPressed: () {
                  final request = askRequest(
                    context,
                    l.homeQuestionToNow(place),
                  );
                  Navigator.of(sheet).pop();
                  nav.push(
                    MaterialPageRoute<void>(
                      builder: (_) => VerdictScreen(request: request),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
