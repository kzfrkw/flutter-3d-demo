import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/check/check_page.dart';
import 'package:flutter_3d_demo/check/check_result.dart';
import 'package:flutter_3d_demo/check/scene_probe.dart';
import 'package:flutter_3d_demo/main.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'office/fake_office_scene_view.dart';

class _NoopProbe implements SceneProbe {
  @override
  Widget buildView(BuildContext context, CheckReporter report) =>
      const SizedBox.shrink();
}

void main() {
  testWidgets('check なしでは s1-office を表示する', (tester) async {
    final fake = FakeOfficeSceneView();
    await tester.pumpWidget(
      App(checkMode: false, probe: _NoopProbe(), officeView: fake),
    );

    expect(find.byType(OfficePage), findsOneWidget);
    expect(find.textContaining('ダミーデータ'), findsOneWidget);
    expect(find.text('準備中'), findsNothing);
    expect(find.byType(CheckPage), findsNothing);
    expect(identical(fake.received, dummyOfficeData), isTrue);
  });

  testWidgets('check ありでは s0-check を表示する', (tester) async {
    await tester.pumpWidget(
      App(
        checkMode: true,
        probe: _NoopProbe(),
        officeView: FakeOfficeSceneView(),
      ),
    );

    expect(find.byType(CheckPage), findsOneWidget);
    expect(find.byType(OfficePage), findsNothing);
    expect(CheckItem.values, hasLength(3));
  });
}
