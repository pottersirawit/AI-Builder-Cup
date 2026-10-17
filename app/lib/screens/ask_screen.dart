import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../places.dart';
import 'parts.dart';

List<String> suggestedQuestions(AppLocalizations l) => [
  l.askSuggestion1,
  l.askSuggestion2,
];

class _Message {
  const _Message.me(this.text)
    : mine = true,
      decision = null,
      needs = null,
      failed = false;
  const _Message.ai(this.text, [this.decision])
    : mine = false,
      needs = null,
      failed = false;
  const _Message.failed(this.text)
    : mine = false,
      decision = null,
      needs = null,
      failed = true;

  /// The answer is a question back: where is [text]'s place?
  const _Message.needs(this.text, NeedsPlace this.needs)
    : mine = false,
      decision = null,
      failed = false;
  final bool mine;
  final String text;
  final Decision? decision;
  final NeedsPlace? needs;
  final bool failed;
}

/// Follow-up questions; each is POSTed to /v1/decide as question_th.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, this.trip, this.opening});
  final Trip? trip;

  /// Current verdict headline, quoted in the opening message.
  final String? opening;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late final List<_Message> _messages = [
    _Message.ai(
      widget.opening == null
          ? context.l10n.askOpeningPlain
          : context.l10n.askOpeningWith(widget.opening!),
    ),
  ];
  final _asked = <String>{};
  final _scroll = ScrollController();
  bool _thinking = false;
  String? _lastQuestion;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Asks [q]; [places] re-runs it once the user said where.
  Future<void> _ask(String q, {List<SavedPlace>? places}) async {
    q = q.trim();
    if (q.isEmpty || _thinking) return;
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    final store = AppScope.readPlaces(context);
    setState(() {
      if (places == null) _messages.add(_Message.me(q));
      _asked.add(q);
      _thinking = true;
      _lastQuestion = q;
    });
    _scrollToEnd();
    try {
      final missing = widget.trip == null && places == null
          ? missingPlaceFor(q, home: store.home, work: store.work)
          : null;
      if (missing != null) {
        setState(
          () => _messages.add(
            _Message.needs(
              q,
              NeedsPlace(
                queryTh: kindLabel(context.l10n, missing),
                kind: missing,
              ),
            ),
          ),
        );
        return;
      }
      final currentOrigin = state.currentLocation?.ok == true
          ? Place(
              nameTh:
                  state.currentLocation!.nameTh ??
                  context.l10n.homeCurrentPlace,
              lat: state.currentLocation!.lat,
              lng: state.currentLocation!.lng,
            )
          : null;
      final d = state.track(
        await api.decide(
          DecideRequest(
            questionTh: q,
            tripId: widget.trip?.id,
            origin: widget.trip?.source == 'app'
                ? widget.trip!.origin
                : currentOrigin,
            destination: widget.trip?.source == 'app'
                ? widget.trip!.destination
                : null,
            places: places ?? store.places,
          ),
        ),
      );
      if (!mounted) return;
      setState(
        () => _messages.add(
          d.needsPlace != null
              ? _Message.needs(q, d.needsPlace!)
              : d.refused
              ? _Message.ai(d.summaryTh, null)
              : _Message.ai(d.summaryTh, d),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(_Message.failed(context.l10n.askFailed)));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    final motion = Motion.of(context);
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 200,
      duration: motion.d(Motion.enter),
      curve: Motion.standard,
    );
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final sky = state.flood ? SkyState.flood : SkyState.clear;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          SkyField(
            state: sky,
            height: double.infinity,
            child: SafeArea(
              bottom: false,
              child: FieldHeader(
                state: sky,
                back: true,
                title: context.l10n.askTitle,
                subtitle: widget.trip?.titleTh ?? context.l10n.appTitle,
                actions: [
                  if (state.usingSample)
                    const Padding(
                      padding: EdgeInsets.only(right: Space.x3),
                      child: SampleBadge(onField: true),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x4,
                Space.gutter,
                Space.x4,
              ),
              children: [
                for (final m in _messages)
                  if (m.needs != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x3),
                      child: NeedsPlacePass(
                        needs: m.needs!,
                        onResolved: (dest, places) => _ask(
                          m.text,
                          places: placesWithAnswer(m.needs!, dest, places),
                        ),
                      ),
                    )
                  else
                    _Bubble(
                      message: m,
                      onRetry: m.failed && _lastQuestion != null
                          ? () => _ask(_lastQuestion!)
                          : null,
                    ),
                if (_thinking)
                  const Padding(
                    padding: EdgeInsets.only(bottom: Space.x3),
                    child: Row(
                      children: [
                        GeminiMark(size: 18),
                        SizedBox(width: Space.x2),
                        Skeleton(width: 160),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: scheme.surfaceContainerLow,
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x3,
              Space.gutter,
              Space.x3 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final q in suggestedQuestions(context.l10n))
                      ActionChip(
                        label: Text(q),
                        onPressed: _asked.contains(q) || _thinking
                            ? null
                            : () => _ask(q),
                      ),
                  ],
                ),
                const SizedBox(height: Space.x3),
                AskBar(
                  onSubmit: _ask,
                  enabled: !_thinking,
                  hint: context.l10n.askInputHint,
                ),
                const SizedBox(height: Space.x2),
                Center(
                  child: Text(
                    context.l10n.askDisclaimer,
                    textAlign: TextAlign.center,
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});
  final _Message message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = FonColors.of(context);
    final d = message.decision;
    final maxW = MediaQuery.sizeOf(context).width * .86;

    if (message.mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          margin: const EdgeInsets.only(bottom: Space.x3),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x3,
          ),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Radii.lg),
              topRight: Radius.circular(Radii.lg),
              bottomLeft: Radius.circular(Radii.lg),
              bottomRight: Radius.circular(Radii.xs),
            ),
          ),
          child: Text(
            message.text,
            style: t.bodyLarge!.copyWith(color: scheme.onPrimary),
          ),
        ),
      );
    }

    if (d != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.x3),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW + 24),
          child: Pass(
            sections: [
              PassSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.headlineTh,
                      style: tabular(
                        t.headlineMedium!,
                      ).copyWith(color: c.paperInk),
                    ),
                    const SizedBox(height: Space.x2),
                    RiskChip(
                      risk: riskOfVerdict(d.verdict),
                      label: boardStatusText(
                        context.l10n,
                        d.verdict,
                        riskOfVerdict(d.verdict),
                      ),
                    ),
                    const SizedBox(height: Space.x3),
                    Text(
                      message.text,
                      style: t.bodyMedium!.copyWith(color: c.paperInk),
                    ),
                  ],
                ),
              ),
              PassSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConfidenceMeter(value: d.confidence),
                    const SizedBox(height: Space.x3),
                    GeneratedBy(d.generatedBy),
                    const SizedBox(height: Space.x2),
                    Text(
                      context.l10n.askDisclaimer,
                      style: t.labelSmall?.copyWith(color: c.paperMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: GeminiMark(size: 18),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: t.bodyLarge!.copyWith(
                    color: message.failed ? scheme.error : scheme.onSurface,
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: Text(context.l10n.askRetry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
