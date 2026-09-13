// Plan/32b — AgentMarkdown renders fenced code with a copy button.

import 'package:app/ui/chat/widgets/agent_markdown.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  Future<void> pump(WidgetTester tester, String md) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AgentMarkdown(md))),
    );
  }

  testWidgets('fenced code block shows a copy button', (tester) async {
    await pump(tester, '```dart\nfinal x = 1;\n```');
    await tester.pump();
    expect(find.byKey(const Key('code-copy')), findsOneWidget);
    expect(find.textContaining('final x = 1;'), findsOneWidget);
  });

  testWidgets('tapping copy puts the code on the clipboard', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, '```\nhello code\n```');
    await tester.pump();
    await tester.tap(find.byKey(const Key('code-copy')));
    await tester.pump();

    expect(calls, isNotEmpty, reason: 'Clipboard.setData was invoked');
    final text = (calls.first.arguments as Map)['text'] as String;
    expect(text, contains('hello code'));
  });

  testWidgets('plain prose renders without a code block', (tester) async {
    await pump(tester, 'just a normal sentence.');
    await tester.pump();
    expect(find.byKey(const Key('code-copy')), findsNothing);
  });

  // Issue #184 — headings used to fall back to Material's TextTheme (h2 = 28pt
  // vs a 12.5pt body), which the #114 text-size setting then scaled into 36pt
  // headings at XL.
  group('heading typography (#184)', () {
    Iterable<TextStyle?> allHeadings(GptMarkdownThemeData t) =>
        [t.h1, t.h2, t.h3, t.h4, t.h5, t.h6];

    test('headings stay proportionate to the mono body', () {
      final typo = AppTypography.dark;
      final md = buildMarkdownTheme(
        typo: typo,
        brightness: Brightness.dark,
      );
      final body = typo.mono.fontSize!;

      for (final style in allHeadings(md)) {
        // Never smaller than the prose it heads…
        expect(style!.fontSize!, greaterThanOrEqualTo(body));
        // …and never more than 1.4× it. Material's headlineMedium (28) was
        // 2.24× and is exactly the bug.
        expect(style.fontSize!, lessThanOrEqualTo(body * 1.4));
      }

      // Still a descending scale, so `#` outranks `######`.
      expect(md.h1!.fontSize!, greaterThan(md.h2!.fontSize!));
      expect(md.h2!.fontSize!, greaterThan(md.h3!.fontSize!));
      expect(md.h3!.fontSize!, greaterThan(md.h4!.fontSize!));
    });

    test('headings use the app mono family, not the platform sans', () {
      final md = buildMarkdownTheme(
        typo: AppTypography.dark,
        brightness: Brightness.dark,
      );
      for (final style in allHeadings(md)) {
        expect(style!.fontFamily, kMonoFamily);
      }
    });

    testWidgets('AgentMarkdown installs the markdown theme', (tester) async {
      await pump(tester, '## Heading');
      final theme = tester.widget<GptMarkdownTheme>(
        find.byType(GptMarkdownTheme),
      );
      expect(theme.gptThemeData.h2!.fontFamily, kMonoFamily);
      expect(theme.gptThemeData.h2!.fontSize, 15.5);
    });
  });
}
