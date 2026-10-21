import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/check/check_page.dart';
import 'package:flutter_3d_demo/check/check_result.dart';
import 'package:flutter_3d_demo/check/scene_probe.dart';
import 'package:flutter_3d_demo/main.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/guide/guide_memory.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
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

  testWidgets('App が持つ PeopleSimulation が OfficePage とカードに届く', (tester) async {
    final sim = PeopleSimulation(dummyOfficeData);
    final fake = FakeOfficeSceneView();
    await tester.pumpWidget(
      App(
        checkMode: false,
        probe: _NoopProbe(),
        officeView: fake,
        simulation: sim,
      ),
    );
    expect(
      identical(
        tester.widget<OfficePage>(find.byType(OfficePage)).simulation,
        sim,
      ),
      isTrue,
    );
    fake.pick(const EntityRef(EntityKind.person, 'person-a'));
    await tester.pump();
    expect(find.text(PersonActivity.stopped.label), findsOneWidget);
    sim.step(0.1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(PersonActivity.walking.label), findsOneWidget);
    fake.pick(null);
    await tester.pump();
  });

  testWidgets('App の guideMemory が OfficePage に届く', (tester) async {
    final memory = GuideMemory(dismissed: true);
    await tester.pumpWidget(
      App(
        checkMode: false,
        probe: _NoopProbe(),
        officeView: FakeOfficeSceneView(),
        guideMemory: memory,
      ),
    );
    expect(
      identical(
        tester.widget<OfficePage>(find.byType(OfficePage)).guideMemory,
        memory,
      ),
      isTrue,
    );
    expect(find.byKey(const Key('guide-start-button')), findsNothing);
  });
}
