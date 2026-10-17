import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../google_link.dart';
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
                account: _accountLabel(l, store, store.calendarAccount),
                comingSoon: false,
                onConnect: () => promptOAuth(context),
                onDisconnect: store.disconnectCalendar,
              ),
              ConnectRow(
                icon: Symbols.mail_rounded,
                title: 'Gmail',
                state: store.gmail,
                detail: l.settingsGmailHint,
                account: _accountLabel(l, store, store.gmailAccount),
                comingSoon: false,
                onConnect: () => promptOAuth(context),
                onDisconnect: store.disconnectGmail,
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

String? _accountLabel(AppLocalizations l, PlacesStore store, String? account) {
  if (account == null) return null;
  if (store.demoProfile && account.contains('demo')) {
    return l.settingsCalendarAccount(account);
  }
  return '$account · ${l.placesConnected}';
}

/// One sheet connects Google Calendar and Gmail: it says what the app reads,
/// opens Google, and waits until the server confirms the account. มิว's demo
/// profile connects without Google.
Future<void> promptOAuth(BuildContext context) async {
  final store = AppScope.readPlaces(context);
  final link = AppScope.linkOf(context);
  final email = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoogleSheet(store: store, link: link),
  );
  if (email == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.l10n.settingsGoogleConnected(email)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _GoogleSheet extends StatefulWidget {
  const _GoogleSheet({required this.store, required this.link});
  final PlacesStore store;
  final GoogleLink? link;

  @override
  State<_GoogleSheet> createState() => _GoogleSheetState();
}

class _GoogleSheetState extends State<_GoogleSheet> {
  PlacesStore get store => widget.store;
  GoogleLink? get link => widget.link;

  // Calendar can already be connected when only Gmail is being reconnected,
  // so the sheet closes only on a sign-in it started itself.
  bool _signingIn = false;

  void _signIn() {
    _signingIn = true;
    if (store.demoProfile || link == null) {
      store
        ..connectCalendar()
        ..connectGmail();
    } else {
      link!.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final waiting =
            store.calendar == LinkState.connecting ||
            store.gmail == LinkState.connecting;
        final failed =
            store.calendar == LinkState.error || store.gmail == LinkState.error;
        final account = store.calendarAccount;
        if (_signingIn &&
            store.calendar == LinkState.connected &&
            store.gmail == LinkState.connected &&
            account != null) {
          _signingIn = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop(account);
          });
        }
        Widget use(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  text,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.settingsGoogleTitle, style: t.titleLarge),
                const SizedBox(height: Space.x1),
                Text(
                  l.settingsGoogleSubtitle,
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Space.x4),
                Text(l.settingsGoogleUseTitle, style: t.labelLarge),
                const SizedBox(height: Space.x2),
                use(
                  Symbols.calendar_month_rounded,
                  l.settingsGoogleCalendarUse,
                ),
                use(Symbols.mail_rounded, l.settingsGoogleGmailUse),
                use(Symbols.verified_user_rounded, l.settingsGooglePrivacy),
                const SizedBox(height: Space.x4),
                if (waiting) ...[
                  Row(
                    key: const ValueKey('google-waiting'),
                    children: [
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.settingsGoogleWaiting, style: t.titleSmall),
                            Text(
                              l.settingsGoogleWaitingHint,
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x3),
                  TextButton(
                    onPressed: () {
                      link?.cancel();
                      Navigator.of(context).pop();
                    },
                    child: Text(l.settingsGoogleCancel),
                  ),
                ] else ...[
                  if (failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x3),
                      child: Text(
                        l.settingsGoogleFailed,
                        style: t.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('google-sign-in'),
                    icon: const Icon(Symbols.login_rounded),
                    label: Text(l.settingsGoogleSignIn),
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: Space.x2),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.settingsGoogleCancel),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
