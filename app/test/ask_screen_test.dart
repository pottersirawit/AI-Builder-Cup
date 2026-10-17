import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/config.dart';
import 'package:fontokmai/design/design.dart';
import 'package:fontokmai/models.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers.dart';

void main() {
  testWidgets('ask screen displays guardrail refusal as plain chat bubble without pass card', (
    tester,
  ) async {
    const refusalText =
        'ขออภัยด้วยครับ มิวสามารถช่วยตอบได้เฉพาะเรื่องการเดินทาง สภาพอากาศ น้ำท่วม และเส้นทางของทริปนี้เท่านั้นครับ';

    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      demoLaunch: const DemoLaunch(screen: 'ask'),
      respond: (req) {
        if (req.url.path == '/v1/decide') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final q = body['question_th'] as String? ?? '';
          if (q.contains('เบอร์เกอร์') || q.contains('burger') || q.contains('Ignore')) {
            return jsonResponse({
              'verdict': 'wait',
              'headline_th': 'คำถามไม่เกี่ยวข้องกับทริป',
              'summary_th': refusalText,
              'confidence': 0,
              'sources': ['Fontokmai Trip Guardrail'],
              'generated_by': 'fallback',
              'refused': true,
              'reasoning': [
                {
                  'tool': 'guardrail_unrelated_question',
                  'summary_th': 'คำถามไม่เกี่ยวข้องกับการเดินทาง',
                },
              ],
            });
          }
        }
        return null;
      },
    );

    // Initial message from AI is visible.
    expect(find.textContaining('ออกก่อน 16:45'), findsOneWidget);

    // Enter unrelated question in AskBar.
    await tester.enterText(find.byType(TextField), 'ขอสูตรทำเบอร์เกอร์หน่อย');
    await tester.tap(find.byIcon(Symbols.arrow_upward_rounded));
    await settle(tester);

    // User's question is displayed.
    expect(find.text('ขอสูตรทำเบอร์เกอร์หน่อย'), findsOneWidget);

    // Refusal message is displayed.
    expect(find.text(refusalText), findsOneWidget);

    // Pass ticket and RiskChip must NOT be shown for the refusal!
    expect(find.byType(Pass), findsNothing);
    expect(find.byType(RiskChip), findsNothing);
  });

  testWidgets('ask screen displays pass card when question is related to the trip', (
    tester,
  ) async {
    final validDecision =
        jsonDecode(File('assets/fixtures/decide_question.json').readAsStringSync())
            as Map<String, dynamic>;

    await pumpApp(
      tester,
      '2026-09-29T16:10:00+07:00',
      demoLaunch: const DemoLaunch(screen: 'ask'),
      respond: (req) {
        if (req.url.path == '/v1/decide') {
          return jsonResponse(validDecision);
        }
        return null;
      },
    );

    // Enter related question.
    await tester.enterText(find.byType(TextField), 'ไปลาดพร้าวตอนทุ่มนึงดีไหม');
    await tester.tap(find.byIcon(Symbols.arrow_upward_rounded));
    await settle(tester);

    // User's question is displayed.
    expect(find.text('ไปลาดพร้าวตอนทุ่มนึงดีไหม'), findsOneWidget);

    // Pass card is rendered for legitimate trip query.
    expect(find.byType(Pass), findsOneWidget);
    expect(find.text(validDecision['headline_th'] as String), findsOneWidget);
  });
}
