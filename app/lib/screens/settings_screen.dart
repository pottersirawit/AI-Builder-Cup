import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../time_th.dart';
import 'gallery_screen.dart';
import 'parts.dart';

/// Settings are local-only for now; nothing here is sent to the backend.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final api = AppScope.apiOf(context);
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
            const _Group('สถานที่ของฉัน', source: 'Google Maps สถานที่ที่บันทึกไว้ · แก้เองได้'),
            const ListTile(
              leading: Icon(Symbols.home_rounded),
              title: Text('บ้าน'),
              subtitle: Text('ซอยลาดพร้าว 32 · ใกล้คลองลาดพร้าว'),
            ),
            const ListTile(
              leading: Icon(Symbols.work_rounded),
              title: Text('ที่ทำงาน'),
              subtitle: Text('สีลม ซอย 3 · จันทร์ถึงศุกร์'),
            ),
            const ListTile(
              leading: Icon(Symbols.bookmark_rounded),
              title: Text('ไปบ่อย'),
              subtitle: Text('สยาม · ทองหล่อ · อิมแพ็ค'),
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
            toggle('calendar', Symbols.calendar_month_rounded, 'Google Calendar', 'เฉพาะนัดที่มีสถานที่'),
            toggle('gmail', Symbols.mail_rounded, 'Gmail', 'เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล'),
            toggle('routine', Symbols.repeat_rounded, 'เรียนรู้กิจวัตร', 'รู้เองว่ากลับบ้านราวหกโมงทุกวัน · เร็ว ๆ นี้',
                enabled: false),
            const _Group('ชุมชนและน้ำท่วม'),
            toggle('share_reports', Symbols.photo_camera_rounded, 'แชร์รายงานน้ำท่วมของฉัน',
                'ไม่ระบุตัว เฉพาะตำแหน่งและระดับน้ำ'),
            toggle('home_alerts', Symbols.home_rounded, 'เตือนน้ำท่วมที่บ้าน', 'แม้ไม่ได้เปิดแอป'),
            toggle('sms_backup', Symbols.sms_rounded, 'สำรองทาง SMS', 'เมื่อไม่มีอินเทอร์เน็ต'),
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
              child: SourceLabel('ชื่อ “พลอย” ตัวเลขผู้ใช้ และรายงานชุมชนในแอปนี้เป็นข้อมูลจำลองสำหรับเดโม'),
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
