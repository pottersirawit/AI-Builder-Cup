import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import 'pass.dart';

/// A placeholder block that pulses while content loads (still under
/// reduce motion).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = Radii.xs});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).enabled) {
      _a.repeat(reverse: true);
    } else {
      _a.value = .5;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = FonColors.of(context).perforation;
    return FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// The pass's shape while its verdict loads.
class PassSkeleton extends StatelessWidget {
  const PassSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'กำลังโหลดคำตอบ',
        child: const Pass(sections: [
          PassSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 180),
                SizedBox(height: Space.x3),
                Skeleton(width: 240, height: 40, radius: Radii.sm),
                SizedBox(height: Space.x3),
                Skeleton(),
                SizedBox(height: Space.x2),
                Skeleton(width: 200),
              ],
            ),
          ),
          PassSection(
            child: Row(
              children: [
                Expanded(child: Skeleton(height: 36)),
                SizedBox(width: Space.x4),
                Expanded(child: Skeleton(height: 36)),
                SizedBox(width: Space.x4),
                Expanded(child: Skeleton(height: 36)),
              ],
            ),
          ),
          PassSection(child: Skeleton(height: 72, radius: Radii.sm)),
        ]),
      );
}

/// Something failed: say what, and offer the way back.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'ลองอีกครั้ง',
  });
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => _StateBlock(
        icon: Symbols.wifi_off_rounded,
        title: title,
        message: message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Symbols.refresh_rounded),
          label: Text(retryLabel),
        ),
      );
}

/// Nothing to show yet, and what to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _StateBlock(icon: icon, title: title, message: message, action: action);
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: Space.x3),
          Text(title, style: t.titleLarge),
          const SizedBox(height: Space.x1),
          Text(message, style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: Space.x4), action!],
        ],
      ),
    );
  }
}
