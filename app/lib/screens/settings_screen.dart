import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import '../time_th.dart';
import 'gallery_screen.dart';
import 'parts.dart';
import 'place_picker.dart';

enum OAuthService { calendar, gmail }

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
                comingSoon: false,
                onConnect: () => _promptOAuth(
                  context,
                  service: OAuthService.calendar,
                  store: store,
                ),
                onDisconnect: store.disconnectCalendar,
              ),
              ConnectRow(
                icon: Symbols.mail_rounded,
                title: 'Gmail',
                state: store.gmail,
                detail: l.settingsGmailHint,
                account: l.settingsCalendarAccount(store.gmailAccount),
                comingSoon: false,
                onConnect: () => _promptOAuth(
                  context,
                  service: OAuthService.gmail,
                  store: store,
                ),
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

Future<void> _promptOAuth(
  BuildContext context, {
  required OAuthService service,
  required PlacesStore store,
}) async {
  final isCalendar = service == OAuthService.calendar;
  final title = isCalendar ? 'Google Calendar' : 'Gmail';
  final scope = isCalendar
      ? 'https://www.googleapis.com/auth/calendar.readonly'
      : 'https://www.googleapis.com/auth/gmail.readonly';
  final scopeShort = isCalendar ? 'calendar.readonly' : 'gmail.readonly';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;
      final isThai = Localizations.localeOf(ctx).languageCode == 'th';

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x4,
            Space.gutter,
            Space.x6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Space.x4),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(Space.x2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCalendar
                          ? Symbols.calendar_month_rounded
                          : Symbols.mail_rounded,
                      color: scheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai ? 'ขอสิทธิ์เข้าถึง $title' : 'Connect $title',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Google Account Integration',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              Container(
                padding: const EdgeInsets.all(Space.x3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.verified_user_rounded,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: Space.x2),
                        Text(
                          isThai
                              ? 'ข้อมูลที่ขอเข้าถึง ($scopeShort)'
                              : 'Requested Scope ($scopeShort)',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      isCalendar
                          ? (isThai
                              ? '• อ่านเฉพาะวัน เวลา และพิกัดสถานที่ของนัดหมาย\n• ใช้เพื่อคำนวณความเสี่ยงฝนตกและน้ำท่วมล่วงหน้า\n• อ่านอย่างเดียว (Read-only) ไม่มีการเขียนหรือลบข้อมูล'
                              : '• Read-only access to upcoming event times and locations\n• Used to evaluate route flood risks before departure\n• Never modifies or deletes your calendar entries')
                          : (isThai
                              ? '• ค้นหาเฉพาะอีเมลยืนยันตั๋วหรือนัดหมายการเดินทาง\n• นำพิกัดมาสร้างทริปแนะนำการเดินทางล่วงหน้า\n• ไม่อ่านและไม่บันทึกเนื้อหาอีเมลส่วนตัว'
                              : '• Searches only for travel and event ticket confirmations\n• Generates proactive route advisories for destinations\n• Never accesses personal emails or private messages'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x2,
                        vertical: Space.x1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isThai
                            ? '🛡️ ปฏิบัติตาม Google Limited Use Policy — ประมวลผลในหน่วยความจำ ไม่เก็บถาวรบนเซิร์ฟเวอร์'
                            : '🛡️ Google Limited Use compliant — Processed in-memory, never stored on servers',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x5),
              FilledButton.icon(
                icon: const Icon(Symbols.login_rounded),
                label: Text(
                  isThai
                      ? 'ดำเนินการต่อด้วย Google (Sign in)'
                      : 'Sign in with Google',
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final authUrl = Uri.parse(
                    'https://accounts.google.com/o/oauth2/v2/auth'
                    '?client_id=945826169258-2npe55rhvgjl26a8mgfod4s9js5bbgpo.apps.googleusercontent.com'
                    '&redirect_uri=https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback'
                    '&response_type=code'
                    '&scope=${Uri.encodeComponent(scope)}'
                    '&access_type=offline',
                  );
                  try {
                    await launchUrl(
                      authUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}

                  if (isCalendar) {
                    await store.connectCalendar(allowLive: true);
                  } else {
                    await store.connectGmail();
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Symbols.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: Space.x2),
                            Text(
                              isThai
                                  ? 'เชื่อมต่อ $title สำเร็จ'
                                  : '$title connected',
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: Space.x2),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
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
