import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import 'place_picker.dart';

/// First launch: one optional screen whose only job is getting home (and
/// work) saved so the app can warn about the trip home. Everything works
/// without it.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.placesOf(context);
    final sky = FonColors.of(context).sky(SkyState.clear);
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final l = context.l10n;

    return Scaffold(
      body: SkyField(
        state: SkyState.clear,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x8,
                    Space.gutter,
                    Space.x4,
                  ),
                  children: [
                    Row(
                      children: [
                        Icon(
                          Symbols.rainy_rounded,
                          fill: 1,
                          color: sky.onField,
                          size: 22,
                        ),
                        const SizedBox(width: Space.x2),
                        Text(
                          l.onboardingAppName,
                          style: t.titleMedium!.copyWith(color: sky.onField),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x6),
                    Text(
                      l.onboardingHeadline,
                      style: t.displaySmall!.copyWith(color: sky.onField),
                    ),
                    const SizedBox(height: Space.x3),
                    Text(
                      l.onboardingIntro,
                      style: t.bodyLarge!.copyWith(color: sky.onFieldMuted),
                    ),
                    const SizedBox(height: Space.x6),
                    Pass(
                      sections: [
                        _PlaceSlot(kind: PlaceKind.home, place: store.home),
                        _PlaceSlot(kind: PlaceKind.work, place: store.work),
                        PassSection(
                          child: SourceLabel(
                            l.onboardingSkipNote,
                            icon: Symbols.lock_rounded,
                            color: c.paperMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x2,
                  Space.gutter,
                  Space.x2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.paper,
                        foregroundColor: c.paperInk,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: store.completeOnboarding,
                      child: Text(l.onboardingStart),
                    ),
                    const SizedBox(height: Space.x1),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: sky.onField,
                          ),
                          onPressed: store.completeOnboarding,
                          child: Text(l.onboardingSkip),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: sky.onFieldMuted,
                          ),
                          onPressed: store.useDemoProfile,
                          child: Text(l.onboardingDemo),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the onboarding pass: บ้าน or ที่ทำงาน, with both ways to set it.
class _PlaceSlot extends StatelessWidget {
  const _PlaceSlot({required this.kind, required this.place});
  final PlaceKind kind;
  final SavedPlace? place;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final p = place;
    final home = kind == PlaceKind.home;
    return PassSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                home ? Symbols.home_rounded : Symbols.work_rounded,
                size: 22,
                color: c.paperInk,
                fill: p == null ? 0 : 1,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  kindLabel(l, kind),
                  style: t.titleMedium!.copyWith(color: c.paperInk),
                ),
              ),
              if (p != null)
                RiskChip(risk: Risk.low, label: l.onboardingSet, dense: true),
            ],
          ),
          const SizedBox(height: Space.x1),
          Text(
            p == null
                ? (home ? l.onboardingHomeHint : l.onboardingWorkHint)
                : (p.kind == PlaceKind.work
                      ? l.onboardingWorkSummary(
                          p.nameTh,
                          workDaysText(l, p.days),
                          p.leaveTime,
                        )
                      : p.nameTh),
            style: (p == null ? t.bodySmall : t.bodyMedium)!.copyWith(
              color: p == null ? c.paperMuted : c.paperInk,
            ),
          ),
          const SizedBox(height: Space.x3),
          if (p == null)
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      pickPlace(context, kind: kind, locateNow: true),
                  icon: const Icon(Symbols.my_location_rounded),
                  label: Text(l.onboardingUseHere),
                ),
                OutlinedButton.icon(
                  onPressed: () => pickPlace(context, kind: kind),
                  icon: const Icon(Symbols.search_rounded),
                  label: Text(l.onboardingSearch),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () => editPlace(context, p),
              icon: const Icon(Symbols.edit_rounded),
              label: Text(l.onboardingEdit),
            ),
        ],
      ),
    );
  }
}
