import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../time_th.dart';
import '../widgets/common.dart';

/// Settings are local-only for now; nothing here is sent to the backend.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final api = AppScope.apiOf(context);
    return SubScreen(
      title: 'ตั้งค่า',
      children: [
        const _Section('สถานที่ของฉัน'),
        const AppCard(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              _Row(icon: '🏠', title: 'บ้าน', subtitle: 'ซอยลาดพร้าว 32 · ใกล้คลองลาดพร้าว', trailing: _Edit('แก้')),
              _Row(icon: '🏢', title: 'ที่ทำงาน', subtitle: 'สีลม ซอย 3 · จันทร์ถึงศุกร์', trailing: _Edit('แก้')),
              _Row(icon: '📍', title: 'ไปบ่อย', subtitle: 'สยาม · ทองหล่อ · อิมแพ็ค', trailing: _Edit('+ เพิ่ม')),
              SourceLabel('Google Maps สถานที่ที่บันทึกไว้ · แก้เองได้'),
            ],
          ),
        ),
        const _Section('การเดินทาง'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('วิธีเดินทางประจำ', style: txt(context, size: 13, color: Palette.of(context).muted)),
              const SizedBox(height: 8),
              ModeToggle(selected: state.mode, onChanged: (m) => state.mode = m),
              const _Row(
                title: 'เตือนล่วงหน้า',
                subtitle: 'ก่อนเวลาที่ควรออกเดินทาง',
                trailing: Pill('2 ชั่วโมง'),
                last: true,
              ),
            ],
          ),
        ),
        const _Section('ให้แอปหาทริปให้เอง'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              _ToggleRow(state: state, id: 'calendar', icon: '📅', title: 'Google Calendar', subtitle: 'เฉพาะนัดที่มีสถานที่'),
              _ToggleRow(
                state: state,
                id: 'gmail',
                icon: '✉️',
                title: 'Gmail',
                subtitle: 'เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล',
              ),
              _ToggleRow(
                state: state,
                id: 'routine',
                icon: '🔁',
                title: 'เรียนรู้กิจวัตร',
                subtitle: 'รู้เองว่ากลับบ้านราวหกโมงทุกวัน · เร็ว ๆ นี้',
                enabled: false,
              ),
              const SourceLabel('ปิดได้ทีละอย่าง ถามเองยังใช้ได้เสมอ'),
            ],
          ),
        ),
        const _Section('ชุมชนและน้ำท่วม'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              _ToggleRow(
                state: state,
                id: 'share_reports',
                icon: '📷',
                title: 'แชร์รายงานน้ำท่วมของฉัน',
                subtitle: 'ไม่ระบุตัว เฉพาะตำแหน่งและระดับน้ำ',
              ),
              _ToggleRow(state: state, id: 'home_alerts', icon: '🏠', title: 'เตือนน้ำท่วมที่บ้าน', subtitle: 'แม้ไม่ได้เปิดแอป'),
              _ToggleRow(state: state, id: 'sms_backup', icon: '📶', title: 'สำรองทาง SMS', subtitle: 'เมื่อไม่มีอินเทอร์เน็ต'),
            ],
          ),
        ),
        const _Section('สำหรับทีมสาธิต'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              _Row(icon: '🛰', title: 'เซิร์ฟเวอร์', subtitle: api.baseUrl),
              _Row(
                icon: '⏱',
                title: 'เวลาสาธิต',
                subtitle: state.demoClock == null ? 'เวลาจริง' : '29 ก.ย. ${hhmm(state.now())} (กดค้างที่นาฬิกาด้านบนเพื่อเปลี่ยน)',
                trailing: TextButton(onPressed: () => showDemoClockPicker(context), child: const Text('เปลี่ยน')),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 16), child: Eyebrow(text));
}

class _Edit extends StatelessWidget {
  const _Edit(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: txt(context, size: 13, weight: FontWeight.w600, color: Palette.of(context).accent));
}

class _Row extends StatelessWidget {
  const _Row({this.icon, required this.title, required this.subtitle, this.trailing, this.last = false});
  final String? icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.bg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(icon!),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: txt(context, weight: FontWeight.w600)),
                Text(subtitle, style: txt(context, size: 13, color: Palette.of(context).muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.state,
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
  });
  final AppState state;
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) => _Row(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: Switch(
          value: state.toggles[id]!,
          onChanged: enabled ? (v) => state.setToggle(id, v) : null,
        ),
      );
}
