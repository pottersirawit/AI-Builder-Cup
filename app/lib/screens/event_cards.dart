import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../departure.dart';
import '../design/design.dart';
import '../events.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../time_th.dart';

/// "อีก 2 ชม. 20 นาที": time until an event starts.
String untilText(AppLocalizations l, Duration d) =>
    d.inMinutes <= 0 ? l.summaryStarted : l.summaryIn(durationText(l, d));

/// "2 ชม. 20 นาที", or whole days from a day on.
String durationText(AppLocalizations l, Duration d) {
  if (d.inHours >= 24) return l.durationD('${d.inDays}');
  final h = d.inHours, m = d.inMinutes % 60;
  return h == 0
      ? l.durationM('$m')
      : (m == 0 ? l.durationH('$h') : l.durationHm('$h', '$m'));
}

/// "ศุกร์ 17 ต.ค.": a Bangkok date without the time.
String dayDate(AppLocalizations l, DateTime t) {
  final b = toBangkok(t);
  return '${l.weekdayName('${b.weekday}')} ${b.day} ${monthShort(l, t)}';
}

/// Rain words for [rainLevel]: none, light, moderate, heavy.
String rainWord(AppLocalizations l, int level) => switch (level) {
  0 => l.summaryRainNone,
  1 => l.summaryRainLight,
  2 => l.summaryRainModerate,
  _ => l.summaryRainHeavy,
};

/// The ranked plan for a decided trip planned from [departAt].
LeavePlan planOf(
  Decision d,
  DateTime departAt,
  DateTime now, {
  DateTime? deadline,
}) => leavePlan(
  d,
  rankOptions(serverOptions(d, departAt)),
  now,
  deadline: deadline,
);

/// The leave line in words, e.g. "ควรออกก่อน 16:45".
String leaveSentence(AppLocalizations l, LeavePlan p) => switch (p.kind) {
  LeaveKind.before => '${l.summaryLeaveBefore} ${hhmm(p.time!)}',
  LeaveKind.at => '${l.summaryLeaveAt} ${hhmm(p.time!)}',
  LeaveKind.now => l.summaryLeaveNow,
  LeaveKind.overdue => l.summaryOverdue(hhmm(p.time!)),
  LeaveKind.avoid => l.summaryAvoid,
};

/// Health-app style page title: a small date line over a large title.
class LargeTitleHeader extends StatelessWidget {
  const LargeTitleHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.onSky = false,
    this.badges = const [],
    this.actions = const [],
  });
  final String eyebrow;
  final String title;
  final bool onSky;

  /// Status pills beside the date line, e.g. "เดโม".
  final List<Widget> badges;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sky = FonColors.of(context).clear;
    final ink = onSky ? sky.onField : scheme.onSurface;
    final muted = onSky ? sky.onFieldMuted : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x1,
        Space.x2,
        Space.x5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Space.target),
            child: IconTheme.merge(
              data: IconThemeData(color: ink),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: Space.x2),
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        eyebrow,
                        style: t.labelLarge!.copyWith(color: muted),
                      ),
                      ...badges,
                    ],
                  ),
                  Text(title, style: t.headlineLarge!.copyWith(color: ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero: the next event and the one answer about it, "leave before
/// 16:45 by BTS". The whole card opens the detail.
class NextEventCard extends StatelessWidget {
  const NextEventCard({
    super.key,
    required this.trip,
    required this.now,
    this.plan,
    this.summary,
    this.loading = false,
    this.failed = false,
    this.unresolved = false,
    this.onTap,
    this.onRetry,
    this.onResolvePlace,
    this.footer,
    this.aside,
  });

  final Trip trip;
  final DateTime now;
  final LeavePlan? plan;

  /// Under the leave answer, e.g. what to bring for this trip.
  final Widget? footer;

  /// Beside the leave time, e.g. the countdown to it.
  final Widget? aside;

  /// The agent's one-paragraph reason, shown under the leave time.
  final String? summary;
  final bool loading;
  final bool failed;
  final bool unresolved;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onResolvePlace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final p = plan;
    final arriveBy = trip.arriveBy;

    final Widget body;
    if (unresolved) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.summaryUnresolved,
            style: t.bodyMedium!.copyWith(color: c.paperInk),
          ),
          const SizedBox(height: Space.x4),
          FilledButton.icon(
            onPressed: onResolvePlace,
            icon: const Icon(Symbols.add_location_alt_rounded),
            label: Text(l.summarySetPlace),
          ),
        ],
      );
    } else if (p != null) {
      body = _LeaveBlock(
        plan: p,
        summary: summary,
        deadline: arriveBy,
        footer: footer,
        aside: aside,
      );
    } else if (failed) {
      body = Row(
        children: [
          Icon(Symbols.cloud_off_rounded, color: muted),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              l.summaryDecideError,
              style: t.bodyMedium!.copyWith(color: c.paperInk),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.summaryRetry)),
        ],
      );
    } else {
      body = Semantics(
        label: l.designLoadingAnswer,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 96, height: 12),
            SizedBox(height: Space.x2),
            Skeleton(width: 168, height: 44, radius: Radii.sm),
            SizedBox(height: Space.x3),
            Skeleton(height: 12),
            SizedBox(height: Space.x5),
            Skeleton(height: 36, radius: Radii.sm),
          ],
        ),
      );
    }

    final top = Padding(
      padding: const EdgeInsets.all(Space.x4),
      child: Row(
        children: [
          if (arriveBy != null) DateBlock(at: arriveBy) else const SizedBox(),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arriveBy == null
                      ? l.summaryNextEvent
                      : untilText(l, arriveBy.difference(now)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabular(t.labelMedium!).copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.titleTh,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge!.copyWith(color: c.paperInk),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(sourceIcon(trip.source), size: 14, color: muted),
                    const SizedBox(width: Space.x1),
                    Expanded(
                      child: Text(
                        [
                          if (arriveBy != null) hhmm(arriveBy),
                          unresolved
                              ? (trip.locationTextTh ?? '')
                              : trip.destination.nameTh,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tabular(t.bodySmall!).copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Symbols.chevron_right_rounded, size: 20, color: muted),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: p == null || arriveBy == null
          ? null
          : l.summaryHeroSemantics(
              trip.titleTh,
              hhmm(arriveBy),
              leaveSentence(l, p),
            ),
      child: GlassTicket(
        onTap: onTap,
        top: top,
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x4,
            Space.x5,
            Space.x5,
          ),
          child: AnimatedSwitcher(
            duration: Motion.of(context).d(Motion.flap),
            child: KeyedSubtree(
              key: ValueKey(
                '${p?.kind}-${p?.time}-${p?.best?.mode}-$loading-$failed',
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// A day number over its month: the ticket's stub, where the reference
/// puts a photo.
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.at, this.size = 64});
  final DateTime at;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E6BFF), Color(0xFF14A8DC)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x552E6BFF),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Space.x1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(
              '${dayOfMonth(at)}',
              style: tabular(
                t.headlineMedium!,
              ).copyWith(color: Colors.white, height: 1.1),
            ),
            Text(
              monthShort(l, at),
              style: t.labelMedium!.copyWith(color: const Color(0xDDFFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveBlock extends StatelessWidget {
  const _LeaveBlock({
    required this.plan,
    this.summary,
    this.deadline,
    this.footer,
    this.aside,
  });
  final LeavePlan plan;
  final String? summary;
  final Widget? footer;
  final Widget? aside;

  /// When the event starts; arriving after it earns a warning.
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final p = plan;
    final (String? label, String big) = switch (p.kind) {
      LeaveKind.before => (l.summaryLeaveBefore, hhmm(p.time!)),
      LeaveKind.at => (l.summaryLeaveAt, hhmm(p.time!)),
      LeaveKind.now => (null, l.summaryLeaveNow),
      LeaveKind.overdue => (l.summaryOverdue(hhmm(p.time!)), l.summaryGoNow),
      LeaveKind.avoid => (null, l.summaryAvoid),
    };
    final isTime = p.kind == LeaveKind.before || p.kind == LeaveKind.at;
    final late = deadline == null || p.kind == LeaveKind.avoid
        ? Duration.zero
        : p.arriveAt.difference(deadline!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label, style: t.labelLarge!.copyWith(color: muted)),
                  Text(
                    big,
                    style: isTime
                        ? tabular(t.displayLarge!).copyWith(color: c.paperInk)
                        : t.displaySmall!.copyWith(color: c.paperInk),
                  ),
                ],
              ),
            ),
            if (aside != null) ...[const SizedBox(width: Space.x3), aside!],
          ],
        ),
        if (late.inMinutes > 0) ...[
          const SizedBox(height: Space.x1),
          RiskChip(
            risk: Risk.medium,
            label: l.summaryLate(durationText(l, late)),
            dense: true,
          ),
        ],
        if (summary != null && summary!.isNotEmpty) ...[
          const SizedBox(height: Space.x1),
          Text(
            summary!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium!.copyWith(color: c.paperInk),
          ),
        ],
        const SizedBox(height: Space.x4),
        Divider(height: 1, color: c.perforation),
        const SizedBox(height: Space.x3),
        LeaveMetaRow(plan: p),
        if (footer != null) ...[const SizedBox(height: Space.x4), footer!],
      ],
    );
  }
}

/// Three facts under the leave time: mode, arrival, rain risk.
class LeaveMetaRow extends StatelessWidget {
  const LeaveMetaRow({super.key, required this.plan});
  final LeavePlan plan;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final best = plan.best;
    Widget cell(String caption, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(caption, style: t.labelSmall!.copyWith(color: muted)),
        const SizedBox(height: Space.x1),
        value,
      ],
    );
    final cells = [
      if (best != null)
        cell(
          l.summaryBy,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(best.mode.icon, size: 18, color: c.paperInk),
              const SizedBox(width: Space.x1),
              Flexible(
                child: Text(
                  best.mode.label(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall!.copyWith(color: c.paperInk),
                ),
              ),
            ],
          ),
        ),
      if (plan.kind != LeaveKind.avoid)
        cell(
          l.summaryArrive,
          Text(
            hhmm(plan.arriveAt),
            style: tabular(t.titleSmall!).copyWith(color: c.paperInk),
          ),
        ),
      if (best != null)
        cell(l.summaryRain, RiskChip(risk: best.risk, dense: true)),
    ];
    if (MediaQuery.textScalerOf(context).scale(10) > 15) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, x) in cells.indexed) ...[
            if (i > 0) const SizedBox(height: Space.x3),
            x,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, x) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: Space.x3),
          Expanded(child: x),
        ],
      ],
    );
  }
}

/// One event in a list: time column, title, place and, when known, the
/// leave-at answer.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.trip,
    this.plan,
    this.showDay = false,
    this.onTap,
  });
  final Trip trip;
  final LeavePlan? plan;

  /// Prefix the time with the date (rows outside a day group).
  final bool showDay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final at = trip.arriveBy;
    final p = plan;

    final Widget? detail;
    if (trip.unresolved) {
      detail = Row(
        children: [
          Icon(Symbols.help_rounded, size: 16, color: c.warning, fill: 1),
          const SizedBox(width: Space.x1),
          Text(
            l.summarySetPlace,
            style: t.labelLarge!.copyWith(color: scheme.primary),
          ),
        ],
      );
    } else if (p != null) {
      final best = p.best;
      detail = Wrap(
        spacing: Space.x2,
        runSpacing: Space.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            p.kind == LeaveKind.avoid || best == null
                ? l.eventsAvoid
                : l.eventsLeaveAt(
                    p.time == null || p.kind == LeaveKind.overdue
                        ? l.summaryLeaveNow
                        : hhmm(p.time!),
                    best.mode.label(l),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tabular(t.labelLarge!).copyWith(color: scheme.onSurface),
          ),
          if (best != null) RiskChip(risk: best.risk, dense: true),
        ],
      );
    } else {
      detail = null;
    }

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDay && at != null)
                        Text(
                          '${dayOfMonth(at)} ${monthShort(l, at)}',
                          style: t.labelSmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        at == null ? '–' : hhmm(at),
                        style: tabular(t.titleMedium!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.titleTh,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium,
                      ),
                      Row(
                        children: [
                          Icon(
                            sourceIcon(trip.source),
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Space.x1),
                          Expanded(
                            child: Text(
                              trip.unresolved
                                  ? '“${trip.locationTextTh ?? ''}”'
                                  : trip.destination.nameTh,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: Space.x1),
                        detail,
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Symbols.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
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

/// Rows grouped on one rounded surface with inset dividers.
class EventGroup extends StatelessWidget {
  const EventGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: Radii.lg,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, w) in children.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 72 + Space.x3,
                  color: Colors.white.withValues(alpha: .10),
                ),
              w,
            ],
          ],
        ),
      ),
    );
  }
}

/// "วันนี้ · ศุกร์ 17 ต.ค." over a day's events.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.day,
    required this.now,
    this.count,
  });

  /// A Bangkok date as UTC midnight (see [bangkokDay]); null for untimed.
  final DateTime? day;
  final DateTime now;

  /// Events that day, shown at the trailing edge.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final d = day;
    final String title;
    String? date;
    if (d == null) {
      title = l.eventsNoTime;
    } else {
      // Noon Bangkok on that date, so the helpers land on the same day.
      final at = d.add(const Duration(hours: 5));
      final diff = d.difference(bangkokDay(now)).inDays;
      title = diff == 0
          ? l.dayToday
          : diff == 1
          ? l.dayTomorrow
          : l.weekdayName('${toBangkok(at).weekday}');
      date = '${dayOfMonth(at)} ${monthShort(l, at)}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter + Space.x1,
        Space.x6,
        Space.gutter + Space.x1,
        Space.x3,
      ),
      child: Semantics(
        header: true,
        child: Wrap(
          spacing: Space.x2,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(title, style: t.titleLarge),
            if (date != null)
              Text(
                date,
                style: tabular(
                  t.bodyMedium!,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            if (count != null)
              Text(
                '· ${l.eventsCount('$count')}',
                style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// A day as a filter chip: "วันนี้", "พรุ่งนี้", or "ส 3 ต.ค.".
String dayChipLabel(AppLocalizations l, DateTime day, DateTime today) {
  final diff = day.difference(today).inDays;
  if (diff == 0) return l.dayToday;
  if (diff == 1) return l.dayTomorrow;
  final at = day.add(const Duration(hours: 5));
  return '${weekdayInitial(l, toBangkok(at).weekday)} ${dayOfMonth(at)} ${monthShort(l, at)}';
}

/// No calendar yet: the reason to connect one, and a way around it.
class ConnectCalendarCard extends StatelessWidget {
  const ConnectCalendarCard({
    super.key,
    required this.onConnect,
    required this.onAsk,
  });
  final VoidCallback onConnect;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(
                Symbols.calendar_month_rounded,
                color: scheme.onPrimaryContainer,
                fill: 1,
              ),
            ),
          ),
          const SizedBox(height: Space.x4),
          Text(
            l.summaryConnectTitle,
            style: t.titleLarge!.copyWith(color: c.paperInk),
          ),
          const SizedBox(height: Space.x1),
          Text(
            l.summaryConnectBody,
            style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.x5),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: onConnect,
            icon: const Icon(Symbols.link_rounded),
            label: Text(l.summaryConnectCta),
          ),
          const SizedBox(height: Space.x1),
          TextButton(onPressed: onAsk, child: Text(l.summaryAskInstead)),
        ],
      ),
    );
  }
}

/// Flood mode's banner over the hero: the home is in danger.
class FloodAlertCard extends StatelessWidget {
  const FloodAlertCard({
    super.key,
    required this.headline,
    required this.onWhatToDo,
  });
  final String headline;
  final VoidCallback onWhatToDo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    return Material(
      color: c.riskHighContainer,
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Padding(
        padding: const EdgeInsets.all(Space.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Symbols.flood_rounded, color: c.warning, fill: 1),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    l.summaryFloodTitle,
                    style: t.titleMedium!.copyWith(color: c.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x2),
            Text(headline, style: t.headlineSmall!.copyWith(color: c.paperInk)),
            const SizedBox(height: Space.x4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(Space.targetLarge),
              ),
              onPressed: onWhatToDo,
              icon: const Icon(Symbols.checklist_rounded),
              label: Text(l.summaryFloodWhatToDo),
            ),
          ],
        ),
      ),
    );
  }
}
