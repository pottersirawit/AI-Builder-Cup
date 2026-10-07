import 'package:flutter/material.dart';

import '../departure.dart';
import '../models.dart';

export '../departure.dart' show SkyState;

/// 4-point spacing scale. [gutter] is the screen edge inset.
abstract final class Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double gutter = x4;

  /// Minimum touch target (Material 48 dp).
  static const double target = 48;

  /// Flood mode targets: used under stress, one-handed, in the dark.
  static const double targetLarge = 64;
}

/// Corner radii. Nested surfaces follow outer = inner + padding.
abstract final class Radii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;

  /// The pass; its 16 dp padding makes [xs]-cornered contents concentric-ish
  /// without forcing it, since passes hold full-bleed rules, not boxes.
  static const double pass = lg;

  /// Radius of the semicircle punched out at each perforation.
  static const double notch = 9;
}

/// Durations and curves. Read them through [Motion.of] so the system
/// "reduce motion" / "remove animations" setting cuts them to zero.
class Motion {
  const Motion._(this.enabled);
  final bool enabled;

  static Motion of(BuildContext context) =>
      Motion._(!(MediaQuery.maybeDisableAnimationsOf(context) ?? false));

  static const tap = Duration(milliseconds: 120);
  static const flap = Duration(milliseconds: 180);
  static const rerank = Duration(milliseconds: 260);
  static const sky = Duration(milliseconds: 520);
  static const enter = Duration(milliseconds: 320);

  /// Material 3 standard and emphasized-decelerate easing.
  static const standard = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  Duration d(Duration full) => enabled ? full : Duration.zero;
}

/// One sky state's ground: a vertical gradient with legible ink on it.
@immutable
class SkyColors {
  const SkyColors({
    required this.top,
    required this.bottom,
    required this.onField,
    required this.onFieldMuted,
  });

  final Color top;
  final Color bottom;
  final Color onField;
  final Color onFieldMuted;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      );

  static SkyColors lerp(SkyColors a, SkyColors b, double t) => SkyColors(
        top: Color.lerp(a.top, b.top, t)!,
        bottom: Color.lerp(a.bottom, b.bottom, t)!,
        onField: Color.lerp(a.onField, b.onField, t)!,
        onFieldMuted: Color.lerp(a.onFieldMuted, b.onFieldMuted, t)!,
      );
}

/// Brand colour roles that Material's ColorScheme has no slot for.
@immutable
class FonColors extends ThemeExtension<FonColors> {
  const FonColors({
    required this.clear,
    required this.storm,
    required this.flood,
    required this.paper,
    required this.paperInk,
    required this.paperMuted,
    required this.perforation,
    required this.rain,
    required this.riskLow,
    required this.riskLowContainer,
    required this.riskMedium,
    required this.riskMediumContainer,
    required this.riskHigh,
    required this.riskHighContainer,
    required this.warning,
    required this.marker,
    required this.sourceInk,
    required this.passShadow,
  });

  final SkyColors clear;
  final SkyColors storm;
  final SkyColors flood;

  /// The pass surface and its inks.
  final Color paper;
  final Color paperInk;
  final Color paperMuted;
  final Color perforation;

  /// Rain ramp: none, light, moderate, heavy (see [rainLevel]).
  final List<Color> rain;

  final Color riskLow;
  final Color riskLowContainer;
  final Color riskMedium;
  final Color riskMediumContainer;
  final Color riskHigh;
  final Color riskHighContainer;

  /// The single warning amber; flood mode's only accent.
  final Color warning;

  /// Departure marker on the rain band.
  final Color marker;
  final Color sourceInk;
  final List<BoxShadow> passShadow;

  SkyColors sky(SkyState s) => switch (s) {
        SkyState.clear => clear,
        SkyState.storm => storm,
        SkyState.flood => flood,
      };

  Color riskInk(Risk r) => switch (r) {
        Risk.low => riskLow,
        Risk.medium => riskMedium,
        Risk.high => riskHigh,
      };

  Color riskContainer(Risk r) => switch (r) {
        Risk.low => riskLowContainer,
        Risk.medium => riskMediumContainer,
        Risk.high => riskHighContainer,
      };

  static FonColors of(BuildContext context) => Theme.of(context).extension<FonColors>()!;

  static const _clear = SkyColors(
    top: Color(0xFF0B57D0),
    bottom: Color(0xFF5C9DFF),
    onField: Color(0xFFFFFFFF),
    onFieldMuted: Color(0xFFD7E6FF),
  );
  static const _storm = SkyColors(
    top: Color(0xFF232B3E),
    bottom: Color(0xFF55617A),
    onField: Color(0xFFFFFFFF),
    onFieldMuted: Color(0xFFC9D1E0),
  );
  static const _flood = SkyColors(
    top: Color(0xFF02060F),
    bottom: Color(0xFF0B1730),
    onField: Color(0xFFF2F5FA),
    onFieldMuted: Color(0xFFA7B4CB),
  );

  static const light = FonColors(
    clear: _clear,
    storm: _storm,
    flood: _flood,
    paper: Color(0xFFFFFEFB),
    paperInk: Color(0xFF0B1F3A),
    paperMuted: Color(0xFF55657D),
    perforation: Color(0xFFC6D3E4),
    rain: [Color(0xFFDCE7F5), Color(0xFF9CC4FF), Color(0xFF4A8FF5), Color(0xFF1A4FB8)],
    riskLow: Color(0xFF137333),
    riskLowContainer: Color(0xFFE3F3E7),
    riskMedium: Color(0xFF9A5200),
    riskMediumContainer: Color(0xFFFFF0D9),
    riskHigh: Color(0xFFB3261E),
    riskHighContainer: Color(0xFFFCE4E2),
    warning: Color(0xFFE8A100),
    marker: Color(0xFF0B1F3A),
    sourceInk: Color(0xFF55657D),
    passShadow: [
      BoxShadow(color: Color(0x1F0B1F3A), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x330B1F3A), blurRadius: 28, spreadRadius: -6, offset: Offset(0, 12)),
    ],
  );

  /// Flood mode: near-black navy, one amber, nothing else shouting.
  static const dark = FonColors(
    clear: _clear,
    storm: _storm,
    flood: _flood,
    paper: Color(0xFF0F1A2E),
    paperInk: Color(0xFFF2F5FA),
    paperMuted: Color(0xFFA7B4CB),
    perforation: Color(0xFF2A3A57),
    rain: [Color(0xFF17233A), Color(0xFF34558A), Color(0xFF5F8FD6), Color(0xFFA9CBFF)],
    riskLow: Color(0xFF8FD4A4),
    riskLowContainer: Color(0xFF12301F),
    riskMedium: Color(0xFFFFC34D),
    riskMediumContainer: Color(0xFF3A2A06),
    riskHigh: Color(0xFFFFB020),
    riskHighContainer: Color(0xFF402A00),
    warning: Color(0xFFFFB020),
    marker: Color(0xFFFFB020),
    sourceInk: Color(0xFFA7B4CB),
    passShadow: [BoxShadow(color: Color(0x14FFFFFF), spreadRadius: 1)],
  );

  @override
  FonColors copyWith() => this;

  @override
  FonColors lerp(FonColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FonColors(
      clear: SkyColors.lerp(clear, other.clear, t),
      storm: SkyColors.lerp(storm, other.storm, t),
      flood: SkyColors.lerp(flood, other.flood, t),
      paper: c(paper, other.paper),
      paperInk: c(paperInk, other.paperInk),
      paperMuted: c(paperMuted, other.paperMuted),
      perforation: c(perforation, other.perforation),
      rain: [for (var i = 0; i < rain.length; i++) c(rain[i], other.rain[i])],
      riskLow: c(riskLow, other.riskLow),
      riskLowContainer: c(riskLowContainer, other.riskLowContainer),
      riskMedium: c(riskMedium, other.riskMedium),
      riskMediumContainer: c(riskMediumContainer, other.riskMediumContainer),
      riskHigh: c(riskHigh, other.riskHigh),
      riskHighContainer: c(riskHighContainer, other.riskHighContainer),
      warning: c(warning, other.warning),
      marker: c(marker, other.marker),
      sourceInk: c(sourceInk, other.sourceInk),
      passShadow: BoxShadow.lerpList(passShadow, other.passShadow, t)!,
    );
  }
}

/// Gemini attribution only (never text fill): the spark beside its answers.
const geminiGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4285F4), Color(0xFF9B72CB), Color(0xFFD96570)],
  stops: [0, .6, 1],
);
