import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const suggestedQuestions = ['ถ้ารอถึงสองทุ่มค่อยกลับล่ะ', 'ไป BTS แทนดีไหม'];

class _Message {
  const _Message.me(this.text)
      : mine = true,
        decision = null;
  const _Message.ai(this.text, [this.decision]) : mine = false;
  final bool mine;
  final String text;
  final Decision? decision;
}

/// Chat-style follow-up: each question is POSTed to /v1/decide as question_th.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, this.trip, this.opening});
  final Trip? trip;

  /// Current headline, used in the opening message.
  final String? opening;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late final List<_Message> _messages = [
    _Message.ai(widget.opening == null
        ? 'อยากรู้อะไรเรื่องฝนกับการเดินทาง ถามได้เลย'
        : 'ตอนนี้แนะนำ “${widget.opening}” นะ มีอะไรอยากถามต่อไหม'),
  ];
  final _asked = <String>{};
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    q = q.trim();
    if (q.isEmpty || _thinking) return;
    final api = AppScope.apiOf(context);
    final state = AppScope.readState(context);
    setState(() {
      _messages.add(_Message.me(q));
      _asked.add(q);
      _thinking = true;
    });
    _input.clear();
    _scrollToEnd();
    final d = state.track(await api.decide(DecideRequest(questionTh: q, tripId: widget.trip?.id)));
    if (!mounted) return;
    setState(() {
      _messages.add(_Message.ai(d.summaryTh, d));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ClockBar(),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Logo(label: 'ถามต่อ'),
                  Positioned(
                    left: 4,
                    child: TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: Text('‹ กลับ', style: txt(context, weight: FontWeight.w600, color: p.accent)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  for (final m in _messages) _Bubble(message: m),
                  if (_thinking) const _Bubble(message: _Message.ai('กำลังคิด…')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final q in suggestedQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _asked.contains(q) || _thinking ? null : () => _ask(q),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          side: BorderSide(color: p.accent, width: 1.5),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        child: Text(q, style: txt(context, size: 13, weight: FontWeight.w600, color: p.accent)),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          onSubmitted: _ask,
                          textInputAction: TextInputAction.send,
                          style: txt(context),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'พิมพ์คำถาม เช่น ถ้าไปมอเตอร์ไซค์ล่ะ',
                            hintStyle: txt(context, color: const Color(0xFF8A99B3)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'ส่ง',
                        onPressed: _thinking ? null : () => _ask(_input.text),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final d = message.decision;
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? kBlue : p.card,
          border: mine ? null : Border.all(color: p.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d != null) ...[
              Row(
                children: [
                  Flexible(
                    child: Text(d.headlineTh,
                        style: txt(context, weight: FontWeight.w700, color: Tone.ofVerdict(d.verdict).fg)),
                  ),
                  const SizedBox(width: 8),
                  Pill('มั่นใจ ${percent(d.confidence)}', tone: Tone.ofVerdict(d.verdict)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(message.text,
                style: txt(context, height: 1.5, color: mine ? Colors.white : p.ink)),
            if (d != null)
              SourceLabel('${d.generatedBy == 'fallback' ? 'กฎสำรอง' : 'Gemini'} · ${d.sources.join(' · ')}'),
          ],
        ),
      ),
    );
  }
}
