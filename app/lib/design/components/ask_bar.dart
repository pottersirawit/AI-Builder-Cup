import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import 'marks.dart';

/// The plain-Thai question field: the app's primary action.
class AskBar extends StatefulWidget {
  const AskBar({
    super.key,
    required this.onSubmit,
    this.hint = 'ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม',
    this.enabled = true,
    this.controller,
  });

  final ValueChanged<String> onSubmit;
  final String hint;
  final bool enabled;
  final TextEditingController? controller;

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _send() {
    final q = _c.text.trim();
    if (q.isEmpty || !widget.enabled) return;
    widget.onSubmit(q);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    const pad = 4.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.x4, pad, pad, pad),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Color(0x140B1F3A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const GeminiMark(size: 20),
          const SizedBox(width: Space.x3),
          Expanded(
            child: TextField(
              controller: _c,
              enabled: widget.enabled,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              style: t.bodyLarge,
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: t.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          IconButton.filled(
            tooltip: 'ถาม',
            onPressed: widget.enabled ? _send : null,
            icon: const Icon(Symbols.arrow_upward_rounded, weight: 600),
          ),
        ],
      ),
    );
  }
}
