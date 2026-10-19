import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/scene/scene_loading.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SceneLoading', () {
    testWidgets('進捗と「素材を読み込み中」。10 秒未満は補足なし、超えると補足あり', (tester) async {
      await tester.pumpWidget(_wrap(const SceneLoading()));
      expect(find.text(SceneLoading.message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(SceneLoading.slowMessage), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text(SceneLoading.slowMessage), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(SceneLoading.slowMessage), findsOneWidget);
      expect(find.text(SceneLoading.message), findsOneWidget);
    });

    testWidgets('dispose のあとタイマーが残らない', (tester) async {
      await tester.pumpWidget(_wrap(const SceneLoading()));
      await tester.pumpWidget(_wrap(const SizedBox()));
      // タイマーが残っていればテスト終了時に失敗する。
      await tester.pump(const Duration(seconds: 20));
    });
  });

  group('SceneErrorView', () {
    for (final kind in SceneLoadFailureKind.values) {
      testWidgets('$kind: 原因・案内・再読み込み', (tester) async {
        var reloaded = 0;
        final failure = SceneLoadFailure(kind);
        await tester.pumpWidget(
          _wrap(SceneErrorView(failure: failure, onReload: () => reloaded++)),
        );
        expect(find.text(failure.cause), findsOneWidget);
        expect(find.text(SceneErrorView.guidance), findsOneWidget);
        expect(find.text('Chrome 最新版でお試しください'), findsOneWidget);
        await tester.tap(find.text(SceneErrorView.reloadLabel));
        expect(reloaded, 1);
      });
    }

    test('原因の文言は種類で異なる', () {
      expect(
        const SceneLoadFailure(SceneLoadFailureKind.webgl2Unsupported).cause,
        isNot(const SceneLoadFailure(SceneLoadFailureKind.loadFailed).cause),
      );
    });

    testWidgets('詳細は detail があるときだけ', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SceneErrorView(
            failure: const SceneLoadFailure(SceneLoadFailureKind.loadFailed),
            onReload: () {},
          ),
        ),
      );
      expect(find.textContaining('詳細'), findsNothing);
      await tester.pumpWidget(
        _wrap(
          SceneErrorView(
            failure: const SceneLoadFailure(
              SceneLoadFailureKind.loadFailed,
              detail: 'Exception: boom',
            ),
            onReload: () {},
          ),
        ),
      );
      expect(find.textContaining('詳細: Exception: boom'), findsOneWidget);
    });
  });
}
