import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models.dart';
import '../labels.dart';
import '../theme.dart';
import '../tokens.dart';

/// Risk as icon + word + colour, so it never rests on colour alone.
class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.risk, this.label, this.dense = false});
  final Risk risk;

  /// Defaults to the risk's own words.
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final ink = c.riskInk(risk);
    return Container(
      padding: EdgeInsets.fromLTRB(dense ? 6 : 8, dense ? 2 : 4, dense ? 8 : 10, dense ? 2 : 4),
      decoration: BoxDecoration(
        color: c.riskContainer(risk),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(risk.icon, size: dense ? 14 : 16, color: ink, fill: 1),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label ?? risk.labelTh,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? t.labelSmall : t.labelMedium)!.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a card's facts came from. Every card carries one.
class SourceLabel extends StatelessWidget {
  const SourceLabel(this.text, {super.key, this.color, this.icon = Symbols.database_rounded});
  final String text;
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? FonColors.of(context).sourceInk;
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: 'แหล่งข้อมูล: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: ink),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: t.bodySmall!.copyWith(color: ink, height: 1.45))),
        ],
      ),
    );
  }
}

/// "ข้อมูลตัวอย่าง": the backend is unreachable and bundled samples are shown.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key, this.onField = false});
  final bool onField;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final ink = onField ? const Color(0xFF2A1A00) : c.riskMedium;
    return Semantics(
      label: 'ข้อมูลตัวอย่าง เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
        decoration: BoxDecoration(
          color: onField ? c.warning : c.riskMediumContainer,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off_rounded, size: 14, color: ink),
            const SizedBox(width: 4),
            Text('ข้อมูลตัวอย่าง', style: t.labelSmall!.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

/// Confidence as ten ticks plus the number; honest about uncertainty.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({super.key, required this.value, this.color});
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    final ink = color ?? c.paperInk;
    final filled = (value * 10).round();
    return Semantics(
      label: 'ความมั่นใจ ${percent(value)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('มั่นใจ', style: t.labelMedium!.copyWith(color: c.paperMuted)),
          const SizedBox(width: Space.x2),
          for (var i = 0; i < 10; i++)
            Container(
              width: 4,
              height: 12,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: i < filled ? ink : c.perforation,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          const SizedBox(width: Space.x2 - 2),
          Text(percent(value), style: tabular(t.labelLarge!).copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// Gemini's mark: the spark in the Gemini gradient (never applied to text).
class GeminiMark extends StatelessWidget {
  const GeminiMark({super.key, this.size = 18, this.fallback = false});
  final double size;

  /// Rule-based fallback answered instead of Gemini.
  final bool fallback;

  @override
  Widget build(BuildContext context) {
    if (fallback) {
      return Icon(Symbols.rule_rounded, size: size, color: FonColors.of(context).paperMuted);
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: geminiGradient.createShader,
      child: Icon(Symbols.auto_awesome_rounded, size: size, fill: 1, color: Colors.white),
    );
  }
}

/// Who answered: Gemini or the rule-based fallback, said plainly.
class GeneratedBy extends StatelessWidget {
  const GeneratedBy(this.generatedBy, {super.key});
  final String generatedBy;

  @override
  Widget build(BuildContext context) {
    final fallback = generatedBy == 'fallback';
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GeminiMark(size: 16, fallback: fallback),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fallback ? 'กฎสำรอง · Gemini ไม่ตอบในรอบนี้' : 'ตัดสินโดย Gemini',
            style: t.labelMedium!.copyWith(color: c.paperMuted),
          ),
        ),
      ],
    );
  }
}
