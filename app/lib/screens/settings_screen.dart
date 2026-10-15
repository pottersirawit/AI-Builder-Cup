import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import '../time_th.dart';
import 'gallery_screen.dart';
import 'parts.dart';
import 'place_picker.dart';

/// Settings are local-only; saved places travel only as coordinates inside
/// each request.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final locator = AppScope.locatorOf(context);
    final sky = state.flood ? SkyState.flood : SkyState.clear;

    Widget toggle(
      String id,
      IconData icon,
      String title,
      String subtitle, {
      bool enabled = true,
    }) => SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: state.toggles[id]!,
      onChanged: enabled ? (v) => state.setToggle(id, v) : null,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SkyField(
              state: sky,
              height: double.infinity,
              child: SafeArea(
                bottom: false,
                child: FieldHeader(
                  state: sky,
                  back: true,
                  title: l.settingsTitle,
                  subtitle: l.settingsSubtitle,
                ),
              ),
            ),
          ),
          SliverList.list(
            children: [
              if (state.notificationsDenied)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x4,
                    Space.gutter,
                    0,
                  ),
                  child: Notice(
                    icon: Symbols.notifications_off_rounded,
                    tone: NoticeTone.warning,
                    text: l.settingsNotificationsOff,
                    action: TextButton(
                      onPressed: locator.openAppSettings,
                      child: Text(l.settingsOpenSettings),
                    ),
                  ),
                ),
              _Group(l.settingsLanguage),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: SegmentedButton<Locale>(
                  key: const ValueKey('language'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: const Locale('th'),
                      label: Text(l.settingsLanguageThai),
                    ),
                    ButtonSegment(
                      value: const Locale('en'),
                      label: Text(l.settingsLanguageEnglish),
                    ),
                  ],
                  selected: {state.locale},
                  onSelectionChanged: (v) => state.locale = v.first,
                ),
              ),
              _Group(l.settingsMyPlaces),
              _PlaceTile(kind: PlaceKind.home, place: store.home),
              _PlaceTile(kind: PlaceKind.work, place: store.work),
              if (store.workFromHome)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.gutter,
                    vertical: Space.x1,
                  ),
                  child: Notice(
                    icon: Symbols.home_work_rounded,
                    text: l.settingsWfh,
                  ),
                ),
              for (final p in store.others)
                _PlaceTile(kind: PlaceKind.other, place: p),
              ListTile(
                key: const ValueKey('add-place'),
                enabled: store.canAddOther,
                leading: const Icon(Symbols.add_location_alt_rounded),
                title: Text(l.settingsAddPlace),
                subtitle: Text(
                  store.canAddOther
                      ? l.settingsAddPlaceHint(
                          store.others.length,
                          PlacesStore.maxOthers,
                        )
                      : l.settingsAddPlaceFull(PlacesStore.maxOthers),
                ),
                onTap: () => pickPlace(context, kind: PlaceKind.other),
              ),
              _Group(l.settingsTravelGroup),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: ModeSegmented(
                  selected: state.mode,
                  onChanged: (m) => state.mode = m,
                ),
              ),
              const SizedBox(height: Space.x2),
              ListTile(
                leading: const Icon(Symbols.notifications_rounded),
                title: Text(l.settingsRemindAhead),
                subtitle: Text(l.settingsRemindAheadHint),
              ),
              _Group(l.settingsAutoGroup),
              ConnectRow(
                icon: Symbols.calendar_month_rounded,
                title: 'Google Calendar',
                state: store.calendar,
                detail: l.settingsCalendarDetail,
                account: l.settingsCalendarAccount(store.calendarAccount),
                comingSoon: !store.canConnectCalendar,
                onConnect: store.connectCalendar,
                onDisconnect: store.disconnectCalendar,
              ),
              toggle(
                'gmail',
                Symbols.mail_rounded,
                'Gmail',
                l.settingsGmailHint,
              ),
              toggle(
                'routine',
                Symbols.repeat_rounded,
                l.settingsRoutine,
                l.settingsRoutineHint,
                enabled: false,
              ),
              _Group(l.settingsCommunityGroup),
              toggle(
                'share_reports',
                Symbols.photo_camera_rounded,
                l.settingsShareReports,
                l.settingsShareReportsHint,
              ),
              toggle(
                'home_alerts',
                Symbols.home_rounded,
                l.settingsHomeAlerts,
                l.settingsHomeAlertsHint,
              ),
              toggle(
                'sms_backup',
                Symbols.sms_rounded,
                l.settingsSmsBackup,
                l.settingsSmsBackupHint,
              ),
              _Group(l.settingsProfileGroup),
              if (store.demoProfile)
                ListTile(
                  leading: const Icon(Symbols.logout_rounded),
                  title: Text(l.settingsExitDemo),
                  subtitle: Text(l.settingsExitDemoHint),
                  onTap: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    store.resetToFirstRun();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Symbols.person_play_rounded),
                  title: Text(l.settingsUseDemo),
                  subtitle: Text(l.settingsUseDemoHint),
                  onTap: store.useDemoProfile,
                ),
              _Group(l.settingsTeamGroup),
              ListTile(
                leading: const Icon(Symbols.palette_rounded),
                title: Text(l.settingsDesignSystem),
                subtitle: Text(l.settingsDesignSystemHint),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GalleryScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Symbols.schedule_rounded),
                title: Text(l.settingsDemoClock),
                subtitle: Text(
                  state.demoClock == null
                      ? l.settingsRealTime
                      : dayTime(l, state.now()),
                ),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => showDemoClockPicker(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x4,
                  Space.gutter,
                  Space.x10,
                ),
                child: SourceLabel(l.settingsDemoNote),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x8,
        Space.gutter,
        Space.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.titleMedium!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A saved place still carrying the default Thai word for its kind reads in
/// the current language; names the person typed show as typed.
String _placeText(AppLocalizations l, String text) => switch (text) {
  'บ้าน' => l.settingsPlaceHome,
  'ที่ทำงาน' => l.settingsPlaceWork,
  'สยาม' => l.settingsPlaceSiam,
  'ทองหล่อ' => l.settingsPlaceThonglor,
  'อิมแพ็ค' => l.settingsPlaceImpact,
  _ => text,
};

/// One saved place, or the empty slot for home/work with why to set it.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.kind, required this.place});
  final PlaceKind kind;
  final SavedPlace? place;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = place;
    if (p == null) {
      final home = kind == PlaceKind.home;
      return ListTile(
        leading: Icon(home ? Symbols.home_rounded : Symbols.work_rounded),
        title: Text(home ? l.settingsSetHome : l.settingsSetWork),
        subtitle: Text(home ? l.settingsSetHomeHint : l.settingsSetWorkHint),
        trailing: const Icon(Symbols.add_rounded),
        onTap: () => pickPlace(context, kind: kind),
      );
    }
    final detail = p.kind == PlaceKind.work
        ? l.settingsWorkDetail(workDaysText(l, p.days), p.leaveTime)
        : '';
    return ListTile(
      leading: Icon(placeIcon(p.icon)),
      title: Text(p.labelFor(l)),
      subtitle: Text(
        '${_placeText(l, p.nameTh)}$detail',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: p.inArea
          ? const Icon(Symbols.chevron_right_rounded)
          : RiskChip(
              risk: Risk.medium,
              label: l.settingsOutOfArea,
              dense: true,
            ),
      onTap: () => editPlace(context, p),
    );
  }
}
