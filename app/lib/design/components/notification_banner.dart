import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';

/// In-app stand-in for the push notification that opens the app at 16:10.
class NotificationBanner extends StatelessWidget {
  const NotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.time,
    required this.onOpen,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String time;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const ink = Color(0xFF0B1F3A);
    const muted = Color(0xFF55657D);
    const radius = 22.0;
    final motion = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.d(Motion.enter),
      curve: Motion.emphasizedDecelerate,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * -24),
        child: Opacity(opacity: v, child: child),
      ),
      child: Dismissible(
        key: const ValueKey('push'),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(color: Color(0x290B1F3A), blurRadius: 30, offset: Offset(0, 12), spreadRadius: -8),
              ],
            ),
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.x3, Space.x3, Space.x1, Space.x3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B57D0),
                        borderRadius: BorderRadius.circular(radius - Space.x3),
                      ),
                      child: const Icon(Symbols.rainy_rounded, color: Colors.white, size: 24, fill: 1),
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ฝนตกไหม · $time', style: t.labelMedium!.copyWith(color: muted)),
                          Text(title, style: t.titleMedium!.copyWith(color: ink, fontWeight: FontWeight.w700)),
                          Text(body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyMedium!.copyWith(color: ink, height: 1.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิดแจ้งเตือน',
                      onPressed: onDismiss,
                      icon: const Icon(Symbols.close_rounded, color: muted, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
