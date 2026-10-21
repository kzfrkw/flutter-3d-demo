import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/guide/operation_guide.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> pumpGuide(WidgetTester tester) async {
  final closed = <int>[];
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OperationGuideOverlay(onClose: () => closed.add(1)),
      ),
    ),
  );
  return closed;
}

void main() {
  testWidgets('デモが示すことと操作方法(AC4)', (tester) async {
    await pumpGuide(tester);
    expect(find.text(guideTitle), findsOneWidget);
    expect(find.text('このデモでわかること'), findsOneWidget);
    expect(find.textContaining('歩く'), findsOneWidget);
    expect(find.textContaining('Flutter ウィジェット'), findsOneWidget);
    expect(find.byKey(const Key('guide-op-drag')), findsOneWidget);
    expect(find.byKey(const Key('guide-op-wheel')), findsOneWidget);
    expect(find.byKey(const Key('guide-op-right-drag')), findsOneWidget);
    expect(find.byKey(const Key('guide-op-click')), findsOneWidget);
    expect(find.textContaining('ドラッグ'), findsWidgets);
    expect(find.textContaining('ホイール'), findsWidgets);
    expect(find.textContaining('クリック'), findsWidgets);
  });

  testWidgets('ホットリロードの一文とファイル名(AC5)', (tester) async {
    await pumpGuide(tester);
    expect(find.textContaining('ホットリロード'), findsOneWidget);
    expect(find.textContaining('status_style.dart'), findsOneWidget);
    expect(find.textContaining('office_layout.dart'), findsOneWidget);
    expect(File('lib/office/status_style.dart').existsSync(), isTrue);
    expect(File('lib/office/scene/office_layout.dart').existsSync(), isTrue);
  });

  testWidgets('案内に状態の文言を入れない', (tester) async {
    await pumpGuide(tester);
    for (final w in ['空き', '使用中', '在席', '離席', '歩行中', '停止中']) {
      expect(find.textContaining(w), findsNothing);
    }
  });

  testWidgets('はじめる・×・外側クリックで 1 回ずつ閉じる。中のクリックでは閉じない(AC1)', (tester) async {
    var closed = await pumpGuide(tester);
    await tester.tap(find.text(guideStartLabel));
    expect(closed, hasLength(1));

    closed = await pumpGuide(tester);
    await tester.tap(find.byKey(const Key('guide-close-button')));
    expect(closed, hasLength(1));

    closed = await pumpGuide(tester);
    await tester.tapAt(const Offset(5, 5));
    expect(closed, hasLength(1));

    closed = await pumpGuide(tester);
    await tester.tap(find.text(guideTitle));
    expect(closed, isEmpty);
  });

  testWidgets('スマホ幅でも [×] が見え、あふれない', (tester) async {
    final closed = await pumpGuide(tester);
    tester.view.physicalSize = const Size(390, 700);
    await tester.pump();
    expect(find.byKey(const Key('guide-close-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(closed, isEmpty);
  });
}
