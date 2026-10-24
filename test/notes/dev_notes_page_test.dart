import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_demo/notes/dev_notes_page.dart';
import 'package:flutter_3d_demo/notes/markdown_lite.dart';
import 'package:flutter_test/flutter_test.dart';

final notes = File('docs/dev-notes.md').readAsStringSync();

Future<void> pumpNotes(
  WidgetTester tester, {
  Size size = const Size(1000, 700),
  Future<String> Function()? body,
  VoidCallback? onBack,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DevNotesPage(loader: body ?? () => Future.value(notes)),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('先頭に「← デモに戻る」があり、押すと戻る', (tester) async {
    await pumpNotes(tester);
    expect(find.text(backToDemoLabel), findsOneWidget);
    expect(find.text('open'), findsNothing);
    await tester.tap(find.text(backToDemoLabel));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('open'), findsOneWidget);
    expect(find.text(backToDemoLabel), findsNothing);
  });

  testWidgets('Tab → Enter で戻れる', (tester) async {
    await pumpNotes(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('7 つの見出しがこの順で出る', (tester) async {
    await pumpNotes(tester);
    final h2 = parseMarkdownLite(notes)
        .whereType<MdHeading>()
        .where((h) => h.level == 2)
        .take(7)
        .toList();
    var lastY = -1.0;
    for (final h in h2) {
      final f = find.text(h.text, skipOffstage: false);
      expect(f, findsOneWidget, reason: h.text);
      final y = tester.getTopLeft(f).dy;
      expect(y, greaterThan(lastY), reason: h.text);
      lastY = y;
    }
    expect(find.text('開発記録'), findsOneWidget);
  });

  testWidgets('375px で全文を最後までスクロールしても overflow しない', (tester) async {
    await pumpNotes(tester, size: const Size(375, 700));
    expect(tester.takeException(), isNull);
    final scroll = find.byType(SingleChildScrollView).first;
    for (var i = 0; i < 80; i++) {
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('読み込み失敗ではエラー表示と戻る行が出る', (tester) async {
    await pumpNotes(tester, body: () => Future<String>.error('x'));
    expect(find.text('開発記録を読み込めませんでした'), findsOneWidget);
    expect(find.text(backToDemoLabel), findsOneWidget);
  });

  testWidgets('本文が空でもエラー表示', (tester) async {
    await pumpNotes(tester, body: () => Future.value(''));
    expect(find.text('開発記録を読み込めませんでした'), findsOneWidget);
  });
}
