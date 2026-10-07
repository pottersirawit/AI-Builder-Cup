import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../time_th.dart';
import '../widgets/common.dart';
import 'flood_screen.dart';

/// Fixed report location until GPS is wired in: Ratchadaphisek Rd at
/// Soi Lat Phrao 32, the flood spot in the demo scenario.
const demoReportLocation = (lat: 13.8063, lng: 100.5737, nameTh: 'ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32');

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.picker});
  final ImagePicker? picker;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  Uint8List? _photo;
  FloodReport? _result;
  bool _sending = false;

  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('เปิดกล้อง/คลังภาพไม่ได้: $e')));
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _result = null;
      _sending = true;
    });
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final r = state.track(await api.submitReport(
      photo: bytes,
      filename: file.name.isEmpty ? 'flood.jpg' : file.name,
      lat: demoReportLocation.lat,
      lng: demoReportLocation.lng,
    ));
    if (!mounted) return;
    setState(() {
      _result = r;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final p = Palette.of(context);
    final r = _result;
    return SubScreen(
      title: 'รายงานน้ำท่วม',
      children: [
        Eyebrow('${demoReportLocation.nameTh} · ${hhmm(state.now())}'),
        _Viewfinder(photo: _photo, scanning: _sending),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _sending ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: Text('ถ่ายรูป', style: txt(context, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _sending ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('จากคลังภาพ', style: txt(context, weight: FontWeight.w600, color: p.accent)),
              ),
            ),
          ],
        ),
        if (r == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              _sending
                  ? 'Gemini กำลังดูภาพ…'
                  : 'ถ่ายรูปน้ำท่วม Gemini จะประเมินระดับน้ำจากภาพ แล้วส่งให้คนที่กำลังจะผ่านจุดนี้',
              style: txt(context, size: 13, color: p.muted),
            ),
          )
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Pill('น้ำสูงประมาณ ${r.depthCmMin} ถึง ${r.depthCmMax} ซม.', tone: Tone.bad),
                    const Spacer(),
                    Text('มั่นใจ ${percent(r.confidence)}', style: txt(context, size: 13, color: p.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(r.descriptionTh, style: txt(context, height: 1.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in TravelMode.values)
                      if (r.passable[m] != null)
                        Pill('${m.emoji} ${passableLabel(r.passable[m]!)}', tone: passableTone(r.passable[m]!)),
                  ],
                ),
                const SourceLabel('Gemini vision · เทียบกับความสูงล้อรถและขอบทาง'),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('ส่งต่อแล้ว'),
                          const SizedBox(height: 4),
                          Text('แจ้งคน ${r.notifiedUsers} คนที่กำลังจะผ่านจุดนี้',
                              style: txt(context, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Pill('✓', tone: Tone.ok),
                  ],
                ),
                if (r.corroboratingReports > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'รายงานนี้ยืนยันกับอีก ${r.corroboratingReports} รายงานใกล้ ๆ จุดนี้',
                      style: txt(context, size: 13, color: p.muted),
                    ),
                  ),
                const SourceLabel('Pub/Sub → แจ้งเตือนเฉพาะคนที่เส้นทางผ่านจุดนี้'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute<void>(builder: (_) => const FloodScreen())),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('ดูสถานการณ์ที่บ้าน', style: txt(context, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ],
    );
  }
}

String passableLabel(String v) => switch (v) {
      'yes' => 'ผ่านได้',
      'slow' => 'ผ่านได้ช้า ๆ',
      _ => 'ไม่ควรผ่าน',
    };

Tone passableTone(String v) => switch (v) {
      'yes' => Tone.ok,
      'slow' => Tone.warn,
      _ => Tone.bad,
    };

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.photo, required this.scanning});
  final Uint8List? photo;
  final bool scanning;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  }

  @override
  void didUpdateWidget(_Viewfinder old) {
    super.didUpdateWidget(old);
    if (widget.scanning && !_scan.isAnimating) _scan.repeat();
    if (!widget.scanning) _scan.stop();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(22)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.photo != null)
            Image.memory(widget.photo!, fit: BoxFit.cover)
          else
            const Center(child: Icon(Icons.water, size: 64, color: Color(0xFF3C4653))),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(8)),
              child: Text('📍 ตำแหน่งจาก GPS', style: txt(context, size: 12, color: Colors.white)),
            ),
          ),
          if (widget.scanning)
            AnimatedBuilder(
              animation: _scan,
              builder: (context, _) => Align(
                alignment: Alignment(0, _scan.value * 2 - 1),
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, kBlue2, kViolet, Colors.transparent]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
