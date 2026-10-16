import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../time_th.dart';
import '../trips_repository.dart';
import 'ask_sheet.dart';
import 'event_cards.dart';
import 'place_picker.dart';
import 'settings_screen.dart';
import 'verdict_screen.dart';

/// Everything coming up from Calendar and Gmail: a month to see where the
/// busy days are, and a ticket per event. Tapping a day narrows the list.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.repo, required this.onRefresh});

  final TripsRepository repo;
  final Future<void> Function() onRefresh;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  /// The day the list is narrowed to, or null for every day.
  DateTime? _day;

  TripsRepository get repo => widget.repo;

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _open(Trip t, LeavePlan? plan) => _push(
    VerdictScreen(
      request: repo.requestFor(t),
      trip: t,
      departAt: planDepartFor(t, AppScope.readState(context).now()),
      mode: plan?.best?.mode,
    ),
  );

  Future<void> _resolve(Trip t) async {
    final saved = await pickPlace(
      context,
      kind: PlaceKind.other,
      initialQuery: t.locationTextTh,
    );
    if (saved == null || !mounted) return;
    _open(
      Trip(
        id: 'app-${t.id}',
        titleTh: t.titleTh,
        source: 'app',
        origin: t.origin,
        destination: saved.asPlace,
        arriveBy: t.arriveBy,
        endsAt: t.endsAt,
        mode: t.mode,
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    // The connect card follows the Google link state.
    AppScope.placesOf(context);
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final now = state.now();
        final today = bangkokDay(now);
        final events = upcoming(repo.trips, now);
        final month = DateTime.utc(today.year, today.month);
        final eventDays = {
          for (final e in events)
            if (e.arriveBy != null) bangkokDay(e.arriveBy!),
        };
        final following = DateTime.utc(month.year, month.month + 1);
        // A second month when events run into it, as a wall calendar would.
        final months = [
          month,
          if (eventDays.any(
            (d) =>
                !d.isBefore(following) &&
                d.isBefore(DateTime.utc(month.year, month.month + 2)),
          ))
            following,
        ];
        final shown = _day == null
            ? events
            : events
                  .where(
                    (e) =>
                        e.arriveBy != null && bangkokDay(e.arriveBy!) == _day,
                  )
                  .toList();

        final Widget? placeholder;
        if (!repo.connected) {
          placeholder = ConnectCalendarCard(
            onConnect: () => promptOAuth(context),
            onAsk: () => showAskSheet(context),
          );
        } else if (events.isEmpty && repo.loading) {
          placeholder = const _ListSkeleton();
        } else if (events.isEmpty && repo.error != null) {
          placeholder = GlassSurface(
            padding: const EdgeInsets.all(Space.x5),
            child: ErrorState(
              title: l.summaryLoadErrorTitle,
              message: l.summaryLoadErrorBody,
              onRetry: widget.onRefresh,
            ),
          );
        } else if (events.isEmpty) {
          placeholder = GlassSurface(
            padding: const EdgeInsets.all(Space.x5),
            child: EmptyState(
              icon: Symbols.event_available_rounded,
              title: l.summaryNoEventsTitle,
              message: l.summaryNoEventsBody,
            ),
          );
        } else {
          placeholder = null;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: widget.onRefresh,
            edgeOffset: MediaQuery.paddingOf(context).top,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: LargeTitleHeader(
                      onSky: true,
                      eyebrow: repo.connected
                          ? l.eventsSource(repo.account ?? '')
                          : dayDate(l, now),
                      title: l.eventsTitle,
                      badges: [
                        if (state.usingSample) const SampleBadge(onField: true),
                      ],
                      actions: [
                        if (placeholder == null)
                          IconButton(
                            tooltip: l.eventsCalendar,
                            onPressed: () => _showCalendar(
                              months: months,
                              today: today,
                              eventDays: eventDays,
                            ),
                            icon: const Icon(Symbols.calendar_month_rounded),
                          ),
                        IconButton(
                          tooltip: l.eventsRefresh,
                          onPressed: widget.onRefresh,
                          icon: const Icon(Symbols.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                if (placeholder != null)
                  _pad(placeholder)
                else ...[
                  SliverToBoxAdapter(
                    child: _DayFilter(
                      days: [
                        for (final g in groupByDay(events))
                          if (g.day != null) g.day!,
                      ],
                      today: today,
                      selected: _day,
                      onSelected: (d) => setState(() => _day = d),
                    ),
                  ),
                  if (shown.isEmpty)
                    _pad(
                      Text(
                        l.eventsNoneOn,
                        style: t.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final g in groupByDay(shown)) ...[
                    SliverToBoxAdapter(
                      child: DayHeader(
                        day: g.day,
                        now: now,
                        count: g.trips.length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      sliver: SliverList.separated(
                        itemCount: g.trips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Space.x3),
                        itemBuilder: (context, i) => _ticket(g.trips[i], now),
                      ),
                    ),
                  ],
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: GlassNavBar.inset(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The month view, on demand: pick a day to filter the list to it.
  Future<void> _showCalendar({
    required List<DateTime> months,
    required DateTime today,
    required Set<DateTime> eventDays,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.x8,
        ),
        children: [
          for (final (i, m) in months.indexed) ...[
            if (i > 0) const SizedBox(height: Space.x3),
            MonthCalendar(
              month: m,
              today: today,
              selected: _day,
              eventDays: eventDays,
              onDay: (d) {
                setState(() => _day = eventDays.contains(d) ? d : null);
                Navigator.of(sheet).pop();
              },
            ),
          ],
        ],
      ),
    ),
  );

  Widget _pad(Widget child) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    sliver: SliverToBoxAdapter(child: child),
  );

  Widget _ticket(Trip trip, DateTime now) {
    final d = repo.decisionFor(trip.id);
    final plan = d == null
        ? null
        : planOf(d, planDepartFor(trip, now), now, deadline: trip.arriveBy);
    return EventTicket(
      key: ValueKey('event-${trip.id}'),
      trip: trip,
      plan: plan,
      onTap: trip.unresolved
          ? () => _resolve(trip)
          : trip.travels
          ? () => _open(trip, plan)
          : null,
    );
  }
}

/// One event as a glass ticket: date stub, time and title above the
/// perforation; the place and, when known, the leave-at answer below.
class EventTicket extends StatelessWidget {
  const EventTicket({super.key, required this.trip, this.plan, this.onTap});
  final Trip trip;
  final LeavePlan? plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final at = trip.arriveBy;
    final p = plan;
    final best = p?.best;

    return MergeSemantics(
      child: GlassTicket(
        radius: Radii.lg,
        onTap: onTap,
        top: Padding(
          padding: const EdgeInsets.all(Space.x3),
          child: Row(
            children: [
              if (at != null) DateBlock(at: at, size: 52),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          sourceIcon(trip.source),
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Space.x1),
                        Text(
                          at == null
                              ? l.eventsNoTime
                              : trip.allDay
                              ? l.allDay
                              : hhmm(at),
                          style: tabular(
                            t.labelMedium!,
                          ).copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Text(
                      trip.titleTh,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x4,
            Space.x3,
            Space.x4,
            Space.x3,
          ),
          child: Wrap(
            spacing: Space.x3,
            runSpacing: Space.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trip.unresolved
                        ? Symbols.help_rounded
                        : trip.virtual
                        ? Symbols.videocam_rounded
                        : Symbols.location_on_rounded,
                    size: 16,
                    fill: 1,
                    color: trip.unresolved
                        ? c.warning
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Space.x1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .5,
                    ),
                    child: Text(
                      trip.unresolved
                          ? l.summarySetPlace
                          : trip.virtual
                          ? l.online
                          : trip.destination.nameTh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(
                        color: trip.unresolved
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (p != null && best != null)
                Text(
                  p.kind == LeaveKind.avoid
                      ? l.eventsAvoid
                      : l.eventsLeaveAt(
                          p.time == null || p.kind == LeaveKind.overdue
                              ? l.summaryLeaveNow
                              : hhmm(p.time!),
                          best.mode.label(l),
                        ),
                  style: tabular(t.labelLarge!),
                ),
              if (best != null) RiskChip(risk: best.risk, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// A month of day circles; days with events glow in the CI gradient.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.eventDays,
    this.onMonth,
    required this.onDay,
    this.selected,
  });

  /// First of the month, UTC midnight of the Bangkok date.
  final DateTime month;
  final DateTime today;
  final Set<DateTime> eventDays;
  final DateTime? selected;

  /// Moves to another month; null hides the arrows.
  final ValueChanged<DateTime>? onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    // Weeks start on Sunday, as Thai wall calendars do.
    final lead = month.weekday % 7;

    Widget cell(int day) {
      final d = DateTime.utc(month.year, month.month, day);
      final has = eventDays.contains(d);
      final isToday = d == today;
      final isSel = d == selected;
      final past = d.isBefore(today);
      return Semantics(
        button: true,
        selected: isSel,
        label: '$day',
        child: InkResponse(
          onTap: () => onDay(d),
          radius: 22,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel
                    ? Colors.white
                    : (has ? null : Colors.white.withValues(alpha: .04)),
                gradient: has && !isSel
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E6BFF), Color(0xFF14A8DC)],
                      )
                    : null,
                border: Border.all(
                  color: isToday
                      ? Colors.white
                      : Colors.white.withValues(alpha: .10),
                  width: isToday ? 1.5 : 1,
                ),
                boxShadow: has && !isSel
                    ? const [
                        BoxShadow(color: Color(0x662E6BFF), blurRadius: 12),
                      ]
                    : null,
              ),
              child: Text(
                '$day',
                style: tabular(t.labelLarge!).copyWith(
                  color: isSel
                      ? const Color(0xFF0B1F3A)
                      : past && !has
                      ? scheme.onSurfaceVariant.withValues(alpha: .5)
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(
        Space.x3,
        Space.x2,
        Space.x3,
        Space.x3,
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Space.target),
            child: Row(
              children: [
                if (onMonth != null)
                  IconButton(
                    tooltip: l.calPrev,
                    onPressed: () =>
                        onMonth!(DateTime.utc(month.year, month.month - 1)),
                    icon: const Icon(Symbols.chevron_left_rounded),
                  ),
                Expanded(
                  child: Text(
                    l.calMonth('${month.month}', '${month.year}'),
                    textAlign: onMonth == null
                        ? TextAlign.start
                        : TextAlign.center,
                    style: t.titleMedium,
                  ),
                ),
                if (onMonth != null)
                  IconButton(
                    tooltip: l.calNext,
                    onPressed: () =>
                        onMonth!(DateTime.utc(month.year, month.month + 1)),
                    icon: const Icon(Symbols.chevron_right_rounded),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.x1),
          Row(
            children: [
              for (final iso in [7, 1, 2, 3, 4, 5, 6])
                Expanded(
                  child: Text(
                    weekdayInitial(l, iso),
                    textAlign: TextAlign.center,
                    style: t.labelSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.x2),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.x1,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= days; d++) cell(d),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.designLoadingAnswer,
    child: const GlassSurface(
      padding: EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 140, height: 16),
          SizedBox(height: Space.x4),
          Skeleton(height: 220, radius: Radii.md),
          SizedBox(height: Space.x5),
          Skeleton(height: 64, radius: Radii.md),
          SizedBox(height: Space.x3),
          Skeleton(height: 64, radius: Radii.md),
        ],
      ),
    ),
  );
}

/// "ทุกวัน · วันนี้ · พรุ่งนี้ · ส 3 ต.ค.": the days that have events, as
/// chips to narrow the list.
class _DayFilter extends StatelessWidget {
  const _DayFilter({
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelected,
  });
  final List<DateTime> days;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, DateTime? day) {
      final on = day == selected;
      return Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? Colors.white : Colors.white.withValues(alpha: .08),
          shape: StadiumBorder(
            side: BorderSide(
              color: on ? Colors.white : Colors.white.withValues(alpha: .14),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onSelected(on ? null : day),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: t.labelLarge!.copyWith(
                      color: on ? const Color(0xFF0B1F3A) : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          chip(l.eventsAllDays, null),
          for (final d in days) ...[
            const SizedBox(width: Space.x2),
            chip(dayChipLabel(l, d, today), d),
          ],
        ],
      ),
    );
  }
}
