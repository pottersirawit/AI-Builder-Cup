import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';

class _SkyTween extends Tween<SkyColors> {
  _SkyTween({super.end});
  @override
  SkyColors lerp(double t) => SkyColors.lerp(begin!, end!, t);
}

/// The ground: the sky's state as a gradient that eases between states.
/// Fills [height] from the top, behind the status bar; content scrolls over it.
class SkyField extends StatelessWidget {
  const SkyField({super.key, required this.state, required this.child, this.height});
  final SkyState state;
  final Widget child;

  /// Height of the painted field; defaults to 45% of the screen.
  /// [double.infinity] paints behind the whole child (a short header field).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final target = FonColors.of(context).sky(state);
    final h = height ?? MediaQuery.sizeOf(context).height * .45;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: TweenAnimationBuilder<SkyColors>(
        tween: _SkyTween(end: target),
        duration: Motion.of(context).d(Motion.sky),
        curve: Motion.standard,
        builder: (context, sky, child) => Stack(
          children: [
            if (h.isInfinite)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: sky.gradient)))
            else
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: h,
                child: DecoratedBox(decoration: BoxDecoration(gradient: sky.gradient)),
              ),
            DefaultTextStyle.merge(
              style: TextStyle(color: sky.onField),
              child: IconTheme.merge(data: IconThemeData(color: sky.onField), child: child!),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Title row on the field: optional back, title + subtitle, actions.
class FieldHeader extends StatelessWidget {
  const FieldHeader({
    super.key,
    required this.state,
    required this.title,
    this.subtitle,
    this.onSubtitleTap,
    this.subtitleTapLabel,
    this.back = false,
    this.actions = const [],
    this.badge,
  });
  final SkyState state;
  final String title;
  final String? subtitle;

  /// Makes the title block a button that edits the place in [subtitle];
  /// the subtitle then carries an edit-location icon.
  final VoidCallback? onSubtitleTap;

  /// What [onSubtitleTap] does, for screen readers.
  final String? subtitleTapLabel;
  final bool back;
  final List<Widget> actions;

  /// A small status pill right after the title, e.g. "เดโม".
  final Widget? badge;

  // The subtitle line alone is ~20 dp, so the whole title block is the target.
  Widget _tappable(Widget child) => Semantics(
        button: true,
        label: subtitleTapLabel,
        child: InkWell(
          onTap: onSubtitleTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Space.target),
            child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: child),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sky = FonColors.of(context).sky(state);
    final t = Theme.of(context).textTheme;
    final subtitleText = subtitle == null
        ? null
        : Text(subtitle!,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium!.copyWith(color: sky.onFieldMuted));
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitleText != null)
          onSubtitleTap == null
              ? subtitleText
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: subtitleText),
                    const SizedBox(width: Space.x1),
                    Icon(Symbols.edit_location_alt_rounded, size: 14, color: sky.onFieldMuted),
                  ],
                ),
        Row(
          children: [
            Flexible(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineSmall!.copyWith(color: sky.onField)),
            ),
            if (badge != null) ...[const SizedBox(width: Space.x2), Flexible(child: badge!)],
          ],
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(back ? Space.x1 : Space.gutter, Space.x2, Space.x2, Space.x2),
      child: Row(
        children: [
          if (back)
            IconButton(
              tooltip: 'กลับ',
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Symbols.arrow_back_rounded, color: sky.onField),
            ),
          Expanded(child: onSubtitleTap == null ? titleBlock : _tappable(titleBlock)),
          ...actions,
        ],
      ),
    );
  }
}
