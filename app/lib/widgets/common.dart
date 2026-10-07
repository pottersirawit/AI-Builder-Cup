import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../time_th.dart';

/// Body text style in the app font with overrides.
TextStyle txt(
  BuildContext context, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color ?? Palette.of(context).ink,
          height: height,
        );

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: txt(context,
                size: 12, weight: FontWeight.w600, color: color ?? Palette.of(context).muted)
            .copyWith(letterSpacing: .6),
      );
}

/// The "where this came from" line under every card.
class SourceLabel extends StatelessWidget {
  const SourceLabel(this.text, {super.key, this.padding = const EdgeInsets.only(top: 10)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: p.srcDot, shape: BoxShape.circle),
          ),
          Expanded(child: Text(text, style: txt(context, size: 11, color: p.muted))),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final light = p == Palette.light;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.cardBorder),
        ),
        elevation: light ? 3 : 0,
        shadowColor: const Color(0x22143C78),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.info});
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final flood = p == Palette.flood;
    final bg = tone == Tone.info && flood ? p.bg2 : tone.bg;
    final fg = tone == Tone.info && flood ? p.accent : tone.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: txt(context, size: 12, weight: FontWeight.w600, color: fg)),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.tone, {super.key, this.size = 12});
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
      );
}

/// Text painted with the Gemini blue-violet-pink gradient.
class GeminiText extends StatelessWidget {
  const GeminiText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => kGeminiGradient.createShader(r),
        child: Text(text, style: style.copyWith(fontWeight: FontWeight.w700)),
      );
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.label = 'ฝนตกไหม'});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(
                colors: [kBlue2, kViolet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.water_drop, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(label, style: txt(context, size: 15, weight: FontWeight.w700)),
        ],
      );
}

String percent(double confidence) => '${(confidence * 100).round()}%';

/// Coloured verdict block: eyebrow, big headline, summary, confidence.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.tone,
    required this.eyebrow,
    required this.headline,
    required this.summary,
    this.confidence,
    this.actions = const [],
  });

  final Tone tone;
  final String eyebrow;
  final String headline;
  final String summary;
  final double? confidence;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: tone.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(color: Color(0x24FFFFFF), shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Eyebrow(eyebrow, color: const Color(0xD9FFFFFF))),
                    if (confidence != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x38FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('มั่นใจ ${percent(confidence!)}',
                            style: txt(context, size: 12, weight: FontWeight.w600, color: white)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(headline,
                    style: txt(context, size: 30, weight: FontWeight.w700, color: white, height: 1.1)),
                const SizedBox(height: 8),
                Text(summary, style: txt(context, size: 14, color: white, height: 1.5)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Buttons on a coloured verdict card.
class OnColorButton extends StatelessWidget {
  const OnColorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.solid = true,
    this.solidColor = kBlue,
  });
  final String label;
  final VoidCallback onPressed;
  final bool solid;
  final Color solidColor;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: solid ? Colors.white : const Color(0x38FFFFFF),
          foregroundColor: solid ? solidColor : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: txt(context, weight: FontWeight.w600),
        ),
        child: Text(label),
      );
}

/// Rain-on-route bars, one per timeline point, bucketed like the prototype.
class RainTimeline extends StatelessWidget {
  const RainTimeline(this.points, {super.key});
  final List<RainPoint> points;

  static int level(double mm) => mm < .5
      ? 0
      : mm < 2.5
          ? 1
          : mm < 7.6
              ? 2
              : 3;

  static const _colors = [Color(0xFFE3EFFF), Color(0xFF9CC4FF), Color(0xFF4A8FF5), Color(0xFF1A4FB8)];
  static const _heights = [6.0, 22.0, 38.0, 54.0];

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final hourLabels = points.where((p) => toBangkok(p.time).minute == 0).map((p) => hhmm(p.time)).toList();
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in points)
                Expanded(
                  child: Tooltip(
                    message: '${hhmm(p.time)} · ${p.mmPerHr.toStringAsFixed(1)} มม./ชม.',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: _heights[level(p.mmPerHr)],
                      decoration: BoxDecoration(
                        color: _colors[level(p.mmPerHr)],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in hourLabels)
              Text(l, style: txt(context, size: 11, color: Palette.of(context).muted)),
          ],
        ),
      ],
    );
  }
}

class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.selected, required this.onChanged});
  final TravelMode selected;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        for (final m in TravelMode.values) ...[
          if (m != TravelMode.values.first) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: m == selected ? p.bg2 : p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: m == selected ? p.accent : p.line, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(m.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(m.labelTh,
                        style: txt(context,
                            size: 13,
                            weight: FontWeight.w600,
                            color: m == selected ? p.accent : p.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Tone.warn.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Tone.warn.fg.withValues(alpha: .4)),
        ),
        child: Text('ข้อมูลตัวอย่าง',
            style: txt(context, size: 11, weight: FontWeight.w600, color: Tone.warn.fg)),
      );
}

/// Phone-style status row showing the (demo) time. Long-press opens the
/// hidden demo-clock picker used to make the demo video reproducible.
class ClockBar extends StatelessWidget {
  const ClockBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final p = Palette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => showDemoClockPicker(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 6, 20, 6),
        child: Row(
          children: [
            Text(hhmm(state.now()), style: txt(context, weight: FontWeight.w600)),
            if (state.demoClock != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: p.srcDot, shape: BoxShape.circle),
              ),
            ],
            const Spacer(),
            if (state.usingSample) ...[const SampleBadge(), const SizedBox(width: 8)],
            Icon(Icons.signal_cellular_alt, size: 16, color: p.ink),
            const SizedBox(width: 4),
            Icon(Icons.wifi, size: 16, color: p.ink),
            const SizedBox(width: 4),
            Icon(Icons.battery_full, size: 16, color: p.ink),
          ],
        ),
      ),
    );
  }
}

Future<void> showDemoClockPicker(BuildContext context) {
  final state = AppScope.readState(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('เวลาสาธิต (X-Demo-Clock)', style: txt(ctx, weight: FontWeight.w700)),
            subtitle: Text('อังคาร 29 ก.ย. 2026 · เวลาไทย', style: txt(ctx, size: 12)),
          ),
          for (final t in [...demoPresets, null])
            ListTile(
              title: Text(t ?? 'เวลาจริง (ไม่ส่ง header)', style: txt(ctx)),
              trailing: (t == null ? null : demoClockIso(t)) == state.demoClock
                  ? const Icon(Icons.check, color: kBlue)
                  : null,
              onTap: () {
                state.demoClock = t == null ? null : demoClockIso(t);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Standard sub-screen frame: clock bar, back button, centred title.
class SubScreen extends StatelessWidget {
  const SubScreen({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.loading = false,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final bool loading;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: children,
    );
    if (onRefresh != null) list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ClockBar(),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Logo(label: title),
                  Positioned(
                    left: 4,
                    child: TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: Text('‹ กลับ',
                          style: txt(context, weight: FontWeight.w600, color: p.accent)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: loading ? const LinearProgressIndicator(minHeight: 2) : null,
            ),
            Expanded(child: list),
            ?bottom,
          ],
        ),
      ),
    );
  }
}
