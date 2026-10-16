import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/check/check_page.dart';
import 'package:flutter_3d_demo/check/check_result.dart';
import 'package:flutter_3d_demo/check/env_info.dart';
import 'package:flutter_3d_demo/check/scene_probe.dart';
import 'package:flutter_test/flutter_test.dart';

/// 決まった結果を、ビューの組み立て後に報告する偽物。
class FakeProbe implements SceneProbe {
  FakeProbe(this.results);

  final Map<CheckItem, CheckResult> results;

  @override
  Widget buildView(BuildContext context, CheckReporter report) {
    Future.microtask(() {
      results.forEach(report);
    });
    return const SizedBox(key: Key('fake-view'), height: 100);
  }
}

Widget _wrap(SceneProbe probe) => MaterialApp(
  home: CheckPage(
    probe: probe,
    env: const EnvInfo(userAgent: 'TestAgent/1.0'),
  ),
);

void main() {
  testWidgets('報告前は 3 項目とも確認中で、ブラウザ・版の行がある', (tester) async {
    await tester.pumpWidget(_wrap(FakeProbe({})));

    expect(find.text('glTF 表示'), findsOneWidget);
    expect(find.text('3D 面にウィジェット埋め込み'), findsOneWidget);
    expect(find.text('アニメ再生'), findsOneWidget);
    expect(find.text('確認中'), findsNWidgets(3));
    expect(find.text('ブラウザ・版'), findsOneWidget);
    expect(find.textContaining('TestAgent/1.0'), findsOneWidget);
    expect(find.textContaining('flutter_scene 0.24.3'), findsOneWidget);
    expect(find.byKey(const Key('fake-view')), findsOneWidget);
  });

  testWidgets('OK と NG が文言で表示され、NG は理由も表示される', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FakeProbe({
          CheckItem.gltf: const CheckResult.ok(),
          CheckItem.widgetEmbed: const CheckResult.ng('boom: embed failed'),
          CheckItem.animation: const CheckResult.ok(),
        }),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('OK'), findsNWidgets(2));
    expect(find.text('NG'), findsOneWidget);
    expect(find.text('確認中'), findsNothing);
    expect(find.textContaining('boom: embed failed'), findsOneWidget);
  });
}
