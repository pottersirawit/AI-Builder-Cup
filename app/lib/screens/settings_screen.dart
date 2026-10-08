import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
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
    final state = AppScope.stateOf(context);
    final store = AppScope.placesOf(context);
    final api = AppScope.apiOf(context);
    final locator = AppScope.locatorOf(context);
    final sky = state.flood ? SkyState.flood : SkyState.clear;

    Widget toggle(String id, IconData icon, String title, String subtitle, {bool enabled = true}) =>
        SwitchListTile(
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
                child: FieldHeader(state: sky, back: true, title: 'ตั้งค่า', subtitle: 'เก็บไว้ในเครื่องนี้เท่านั้น'),
              ),
            ),
          ),
          SliverList.list(children: [
            if (state.notificationsDenied)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
                child: Notice(
                  icon: Symbols.notifications_off_rounded,
                  tone: NoticeTone.warning,
                  text: 'ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้',
                  action: TextButton(onPressed: locator.openAppSettings, child: const Text('เปิดการตั้งค่า')),
                ),
              ),
            _Group('สถานที่ของฉัน', source: 'เก็บไว้ในเครื่องนี้เท่านั้น · ส่งพิกัดไปกับคำถามตอนถาม'),
            _PlaceTile(kind: PlaceKind.home, place: store.home),
            _PlaceTile(kind: PlaceKind.work, place: store.work),
            if (store.workFromHome)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x1),
                child: Notice(icon: Symbols.home_work_rounded, text: 'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น'),
              ),
            for (final p in store.others) _PlaceTile(kind: PlaceKind.other, place: p),
            ListTile(
              key: const ValueKey('add-place'),
              enabled: store.canAddOther,
              leading: const Icon(Symbols.add_location_alt_rounded),
              title: const Text('เพิ่มสถานที่'),
              subtitle: Text(store.canAddOther
                  ? 'ยิม โรงเรียนลูก บ้านพ่อแม่ · ${store.others.length} จาก ${PlacesStore.maxOthers}'
                  : 'ครบ ${PlacesStore.maxOthers} แห่งแล้ว ลบที่เดิมก่อนจึงเพิ่มได้'),
              onTap: () => pickPlace(context, kind: PlaceKind.other),
            ),
            const _Group('การเดินทาง'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: ModeSegmented(selected: state.mode, onChanged: (m) => state.mode = m),
            ),
            const SizedBox(height: Space.x2),
            const ListTile(
              leading: Icon(Symbols.notifications_rounded),
              title: Text('เตือนล่วงหน้า'),
              subtitle: Text('2 ชั่วโมงก่อนเวลาที่ควรออก'),
            ),
            const _Group('ให้แอปหาทริปให้เอง', source: 'ปิดได้ทีละอย่าง ถามเองยังใช้ได้เสมอ'),
            ConnectRow(
              icon: Symbols.calendar_month_rounded,
              title: 'Google Calendar',
              state: store.calendar,
              detail: 'เฉพาะนัดที่มีสถานที่',
              account: '${store.calendarAccount} · บัญชีจำลอง',
              comingSoon: !store.canConnectCalendar,
              onConnect: store.connectCalendar,
              onDisconnect: store.disconnectCalendar,
            ),
            toggle('gmail', Symbols.mail_rounded, 'Gmail', 'เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล'),
            toggle('routine', Symbols.repeat_rounded, 'เรียนรู้กิจวัตร', 'รู้เองว่ากลับบ้านราวหกโมงทุกวัน · เร็ว ๆ นี้',
                enabled: false),
            const _Group('ชุมชนและน้ำท่วม'),
            toggle('share_reports', Symbols.photo_camera_rounded, 'แชร์รายงานน้ำท่วมของฉัน',
                'ไม่ระบุตัว เฉพาะตำแหน่งและระดับน้ำ'),
            toggle('home_alerts', Symbols.home_rounded, 'เตือนน้ำท่วมที่บ้าน', 'แม้ไม่ได้เปิดแอป'),
            toggle('sms_backup', Symbols.sms_rounded, 'สำรองทาง SMS', 'เมื่อไม่มีอินเทอร์เน็ต'),
            const _Group('โปรไฟล์'),
            if (store.demoProfile)
              ListTile(
                leading: const Icon(Symbols.logout_rounded),
                title: const Text('ออกจากโปรไฟล์เดโม'),
                subtitle: const Text('ลบสถานที่ของมิวและกลับไปหน้าเริ่มต้น'),
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.resetToFirstRun();
                },
              )
            else
              ListTile(
                leading: const Icon(Symbols.person_play_rounded),
                title: const Text('ใช้โปรไฟล์เดโม (มิว)'),
                subtitle: const Text('สถานที่และนัดจำลองของมิว สำหรับสาธิต'),
                onTap: store.useDemoProfile,
              ),
            const _Group('สำหรับทีม'),
            ListTile(
              leading: const Icon(Symbols.palette_rounded),
              title: const Text('ระบบดีไซน์'),
              subtitle: const Text('สี ตัวอักษร ระยะ และคอมโพเนนต์ทุกสถานะท้องฟ้า'),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const GalleryScreen())),
            ),
            ListTile(
              leading: const Icon(Symbols.schedule_rounded),
              title: const Text('เวลาสาธิต'),
              subtitle: Text(state.demoClock == null ? 'เวลาจริง' : 'อังคาร 29 ก.ย. ${hhmm(state.now())}'),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => showDemoClockPicker(context),
            ),
            ListTile(
              leading: const Icon(Symbols.dns_rounded),
              title: const Text('เซิร์ฟเวอร์'),
              subtitle: Text(api.baseUrl),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x10),
              child: SourceLabel('ชื่อ “มิว” ตัวเลขผู้ใช้ และรายงานชุมชนในแอปนี้เป็นข้อมูลจำลองสำหรับเดโม'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, {this.source});
  final String title;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x8, Space.gutter, Space.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleMedium!.copyWith(color: Theme.of(context).colorScheme.primary)),
          if (source != null) ...[const SizedBox(height: Space.x1), SourceLabel(source!)],
        ],
      ),
    );
  }
}

/// One saved place, or the empty slot for home/work with why to set it.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.kind, required this.place});
  final PlaceKind kind;
  final SavedPlace? place;

  @override
  Widget build(BuildContext context) {
    final p = place;
    if (p == null) {
      final home = kind == PlaceKind.home;
      return ListTile(
        leading: Icon(home ? Symbols.home_rounded : Symbols.work_rounded),
        title: Text(home ? 'ตั้งบ้าน' : 'ตั้งที่ทำงาน'),
        subtitle: Text(home ? 'ให้แอปเตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน' : 'ให้เตือนตอนเลิกงานได้แม่นขึ้น'),
        trailing: const Icon(Symbols.add_rounded),
        onTap: () => pickPlace(context, kind: kind),
      );
    }
    final detail = p.kind == PlaceKind.work ? ' · ${workDaysLabel(p.days)} ออก ${p.leaveTime}' : '';
    return ListTile(
      leading: Icon(placeIcon(p.icon)),
      title: Text(p.labelTh),
      subtitle: Text('${p.nameTh}$detail', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: p.inArea
          ? const Icon(Symbols.chevron_right_rounded)
          : const RiskChip(risk: Risk.medium, label: 'นอกพื้นที่ที่รองรับ', dense: true),
      onTap: () => editPlace(context, p),
    );
  }
}
