import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../time_th.dart';
import 'event_cards.dart' show dayDate;
import 'parts.dart';
import 'place_picker.dart';

IconData activityIcon(String kind) => switch (kind) {
  'climbing' => Symbols.landscape_rounded,
  'camping' => Symbols.camping_rounded,
  'hiking' => Symbols.hiking_rounded,
  'beach' => Symbols.beach_access_rounded,
  'cycling' => Symbols.directions_bike_rounded,
  'running' => Symbols.directions_run_rounded,
  _ => Symbols.backpack_rounded,
};

/// Where the trip to a day out starts: the phone, else home; null when
/// neither is known.
Place? activityOrigin(BuildContext context) {
  final loc = AppScope.readState(context).currentLocation;
  if (loc?.ok == true) {
    return Place(
      nameTh: loc!.nameTh ?? context.l10n.homeCurrentPlace,
      lat: loc.lat,
      lng: loc.lng,
    );
  }
  return AppScope.readPlaces(context).home?.asPlace;
}

/// The next four days the user might mean: today, tomorrow and the coming
/// weekend.
List<DateTime> activityDays(DateTime now) {
  final today = bangkokDay(now);
  final out = <DateTime>[today, today.add(const Duration(days: 1))];
  for (var i = 2; i < 8 && out.length < 4; i++) {
    final d = today.add(Duration(days: i));
    final wd = toBangkok(d).weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) out.add(d);
  }
  return out;
}

/// The answer to "ไปปีนผาต้องเตรียมอะไร" before there is a place: what to
/// bring now, and when and where to make it about the weather there.
class ActivityAskPass extends StatefulWidget {
  const ActivityAskPass({
    super.key,
    required this.plan,
    required this.now,
    required this.onPlan,
  });
  final ActivityPlan plan;
  final DateTime now;

  /// The user picked a place for the chosen day.
  final void Function(Place destination, DateTime day) onPlan;

  @override
  State<ActivityAskPass> createState() => _ActivityAskPassState();
}

class _ActivityAskPassState extends State<ActivityAskPass> {
  late DateTime _day = _initialDay();

  DateTime _initialDay() {
    final days = activityDays(widget.now);
    final asked = widget.plan.activity.day;
    if (asked == null) return days.first;
    return days.firstWhere(
      (d) => isoDay(d) == asked,
      orElse: () => DateTime.parse('${asked}T00:00:00+07:00'),
    );
  }

  Future<void> _pick(String? query) async {
    final picked = await pickPoint(context, initialQuery: query);
    if (picked == null || !mounted) return;
    widget.onPlan(
      Place(nameTh: picked.nameTh, lat: picked.lat, lng: picked.lng),
      _day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final plan = widget.plan;
    final days = {
      for (final d in activityDays(widget.now)) isoDay(d): d,
      isoDay(_day): _day,
    }.values.toList()..sort();
    final today = bangkokDay(widget.now);
    String dayLabel(DateTime d) => switch (bangkokDay(d).difference(today)) {
      Duration(inHours: 0) => l.activityToday,
      Duration(inHours: 24) => l.activityTomorrow,
      _ => dayDate(l, d),
    };

    Widget label(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 16, color: c.paperMuted),
        const SizedBox(width: Space.x1),
        Text(text, style: t.labelLarge!.copyWith(color: c.paperMuted)),
      ],
    );

    return Pass(
      semanticLabel: plan.headlineTh,
      sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    activityIcon(plan.activity.kind),
                    size: 18,
                    color: c.paperMuted,
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text(
                      plan.activity.nameTh,
                      style: t.titleSmall!.copyWith(color: c.paperInk),
                    ),
                  ),
                  GeneratedBy(plan.generatedBy),
                ],
              ),
              const SizedBox(height: Space.x3),
              Text(
                plan.headlineTh,
                style: t.headlineMedium!.copyWith(color: c.paperInk),
              ),
              const SizedBox(height: Space.x3),
              ActivityChecklist(items: plan.checklist, onPaper: true),
              const SizedBox(height: Space.x2),
              Text(
                l.activityGeneralNote,
                style: t.bodySmall!.copyWith(color: c.paperMuted),
              ),
            ],
          ),
        ),
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.askTh,
                style: t.titleMedium!.copyWith(color: c.paperInk),
              ),
              const SizedBox(height: Space.x3),
              label(Symbols.calendar_today_rounded, l.activityWhen),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  for (final d in days)
                    ChoiceChip(
                      key: ValueKey('activity-day-${isoDay(d)}'),
                      label: Text(dayLabel(d)),
                      selected: isoDay(d) == isoDay(_day),
                      onSelected: (_) => setState(() => _day = d),
                    ),
                ],
              ),
              const SizedBox(height: Space.x4),
              label(Symbols.location_on_rounded, l.activityWhere),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  for (final s in plan.suggestionsTh)
                    ActionChip(
                      key: ValueKey('activity-place-$s'),
                      avatar: const Icon(Symbols.place_rounded, size: 18),
                      label: Text(s),
                      onPressed: () => _pick(s),
                    ),
                  ActionChip(
                    key: const ValueKey('activity-search'),
                    avatar: const Icon(Symbols.search_rounded, size: 18),
                    label: Text(l.activitySearchPlace),
                    onPressed: () => _pick(null),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Things to bring, each ticked off by tapping. Ticks live only on screen.
class ActivityChecklist extends StatefulWidget {
  const ActivityChecklist({
    super.key,
    required this.items,
    this.onPaper = false,
  });
  final List<ChecklistItem> items;

  /// Drawn on a pass rather than the page surface.
  final bool onPaper;

  @override
  State<ActivityChecklist> createState() => _ActivityChecklistState();
}

class _ActivityChecklistState extends State<ActivityChecklist> {
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ink = widget.onPaper ? c.paperInk : scheme.onSurface;
    final muted = widget.onPaper ? c.paperMuted : scheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in widget.items.indexed)
          Semantics(
            checked: _done.contains(i),
            child: InkWell(
              key: ValueKey('check-$i'),
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => setState(
                () => _done.contains(i) ? _done.remove(i) : _done.add(i),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _done.contains(i)
                          ? Symbols.check_circle_rounded
                          : Symbols.radio_button_unchecked_rounded,
                      size: 20,
                      fill: _done.contains(i) ? 1 : 0,
                      color: _done.contains(i) ? c.riskLow : muted,
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemTh,
                            style: t.bodyLarge!.copyWith(
                              color: ink,
                              decoration: _done.contains(i)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.whyTh.isNotEmpty)
                            Text(
                              item.whyTh,
                              style: t.bodySmall!.copyWith(color: muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_done.isNotEmpty)
          Text(
            context.l10n.activityChecked(
              '${_done.length}',
              '${widget.items.length}',
            ),
            style: tabular(t.labelMedium!).copyWith(color: muted),
          ),
      ],
    );
  }
}

/// The day out on the trip's page: its day's weather at the place, what that
/// weather means for it, and the checklist.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.plan});
  final ActivityPlan plan;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final f = plan.forecast;
    final day = plan.activity.day == null
        ? null
        : DateTime.parse('${plan.activity.day}T00:00:00+07:00');
    return Section(
      key: const ValueKey('activity-section'),
      title: plan.headlineTh,
      trailing: Icon(
        activityIcon(plan.activity.kind),
        size: 22,
        color: scheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day != null && plan.placeTh.isNotEmpty)
            Text(
              l.activityWeatherOn(dayDate(l, day), plan.placeTh),
              style: t.titleSmall,
            ),
          const SizedBox(height: Space.x2),
          if (f == null)
            Text(
              l.activityNoForecast,
              style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            for (final (i, note) in plan.weatherNotesTh.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i == 0
                          ? Symbols.partly_cloudy_day_rounded
                          : Symbols.info_rounded,
                      size: 20,
                      color: i == 0 ? scheme.primary : scheme.tertiary,
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Text(
                        note,
                        style: tabular(i == 0 ? t.bodyLarge! : t.bodyMedium!),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Space.x3),
          Text(l.activityChecklistTitle, style: t.titleSmall),
          const SizedBox(height: Space.x1),
          ActivityChecklist(items: plan.checklist),
          const SizedBox(height: Space.x2),
          GeneratedBy(plan.generatedBy),
        ],
      ),
    );
  }
}
