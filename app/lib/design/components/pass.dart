import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';
import '../tokens.dart';

/// A paper pass: stacked sections separated by perforated rules, with a
/// semicircle punched out of each edge at every seam, like a boarding pass.
class Pass extends StatelessWidget {
  const Pass({super.key, required this.sections, this.onTap, this.semanticLabel});

  final List<Widget> sections;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    Widget body = _PassBody(
      paper: c.paper,
      perforation: c.perforation,
      shadows: c.passShadow,
      children: sections,
    );
    if (onTap != null) {
      // Ink would paint under the paper, so the pass takes taps without a
      // ripple; every pass that has onTap also carries a visible button.
      body = GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: body);
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: DefaultTextStyle.merge(style: TextStyle(color: c.paperInk), child: body),
    );
  }
}

/// Standard section padding inside a [Pass].
class PassSection extends StatelessWidget {
  const PassSection({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(Space.x5, Space.x4, Space.x5, Space.x4),
        child: child,
      );
}

/// One labelled value in the segment row: ออก | ถึง | โหมด | มั่นใจ.
class PassSegment {
  const PassSegment(this.label, this.value, {this.icon, this.color});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
}

/// Segment row: label above a tabular value, hairlines between segments.
class PassSegments extends StatelessWidget {
  const PassSegments(this.segments, {super.key});
  final List<PassSegment> segments;

  @override
  Widget build(BuildContext context) {
    final c = FonColors.of(context);
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              VerticalDivider(width: Space.x5, thickness: 1, color: c.perforation),
            Expanded(
              child: Semantics(
                label: '${segments[i].label} ${segments[i].value}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(segments[i].label,
                        style: t.labelSmall!.copyWith(color: c.paperMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (segments[i].icon != null) ...[
                          Icon(segments[i].icon, size: 18, color: segments[i].color ?? c.paperInk),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            segments[i].value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tabular(t.titleMedium!).copyWith(
                              fontWeight: FontWeight.w700,
                              color: segments[i].color ?? c.paperInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PassBody extends MultiChildRenderObjectWidget {
  const _PassBody({
    required this.paper,
    required this.perforation,
    required this.shadows,
    required super.children,
  });

  final Color paper;
  final Color perforation;
  final List<BoxShadow> shadows;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPass(paper: paper, perforation: perforation, shadows: shadows);

  @override
  void updateRenderObject(BuildContext context, _RenderPass r) => r
    ..paper = paper
    ..perforation = perforation
    ..shadows = shadows;
}

class _PassParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPass extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PassParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PassParentData> {
  _RenderPass({required Color paper, required Color perforation, required List<BoxShadow> shadows})
      : _paper = paper,
        _perforation = perforation,
        _shadows = shadows;

  Color _paper;
  set paper(Color v) {
    if (v == _paper) return;
    _paper = v;
    markNeedsPaint();
  }

  Color _perforation;
  set perforation(Color v) {
    if (v == _perforation) return;
    _perforation = v;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> v) {
    _shadows = v;
    markNeedsPaint();
  }

  final List<double> _seams = [];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PassParentData) child.parentData = _PassParentData();
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    var h = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      h += c.getMinIntrinsicHeight(width);
    }
    return h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    _seams.clear();
    var y = 0.0;
    final inner = BoxConstraints.tightFor(width: constraints.maxWidth);
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (c != firstChild) _seams.add(y);
      c.layout(inner, parentUsesSize: true);
      (c.parentData! as _PassParentData).offset = Offset(0, y);
      y += c.size.height;
    }
    size = constraints.constrain(Size(constraints.maxWidth, y));
  }

  Path _shape(Offset o) {
    final rect = o & size;
    var path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(Radii.pass)));
    for (final s in _seams) {
      final notches = Path()
        ..addOval(Rect.fromCircle(center: Offset(rect.left, rect.top + s), radius: Radii.notch))
        ..addOval(Rect.fromCircle(center: Offset(rect.right, rect.top + s), radius: Radii.notch));
      path = Path.combine(PathOperation.difference, path, notches);
    }
    return path;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final shape = _shape(offset);
    for (final s in _shadows) {
      final p = s.toPaint();
      if (s.spreadRadius > 0 && s.blurRadius == 0) {
        // A ring, used for elevation in dark mode where shadows vanish.
        canvas.drawPath(
            shape,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s.spreadRadius * 2
              ..color = s.color);
        continue;
      }
      final grow = s.spreadRadius;
      final m = Matrix4.identity();
      final b = shape.getBounds();
      if (grow != 0) {
        m
          ..translateByDouble(b.center.dx, b.center.dy, 0, 1)
          ..scaleByDouble((b.width + grow * 2) / b.width, (b.height + grow * 2) / b.height, 1, 1)
          ..translateByDouble(-b.center.dx, -b.center.dy, 0, 1);
      }
      canvas.drawPath(shape.transform(m.storage).shift(s.offset), p);
    }
    canvas.drawPath(shape, Paint()..color = _paper);

    final dash = Paint()
      ..color = _perforation
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final s in _seams) {
      final y = offset.dy + s;
      var x = offset.dx + Radii.notch + 8;
      final end = offset.dx + size.width - Radii.notch - 8;
      while (x < end) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, end), y), dash);
        x += 10;
      }
    }

    context.pushClipPath(needsCompositing, offset, Offset.zero & size, _shape(Offset.zero),
        (ctx, o) => defaultPaint(ctx, o));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
