import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../location.dart';
import '../models.dart';
import '../time_th.dart';
import 'shell.dart';

/// Photo of street flooding → Gemini vision depth → people on the route.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.picker, this.locate = currentFix, this.autoSubmit = false});
  final ImagePicker? picker;
  final Future<Fix> Function() locate;

  /// Demo hook: submit without a photo on open, to show the result state.
  final bool autoSubmit;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  Fix? _fix;
  bool _locating = true;
  Uint8List? _photo;
  FloodReport? _result;
  bool _sending = false;
  Object? _error;
  ({Uint8List bytes, String name})? _pending;
  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _locate().then((_) {
      if (widget.autoSubmit && mounted) _submit(Uint8List(0), 'sample.jpg');
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final f = await widget.locate();
    if (!mounted) return;
    setState(() {
      _fix = f;
      _locating = false;
    });
  }

  Future<void> _pick(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(source == ImageSource.camera
            ? 'เปิดกล้องไม่ได้ ลองเลือกจากคลังภาพแทน'
            : 'เปิดคลังภาพไม่ได้ ตรวจสิทธิ์รูปภาพในตั้งค่าเครื่อง'),
      ));
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = bytes);
    await _submit(bytes, file.name.isEmpty ? 'flood.jpg' : file.name);
  }

  Future<void> _submit(Uint8List bytes, String name) async {
    final fix = _fix ?? await widget.locate();
    if (!mounted) return;
    setState(() {
      _result = null;
      _error = null;
      _sending = true;
      _pending = (bytes: bytes, name: name);
    });
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    try {
      final r = state.track(await api.submitReport(photo: bytes, filename: name, lat: fix.lat, lng: fix.lng));
      if (!mounted) return;
      setState(() => _result = r);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _resultKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              duration: Motion.of(context).d(Motion.enter), curve: Motion.standard, alignment: .1);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final sky = state.flood ? SkyState.flood : SkyState.storm;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final r = _result;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SkyField(
              state: sky,
              height: double.infinity,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldHeader(
                      state: sky,
                      title: 'แจ้งน้ำท่วม',
                      subtitle: 'ถ่ายรูปน้ำบนถนน บอกคนที่กำลังจะผ่าน',
                      actions: [
                        if (state.usingSample)
                          const Padding(
                            padding: EdgeInsets.only(right: Space.x3),
                            child: SampleBadge(onField: true),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
                      child: _LocationLine(fix: _fix, locating: _locating, time: hhmm(state.now()), onRetry: _locate, sky: sky),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x10),
            sliver: SliverList.list(children: [
              _Viewfinder(photo: _photo, scanning: _sending),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sending ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Symbols.photo_camera_rounded),
                      label: const Text('ถ่ายรูป'),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sending ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Symbols.photo_library_rounded),
                      label: const Text('จากคลังภาพ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              if (_error != null)
                ErrorState(
                  title: 'ส่งรายงานไม่สำเร็จ',
                  message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ รูปยังอยู่ในเครื่อง ส่งใหม่ได้เลย',
                  retryLabel: 'ส่งอีกครั้ง',
                  onRetry: () => _submit(_pending!.bytes, _pending!.name),
                )
              else if (r == null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 3), child: GeminiMark(size: 18)),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Text(
                        _sending
                            ? 'Gemini กำลังดูภาพ ประเมินระดับน้ำเทียบกับล้อรถและขอบทาง…'
                            : 'Gemini จะประเมินระดับน้ำจากภาพ แล้วเตือนคนที่เส้นทางผ่านจุดนี้ในรัศมี 300 ม.',
                        style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              else ...[
                _ResultPass(key: _resultKey, report: r),
                const SizedBox(height: Space.x4),
                FilledButton.tonalIcon(
                  onPressed: () => Shell.goTo(context, ShellTab.home),
                  icon: const Icon(Symbols.home_rounded),
                  label: const Text('ดูสถานการณ์ที่บ้าน'),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({
    required this.fix,
    required this.locating,
    required this.time,
    required this.onRetry,
    required this.sky,
  });
  final Fix? fix;
  final bool locating;
  final String time;
  final VoidCallback onRetry;
  final SkyState sky;

  @override
  Widget build(BuildContext context) {
    final colors = FonColors.of(context).sky(sky);
    final t = Theme.of(context).textTheme;
    final f = fix;
    final String title;
    final String detail;
    if (locating || f == null) {
      title = 'กำลังหาตำแหน่ง…';
      detail = 'ใช้ GPS ของเครื่อง';
    } else if (f.fromGps) {
      title = f.noteTh;
      detail = 'GPS · ${f.lat.toStringAsFixed(4)}, ${f.lng.toStringAsFixed(4)} · $time';
    } else {
      title = fallbackSpot.nameTh;
      detail = '${f.noteTh} · ใช้ตำแหน่งสำรองของเดโม';
    }
    return Row(
      children: [
        Icon(f?.fromGps ?? false ? Symbols.my_location_rounded : Symbols.location_on_rounded,
            color: colors.onField, size: 20),
        const SizedBox(width: Space.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.titleSmall!.copyWith(color: colors.onField)),
              Text(detail, style: tabular(t.bodySmall!).copyWith(color: colors.onFieldMuted)),
            ],
          ),
        ),
        if (!locating && !(f?.fromGps ?? true))
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: colors.onField),
            child: const Text('ลองหา GPS'),
          ),
      ],
    );
  }
}

class _ResultPass extends StatelessWidget {
  const _ResultPass({super.key, required this.report});
  final FloodReport report;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final r = report;
    return Pass(
      semanticLabel: 'น้ำสูงประมาณ ${r.depthCmMin} ถึง ${r.depthCmMax} เซนติเมตร',
      sections: [
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const GeminiMark(size: 16),
                const SizedBox(width: Space.x2),
                Text('Gemini ดูภาพแล้ว', style: t.titleSmall!.copyWith(color: c.paperInk)),
              ]),
              const SizedBox(height: Space.x2),
              Text('น้ำสูง ${r.depthCmMin}–${r.depthCmMax} ซม.',
                  style: tabular(t.displaySmall!).copyWith(color: c.paperInk)),
              const SizedBox(height: Space.x2),
              ConfidenceMeter(value: r.confidence),
              const SizedBox(height: Space.x3),
              Text(r.descriptionTh, style: t.bodyMedium!.copyWith(color: c.paperInk)),
            ],
          ),
        ),
        PassSection(
          child: PassSegments([
            for (final m in TravelMode.values)
              if (r.passable[m] != null)
                PassSegment(m.shortTh, passableLabel(r.passable[m]!),
                    icon: passableRisk(r.passable[m]!).icon, color: c.riskInk(passableRisk(r.passable[m]!))),
          ]),
        ),
        PassSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.campaign_rounded, color: c.paperInk),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: Text('แจ้งคน ${r.notifiedUsers} คนที่กำลังจะผ่านจุดนี้',
                        style: tabular(t.titleMedium!).copyWith(color: c.paperInk)),
                  ),
                ],
              ),
              if (r.corroboratingReports > 0)
                Padding(
                  padding: const EdgeInsets.only(top: Space.x1, left: 32),
                  child: Text('ยืนยันกับอีก ${r.corroboratingReports} รายงานในรัศมี 300 ม.',
                      style: t.bodySmall!.copyWith(color: c.paperMuted)),
                ),
              const SizedBox(height: Space.x3),
              const SourceLabel('Gemini vision เทียบล้อรถและขอบทาง · Pub/Sub แจ้งเฉพาะคนที่เส้นทางผ่าน · จำนวนคนเป็นตัวเลขจำลองสำหรับเดโม'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.photo, required this.scanning});
  final Uint8List? photo;
  final bool scanning;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _scan =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didUpdateWidget(_Viewfinder old) {
    super.didUpdateWidget(old);
    final animate = widget.scanning && Motion.of(context).enabled;
    if (animate && !_scan.isAnimating) _scan.repeat();
    if (!animate) _scan.stop();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final photo = widget.photo;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null && photo.isNotEmpty)
              Image.memory(photo, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.flood_rounded, size: 48, color: Color(0xFF6A7A96)),
                  const SizedBox(height: Space.x2),
                  Text(photo == null ? 'ถ่ายให้เห็นล้อรถหรือขอบทาง' : 'ไม่มีภาพ · ผลตัวอย่าง',
                      style: t.bodyMedium!.copyWith(color: const Color(0xFFA7B4CB))),
                ],
              ),
            if (widget.scanning)
              AnimatedBuilder(
                animation: _scan,
                builder: (context, _) => Align(
                  alignment: Alignment(0, _scan.value * 2 - 1),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(gradient: geminiGradient),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
