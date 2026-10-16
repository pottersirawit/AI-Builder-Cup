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
                account: _accountLabel(l, store, store.calendarAccount),
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
                account: _accountLabel(l, store, store.gmailAccount),
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

String _accountLabel(AppLocalizations l, PlacesStore store, String account) {
  if (store.demoProfile && account.contains('demo')) {
    return l.settingsCalendarAccount(account);
  }
  return '$account · ${l.placesConnected}';
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

  final defaultEmail = isCalendar
      ? (store.calendarAccount.contains('demo')
          ? 'the32069@gmail.com'
          : store.calendarAccount)
      : (store.gmailAccount.contains('demo')
          ? 'the32069@gmail.com'
          : store.gmailAccount);
  final emailController = TextEditingController(text: defaultEmail);

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
          padding: EdgeInsets.only(
            left: Space.gutter,
            right: Space.gutter,
            top: Space.x4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Space.x6,
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
                          isThai ? 'เชื่อมต่อ $title' : 'Connect $title',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isThai
                              ? 'เพื่อตรวจสอบสภาพอากาศและเส้นทางล่วงหน้า'
                              : 'Proactive weather & commute intelligence',
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
                  borderRadius: BorderRadius.circular(16),
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
                              ? 'สิทธิ์การใช้งานและความเป็นส่วนตัว'
                              : 'Privacy & Security Reassurance',
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
                              ? '• ตรวจสอบวัน เวลา และสถานที่นัดหมาย เพื่อคำนวณความเสี่ยงฝนตกและน้ำท่วมล่วงหน้า\n• ปลอดภัยและเป็นส่วนตัว: ดูเฉพาะกำหนดการเดินทาง ไม่มีการแก้ไขหรือลบข้อมูลในปฏิทิน\n• ประมวลผลบนเครื่องของคุณเพื่อวางแผนเส้นทาง ไม่เก็บข้อมูลส่วนตัวบนเซิร์ฟเวอร์'
                              : '• Checks upcoming event times and locations to calculate rain and flood risk before departure\n• Private and secure: Only reads travel schedules, never modifies or deletes your events\n• Processed on your device for route planning, never permanently stored on servers')
                          : (isThai
                              ? '• ตรวจสอบอีเมลยืนยันการจองตั๋วหรือนัดหมาย เพื่อแนะนำการเดินทางล่วงหน้าอัตโนมัติ\n• ปลอดภัยและเป็นส่วนตัว: ค้นหาเฉพาะข้อมูลการเดินทาง ไม่อ่านอีเมลส่วนตัวอื่น ๆ\n• ประมวลผลบนเครื่องของคุณเพื่อวางแผนเส้นทาง ไม่เก็บข้อมูลส่วนตัวบนเซิร์ฟเวอร์'
                              : '• Checks travel or booking confirmations to proactively suggest safe transit routes\n• Private and secure: Only searches travel details, never reads your personal messages\n• Processed on your device for route planning, never permanently stored on servers'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x4),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.account_circle_rounded),
                  labelText: isThai ? 'บัญชี Google' : 'Google Account',
                  hintText: 'user@gmail.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.x3,
                    vertical: Space.x2,
                  ),
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
                  final email = emailController.text.trim();
                  final selectedEmail = email.isNotEmpty ? email : defaultEmail;
                  Navigator.of(ctx).pop();
                  final authUrl = Uri.parse(
                    'https://accounts.google.com/o/oauth2/v2/auth'
                    '?client_id=945826169258-2npe55rhvgjl26a8mgfod4s9js5bbgpo.apps.googleusercontent.com'
                    '&redirect_uri=https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback'
                    '&response_type=code'
                    '&scope=${Uri.encodeComponent(scope)}'
                    '&state=${Uri.encodeComponent(selectedEmail)}'
                    '&access_type=offline',
                  );
                  try {
                    await launchUrl(
                      authUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}

                  if (isCalendar) {
                    await store.connectCalendar(
                      allowLive: true,
                      email: selectedEmail,
                    );
                  } else {
                    await store.connectGmail(
                      email: selectedEmail,
                    );
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
                            Expanded(
                              child: Text(
                                isThai
                                    ? 'เชื่อมต่อ $title สำหรับ $selectedEmail เรียบร้อยแล้ว'
                                    : '$title connected for $selectedEmail',
                              ),
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
