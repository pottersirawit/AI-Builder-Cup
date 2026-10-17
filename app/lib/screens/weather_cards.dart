import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../carry.dart';
import '../departure.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../time_th.dart';

/// Material symbol for a Google weather condition type.
IconData weatherIcon(String condition, {bool night = false}) =>
    switch (condition) {
      'THUNDERSTORM' ||
      'THUNDERSHOWER' ||
      'LIGHT_THUNDERSTORM_RAIN' ||
      'SCATTERED_THUNDERSTORMS' ||
      'HEAVY_THUNDERSTORM' => Symbols.thunderstorm_rounded,
      'HEAVY_RAIN' || 'HEAVY_RAIN_SHOWERS' => Symbols.rainy_heavy_rounded,
      'LIGHT_RAIN' ||
      'LIGHT_RAIN_SHOWERS' ||
      'CHANCE_OF_SHOWERS' => Symbols.rainy_light_rounded,
      'RAIN' ||
      'RAIN_SHOWERS' ||
      'RAIN_PERIODICALLY_HEAVY' ||
      'MODERATE_TO_HEAVY_RAIN' => Symbols.rainy_rounded,
      'CLOUDY' || 'MOSTLY_CLOUDY' => Symbols.cloud_rounded,
      'PARTLY_CLOUDY' || 'MOSTLY_CLEAR' =>
        night
            ? Symbols.partly_cloudy_night_rounded
            : Symbols.partly_cloudy_day_rounded,
      _ => night ? Symbols.clear_night_rounded : Symbols.sunny_rounded,
    };

/// The glow colour behind a condition's icon.
Color weatherGlow(String condition, {bool night = false}) {
  final icon = weatherIcon(condition, night: night);
  if (icon == Symbols.sunny_rounded ||
      icon == Symbols.partly_cloudy_day_rounded) {
    return const Color(0xFFFFB547);
  }
  if (icon == Symbols.cloud_rounded ||
      icon == Symbols.clear_night_rounded ||
      icon == Symbols.partly_cloudy_night_rounded) {
    return const Color(0xFFB9C8E4);
  }
  return const Color(0xFF6EA8FF);
}

String uvWord(AppLocalizations l, int uv) => uv >= 11
    ? l.wxUvExtreme
    : uv >= veryHighUv
    ? l.wxUvVeryHigh
    : uv >= highUv
    ? l.wxUvHigh
    : uv >= 3
    ? l.wxUvModerate
    : l.wxUvLow;

bool _isNight(WeatherHour h, DateTime? sunset) {
  final b = toBangkok(h.time).hour;
  if (sunset != null && !h.time.isBefore(sunset)) return true;
  return b >= 19 || b < 6;
}

/// While rain is falling, when it eases; null when it is not falling now.
String? _rainNow(AppLocalizations l, List<WeatherHour> ahead, WeatherHour now) {
  if (!isRaining(now) || now.rainMmPerHr < lightRain) return null;
  final dry = ahead.skip(1).where((h) => !isRaining(h)).firstOrNull;
  return dry == null ? l.wxRainNow : l.wxRainStops(hhmm(dry.time));
}

/// The day in one line: what it is like now and when rain comes.
String weatherHeadline(AppLocalizations l, Outlook o, DateTime now) {
  final ahead = hoursAhead(o, now: now);
  final current = ahead.firstOrNull ?? o.now;
  if (_rainNow(l, ahead, current) case final falling?) return falling;
  final mood = current.uvIndex >= veryHighUv
      ? l.wxSunStrong
      : current.feelsLikeC >= hotFeelsLikeC
      ? l.wxHot
      : current.conditionTh;
  final later = _rainLine(l, ahead, current);
  return mood.isEmpty ? later : '$mood · $later';
}

/// Rain falling now, else the next wet hour after this one (this hour's
/// chance is already in the stats), worded by how likely it is.
String _rainLine(AppLocalizations l, List<WeatherHour> ahead, WeatherHour now) {
  if (_rainNow(l, ahead, now) case final falling?) return falling;
  final rain = ahead.skip(1).where(isRaining).firstOrNull;
  if (rain == null) return l.wxDryAhead;
  return likelyRain(rain)
      ? l.wxRainFrom(hhmm(rain.time))
      : l.wxMaybeRainFrom(hhmm(rain.time));
}

/// Now: temperature, sky, feels-like, UV, rain chance, then the hours.
class WeatherHeroCard extends StatelessWidget {
  const WeatherHeroCard({super.key, required this.outlook, required this.now});
  final Outlook outlook;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hours = hoursAhead(outlook, now: now);
    final current = hours.firstOrNull ?? outlook.now;
    final night = _isNight(current, outlook.sunset);
    final glow = weatherGlow(current.condition, night: night);

    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tabular(
              t.titleSmall!,
            ).copyWith(color: color ?? scheme.onSurface),
          ),
        ],
      ),
    );

    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(
        Space.x5,
        Space.x5,
        Space.x5,
        Space.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.tempC.round()}°',
                      style: tabular(t.displayLarge!).copyWith(
                        fontSize: 64,
                        height: 1.05,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      current.conditionTh,
                      style: t.titleMedium!.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rainLine(l, hours, current),
                      style: t.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: .45),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Icon(
                  weatherIcon(current.condition, night: night),
                  size: 56,
                  fill: 1,
                  color: glow,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              stat(l.wxFeels, '${current.feelsLikeC.round()}°'),
              stat(
                l.wxUv,
                '${current.uvIndex} ${uvWord(l, current.uvIndex)}',
                color: current.uvIndex >= highUv
                    ? const Color(0xFFFFC34D)
                    : null,
              ),
              stat(
                l.wxRainChance,
                '${current.rainProbPct}%',
                color: isRaining(current) ? const Color(0xFF8AB4FF) : null,
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Row(
            children: [
              stat(l.wxHumidity, '${current.humidityPct}%'),
              stat(l.wxWind, l.wxWindKph('${current.windKph.round()}')),
              if (outlook.sunset case final sunset?)
                stat(l.wxSunset, hhmm(sunset))
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: Space.x4),
          Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
          const SizedBox(height: Space.x3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, h) in hours.indexed) ...[
                  if (i > 0) const SizedBox(width: Space.x1),
                  _HourCell(
                    hour: h,
                    label: i == 0 ? l.wxNow : hhmm(h.time),
                    night: _isNight(h, outlook.sunset),
                    current: i == 0,
                  ),
                ],
              ],
            ),
          ),
          if (outlook.sources.isNotEmpty) ...[
            const SizedBox(height: Space.x3),
            SourceLabel(outlook.sources.join(' · ')),
          ],
        ],
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.hour,
    required this.label,
    required this.night,
    required this.current,
  });
  final WeatherHour hour;
  final String label;
  final bool night;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final wet = isRaining(hour);
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(
        vertical: Space.x2,
        horizontal: Space.x1,
      ),
      decoration: current
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(Radii.md),
            )
          : null,
      child: Column(
        children: [
          Text(
            label,
            style: tabular(
              t.labelSmall!,
            ).copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.x1),
          Icon(
            weatherIcon(hour.condition, night: night),
            size: 22,
            fill: 1,
            color: weatherGlow(hour.condition, night: night),
          ),
          const SizedBox(height: Space.x1),
          Text(
            '${hour.tempC.round()}°',
            style: tabular(t.labelLarge!).copyWith(color: scheme.onSurface),
          ),
          Text(
            '${hour.rainProbPct}%',
            style: tabular(t.labelSmall!).copyWith(
              color: wet ? const Color(0xFF8AB4FF) : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Words, icon and accent for one thing to carry.
({IconData icon, String title, String why, Color accent}) carryLook(
  AppLocalizations l,
  CarryItem i,
) {
  final from = i.from == null ? '' : hhmm(i.from!);
  final to = i.to == null ? '' : hhmm(i.to!);
  const rain = Color(0xFF6EA8FF), sun = Color(0xFFFFB547);
  return switch (i.kind) {
    CarryKind.raincoat => (
      icon: Symbols.apparel_rounded,
      title: l.carryRaincoat,
      why: l.carryWhyHeavy(from, to),
      accent: rain,
    ),
    CarryKind.umbrella => (
      icon: Symbols.umbrella_rounded,
      title: l.carryUmbrella,
      why: l.carryWhyRain('${i.value}', from, to),
      accent: rain,
    ),
    CarryKind.spareUmbrella => (
      icon: Symbols.umbrella_rounded,
      title: l.carrySpareUmbrella,
      why: l.carryWhyMaybeRain('${i.value}', from, to),
      accent: rain,
    ),
    CarryKind.sunUmbrella => (
      icon: Symbols.beach_access_rounded,
      title: l.carrySunUmbrella,
      why: l.carryWhyShade(from, to),
      accent: sun,
    ),
    CarryKind.sunscreen => (
      icon: Symbols.sanitizer_rounded,
      title: l.carrySunscreen,
      why: l.carryWhyUv('${i.value}', from, to),
      accent: sun,
    ),
    CarryKind.water => (
      icon: Symbols.water_bottle_rounded,
      title: l.carryWater,
      why: l.carryWhyHeat('${i.value}'),
      accent: const Color(0xFF5FD4E8),
    ),
    CarryKind.shoes => (
      icon: Symbols.footprint_rounded,
      title: l.carryShoes,
      why: l.carryWhyShoes(from, to),
      accent: rain,
    ),
  };
}

/// "วันนี้ควรพก": one glass tile per item, side by side.
class CarryStrip extends StatelessWidget {
  const CarryStrip({super.key, required this.items, this.moto = false});
  final List<CarryItem> items;

  /// The raincoat is for riding, not for a downpour.
  final bool moto;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (items.isEmpty) {
      return _CarryTile(
        icon: Symbols.check_circle_rounded,
        accent: FonColors.of(context).riskLow,
        title: l.carryNothing,
        why: l.carryNothingBody,
        wide: true,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i > 0) const SizedBox(width: Space.x3),
              _tile(l, item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(AppLocalizations l, CarryItem item) {
    final look = carryLook(l, item);
    final why = item.kind == CarryKind.raincoat && moto
        ? l.carryWhyMoto(hhmm(item.from!), hhmm(item.to!))
        : look.why;
    return _CarryTile(
      key: ValueKey('carry-${item.kind.name}'),
      icon: look.icon,
      accent: look.accent,
      title: look.title,
      why: why,
    );
  }
}

class _CarryTile extends StatelessWidget {
  const _CarryTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.why,
    this.wide = false,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String why;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final badge = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: .18),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Icon(icon, color: accent, fill: 1, size: 24),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.titleMedium!.copyWith(color: scheme.onSurface)),
        const SizedBox(height: 2),
        Text(
          why,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tabular(t.bodySmall!).copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    return MergeSemantics(
      child: SizedBox(
        width: wide ? double.infinity : 152,
        child: GlassSurface(
          radius: Radii.lg,
          tint: accent,
          padding: const EdgeInsets.all(Space.x4),
          child: wide
              ? Row(
                  children: [
                    badge,
                    const SizedBox(width: Space.x3),
                    Expanded(child: text),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge,
                    const SizedBox(height: Space.x5),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// "พกไปด้วย ☂ ร่ม · 🧴 ครีมกันแดด": the trip's packing list as small pills.
class BringRow extends StatelessWidget {
  const BringRow({super.key, required this.items});
  final List<CarryItem> items;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.planBring,
          style: t.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.x2),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            for (final i in items)
              Builder(
                builder: (context) {
                  final look = carryLook(l, i);
                  return Tooltip(
                    message: look.why,
                    child: Container(
                      key: ValueKey('bring-${i.kind.name}'),
                      padding: const EdgeInsets.fromLTRB(
                        Space.x2,
                        Space.x1,
                        Space.x3,
                        Space.x1,
                      ),
                      decoration: BoxDecoration(
                        color: look.accent.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(
                          color: look.accent.withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            look.icon,
                            size: 18,
                            fill: 1,
                            color: look.accent,
                          ),
                          const SizedBox(width: Space.x1),
                          Flexible(
                            child: Text(
                              look.title,
                              style: t.labelLarge!.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// A small weather tag for one moment: icon plus rain chance or temperature.
class WeatherTag extends StatelessWidget {
  const WeatherTag({super.key, required this.hour, this.night = false});
  final WeatherHour hour;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final wet = isRaining(hour);
    final glow = weatherGlow(hour.condition, night: night);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          weatherIcon(hour.condition, night: night),
          size: 16,
          fill: 1,
          color: glow,
        ),
        const SizedBox(width: Space.x1),
        Flexible(
          child: Text(
            wet
                ? l.planRainAt('${hour.rainProbPct}')
                : '${hour.tempC.round()}°',
            style: tabular(
              t.labelMedium!,
            ).copyWith(color: wet ? const Color(0xFF8AB4FF) : glow),
          ),
        ),
      ],
    );
  }
}

/// Weather, kept small: one line now, the full card on tap.
class WeatherPeek extends StatelessWidget {
  const WeatherPeek({super.key, required this.outlook, required this.now});
  final Outlook outlook;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final current = hoursAhead(outlook, now: now).firstOrNull ?? outlook.now;
    final night = _isNight(current, outlook.sunset);
    return GlassSurface(
      radius: Radii.lg,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            useSafeArea: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.x8,
              ),
              child: WeatherHeroCard(outlook: outlook, now: now),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              children: [
                Icon(
                  weatherIcon(current.condition, night: night),
                  fill: 1,
                  color: weatherGlow(current.condition, night: night),
                ),
                const SizedBox(width: Space.x3),
                Text(
                  '${current.tempC.round()}°',
                  style: tabular(t.titleMedium!),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Text(
                    weatherHeadline(l, outlook, now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
        ),
      ),
    );
  }
}
