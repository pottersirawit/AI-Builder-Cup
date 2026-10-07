import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

// Palette from fontokmai.html.
const kBlue = Color(0xFF1A73E8);
const kBlue2 = Color(0xFF4285F4);
const kViolet = Color(0xFF9B72CB);
const kPink = Color(0xFFD96570);
const kGeminiGradient = LinearGradient(colors: [kBlue2, kViolet, kPink], stops: [0, .6, 1]);

/// Semantic tones used for verdicts, pills and route dots.
enum Tone {
  info(kBlue, Color(0xFFEEF6FF), [kBlue2, kViolet]),
  ok(Color(0xFF1E8E3E), Color(0xFFE6F4EA), [Color(0xFF1E8E3E), Color(0xFF34A853)]),
  warn(Color(0xFFE37400), Color(0xFFFEF3E0), [Color(0xFFE37400), Color(0xFFF9AB00)]),
  bad(Color(0xFFD93025), Color(0xFFFCE8E6), [Color(0xFFC5221F), Color(0xFFEA4335)]);

  const Tone(this.fg, this.bg, this.gradient);
  final Color fg;
  final Color bg;
  final List<Color> gradient;

  static Tone ofVerdict(Verdict v) => switch (v) {
        Verdict.leaveNow => ok,
        Verdict.wait || Verdict.switchMode => warn,
        Verdict.dontGo => bad,
      };

  static Tone ofRisk(Risk r) => switch (r) {
        Risk.low => ok,
        Risk.medium => warn,
        Risk.high => bad,
      };

  static Tone ofHomeLevel(HomeLevel l) => switch (l) {
        HomeLevel.normal => ok,
        HomeLevel.watch => warn,
        HomeLevel.danger => bad,
      };
}

/// Surface colours that differ between the normal (light) and flood (dark)
/// screens, so shared widgets adapt automatically.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.bg2,
    required this.card,
    required this.cardBorder,
    required this.ink,
    required this.muted,
    required this.line,
    required this.srcDot,
    required this.accent,
  });

  final Color bg;
  final Color bg2;
  final Color card;
  final Color cardBorder;
  final Color ink;
  final Color muted;
  final Color line;
  final Color srcDot;
  final Color accent;

  static const light = Palette(
    bg: Color(0xFFDFEEFF),
    bg2: Color(0xFFEEF6FF),
    card: Colors.white,
    cardBorder: Color(0xB3D6E4F5),
    ink: Color(0xFF0B1F3A),
    muted: Color(0xFF5B6B82),
    line: Color(0xFFD6E4F5),
    srcDot: kBlue2,
    accent: kBlue,
  );

  static const flood = Palette(
    bg: Color(0xFF0B1A33),
    bg2: Color(0xFF1F3A66),
    card: Color(0xFF12264A),
    cardBorder: Color(0xFF1F3A66),
    ink: Color(0xFFE6EFFF),
    muted: Color(0xFF9FB4D6),
    line: Color(0xFF1F3A66),
    srcDot: Color(0xFFFF8A80),
    accent: Color(0xFF9CC4FF),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>() ?? light;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < .5 ? this : (other ?? this);
}

ThemeData _withPalette(ThemeData base, Palette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kBlue, brightness: brightness)
      .copyWith(primary: p.accent, surface: p.card, onSurface: p.ink);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: p.accent,
      thumbColor: p.accent,
      inactiveTrackColor: p.line,
    ),
  );
}

ThemeData buildTheme({bool useGoogleFonts = true}) {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: kBlue);
  final themed = useGoogleFonts
      ? base.copyWith(textTheme: GoogleFonts.chakraPetchTextTheme(base.textTheme))
      : base;
  return _withPalette(themed, Palette.light, Brightness.light);
}

/// Dark variant for flood mode that keeps the font of [light].
ThemeData floodTheme(ThemeData light) => _withPalette(light, Palette.flood, Brightness.dark);
