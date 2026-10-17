import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens.dart';

/// Where a glass surface sits, which decides how it is made.
enum GlassVariant {
  /// A content card. Over the smooth backdrop a blur would look the same as
  /// none, so it is translucent fill, a highlight and a light-catching rim.
  crystal,

  /// Chrome floating over scrolling content: a real backdrop blur.
  frosted,
}

/// "Crystal" surface. On the night theme it is dark glass over
/// [CrystalBackdrop]; on the light theme, translucent paper. Turns opaque in
/// flood mode, with high contrast or bold text on, so text never sits on a
/// busy ground for those users.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.variant = GlassVariant.crystal,
    this.radius = Radii.xl,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.borderRadius,
    this.shadow = true,
  });

  final Widget child;
  final GlassVariant variant;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// A colour washed through the glass, e.g. the risk of what it holds.
  final Color? tint;

  /// Per-corner radii; overrides [radius] (ticket halves).
  final BorderRadius? borderRadius;
  final bool shadow;

  static bool opaqueFor(BuildContext context) {
    final c = FonColors.of(context);
    return (!c.glass && Theme.of(context).brightness == Brightness.dark) ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.boldTextOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final crystal = variant == GlassVariant.crystal;

    if (opaqueFor(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: crystal ? c.paper : scheme.surfaceContainerHigh,
          borderRadius: shape,
          border: Border.all(color: c.perforation),
          boxShadow: crystal && shadow ? c.passShadow : null,
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    final night = c.glass;
    final blur = !crystal && !kIsWeb;
    // Light: .86 is the floor for muted text at 4.5:1 over the storm sky.
    // Night: ink is white, so the fill only has to lift the card off the
    // backdrop; the scrim under it keeps blobs from eating contrast.
    final Color fill;
    if (night) {
      fill = crystal
          ? const Color(0x1AFFFFFF)
          : (blur ? const Color(0x29FFFFFF) : const Color(0xE6161F33));
    } else {
      fill = crystal
          ? const Color(0xDBFFFEFB)
          : (blur ? const Color(0xB8FFFFFF) : const Color(0xF0FFFFFF));
    }
    final highlight = night ? .10 : (crystal ? .5 : .35);
    final surface = ColoredBox(
      color: night && crystal ? const Color(0x66060A14) : Colors.transparent,
      child: ColoredBox(
        color: fill,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: highlight),
                (tint ?? Colors.white).withValues(
                  alpha: tint == null ? 0 : .10,
                ),
              ],
            ),
          ),
          child: CustomPaint(
            foregroundPainter: _Rim(shape: shape, night: night),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: !shadow
            ? null
            : night
            ? const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 32,
                  spreadRadius: -6,
                  offset: Offset(0, 14),
                ),
              ]
            : crystal
            ? const [
                BoxShadow(
                  color: Color(0x290B1F3A),
                  blurRadius: 32,
                  spreadRadius: -8,
                  offset: Offset(0, 16),
                ),
                BoxShadow(
                  color: Color(0x140B1F3A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1F0B1F3A),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: surface,
              )
            : surface,
      ),
    );
  }
}

/// The 1 dp edge that catches light top-left and fades bottom-right.
class _Rim extends CustomPainter {
  const _Rim({required this.shape, required this.night});
  final BorderRadius shape;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: night ? .32 : .8),
          Colors.white.withValues(alpha: night ? .05 : .2),
        ],
      ).createShader(rect);
    canvas.drawRRect(shape.toRRect(rect.deflate(.5)), paint);
  }

  @override
  bool shouldRepaint(_Rim old) => old.shape != shape || old.night != night;
}

/// The night ground: deep navy lit by soft blobs of the sky's mood: blue
/// and cyan when clear, a warm sun when it is hot, slate when stormy.
class CrystalBackdrop extends StatelessWidget {
  const CrystalBackdrop({
    super.key,
    required this.state,
    this.warm = 0,
    required this.child,
  });

  final SkyState state;

  /// 0..1: how much hot sun to glow in the corner.
  final double warm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final (Color a, Color b, Color c) = switch (state) {
      SkyState.clear => (
        const Color(0xFF1F5FE0),
        const Color(0xFF16B4E8),
        const Color(0xFF5B3FD0),
      ),
      SkyState.storm => (
        const Color(0xFF3B4A6E),
        const Color(0xFF2A6FA8),
        const Color(0xFF29324A),
      ),
      SkyState.flood => (
        const Color(0xFF5A3A00),
        const Color(0xFF13284D),
        const Color(0xFF1A1A1A),
      ),
    };
    Widget blob(Alignment at, Color color, double size, double alpha) =>
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: at,
                radius: size,
                colors: [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: warm.clamp(0, 1)),
      duration: Motion.of(context).d(Motion.sky),
      builder: (context, w, _) => Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: base)),
          blob(const Alignment(-1.1, -1.0), a, 1.1, .55),
          blob(const Alignment(1.2, -0.35), b, .8, .35),
          blob(const Alignment(-0.6, 0.9), c, 1.0, .30),
          if (w > 0)
            blob(
              const Alignment(1.1, -1.1),
              const Color(0xFFFF9F2E),
              .9,
              .45 * w,
            ),
          child,
        ],
      ),
      child: child,
    );
  }
}

/// One destination of [GlassNavBar].
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.label,
    this.badge = false,
  });
  final IconData icon;
  final String label;

  /// A warning dot: something there needs the user.
  final bool badge;
}

/// Floating pill of destinations with a separate round action at its end,
/// like the search button beside an iOS 26 tab bar.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.action,
    required this.actionTooltip,
    required this.onAction,
  });

  final List<GlassNavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget action;
  final String actionTooltip;
  final VoidCallback onAction;

  static const double height = 64;

  /// Space the bar takes at the bottom of a scrolling page.
  static double inset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + height + Space.x3 + Space.x4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = FonColors.of(context);
    final motion = Motion.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showLabels = MediaQuery.textScalerOf(context).scale(14) <= 14 * 1.3;
    final Color indicator, onIndicator;
    if (c.glass) {
      indicator = Colors.white.withValues(alpha: .16);
      onIndicator = Colors.white;
    } else if (dark) {
      indicator = scheme.primaryContainer;
      onIndicator = scheme.onPrimaryContainer;
    } else {
      indicator = scheme.secondaryContainer;
      onIndicator = scheme.onSecondaryContainer;
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Space.x3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x6),
        child: Row(
          children: [
            Expanded(
              child: GlassSurface(
                variant: GlassVariant.frosted,
                radius: Radii.pill,
                padding: const EdgeInsets.all(Space.x1),
                child: SizedBox(
                  height: height - Space.x2,
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: motion.d(Motion.rerank),
                        curve: Motion.standard,
                        alignment: Alignment(
                          items.length == 1
                              ? 0
                              : -1 + 2 * selected / (items.length - 1),
                          0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 1 / items.length,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: indicator,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final (i, item) in items.indexed)
                            Expanded(
                              child: _NavSlot(
                                item: item,
                                selected: i == selected,
                                showLabel: showLabels,
                                ink: i == selected
                                    ? onIndicator
                                    : scheme.onSurfaceVariant,
                                onTap: () => onSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.x2),
            Semantics(
              button: true,
              label: actionTooltip,
              excludeSemantics: true,
              child: Tooltip(
                message: actionTooltip,
                child: Material(
                  color: c.glass ? Colors.white : null,
                  type: c.glass
                      ? MaterialType.canvas
                      : MaterialType.transparency,
                  shape: const CircleBorder(),
                  elevation: c.glass ? 6 : 0,
                  shadowColor: Colors.white.withValues(alpha: .4),
                  child: c.glass
                      ? InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAction,
                          child: SizedBox.square(
                            dimension: height,
                            child: Center(child: action),
                          ),
                        )
                      : GlassSurface(
                          variant: GlassVariant.frosted,
                          radius: Radii.pill,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onAction,
                              child: SizedBox.square(
                                dimension: height,
                                child: Center(child: action),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.ink,
    required this.onTap,
  });
  final GlassNavItem item;
  final bool selected;
  final bool showLabel;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final icon = Icon(item.icon, color: ink, fill: selected ? 1 : 0, size: 24);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: showLabel ? '' : item.label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.badge)
                    Badge(smallSize: 8, backgroundColor: c.warning, child: icon)
                  else
                    icon,
                  if (showLabel) ...[
                    const SizedBox(width: Space.x2),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelLarge!.copyWith(color: ink),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass ticket: [top] and [bottom] halves joined by a perforation with a
/// notch punched out of each side, like the boarding-pass identity.
class GlassTicket extends StatelessWidget {
  const GlassTicket({
    super.key,
    required this.top,
    required this.bottom,
    this.onTap,
    this.radius = Radii.xl,
    this.tint,
  });

  final Widget top;
  final Widget bottom;
  final VoidCallback? onTap;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final r = Radius.circular(radius);
    final ticket = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipPath(
          clipper: const _NotchClipper(atTop: false),
          child: GlassSurface(
            borderRadius: BorderRadius.vertical(top: r),
            shadow: false,
            tint: tint,
            child: top,
          ),
        ),
        ClipPath(
          clipper: const _NotchClipper(atTop: true),
          child: GlassSurface(
            borderRadius: BorderRadius.vertical(bottom: r),
            shadow: false,
            tint: tint,
            child: CustomPaint(
              painter: _Perforation(
                color: c.glass ? const Color(0x40FFFFFF) : c.perforation,
              ),
              child: bottom,
            ),
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(r),
        // Glass halves carry no shadow: it would show through the notches.
        boxShadow: GlassSurface.opaqueFor(context) ? c.passShadow : null,
      ),
      child: Stack(
        children: [
          ticket,
          if (onTap != null)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(borderRadius: BorderRadius.all(r), onTap: onTap),
              ),
            ),
        ],
      ),
    );
  }
}

const double _notch = 10;

/// Half-circle notches on both sides of the joining edge.
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.atTop});
  final bool atTop;

  @override
  Path getClip(Size size) {
    final y = atTop ? 0.0 : size.height;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _notch))
        ..addOval(
          Rect.fromCircle(center: Offset(size.width, y), radius: _notch),
        ),
    );
  }

  @override
  bool shouldReclip(_NotchClipper old) => old.atTop != atTop;
}

/// The dashed tear line along the top of the bottom half.
class _Perforation extends CustomPainter {
  const _Perforation({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0, gap = 5.0;
    for (var x = _notch + 6; x < size.width - _notch - 6; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => old.color != color;
}
