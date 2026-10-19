import 'package:flutter/material.dart';

import 'check/check_mode.dart';
import 'check/check_page.dart';
import 'check/env_info.dart';
import 'check/flutter_scene_probe.dart';
import 'check/scene_probe.dart';
import 'office/data/dummy_office_data.dart';
import 'office/data/office_models.dart';
import 'office/office_page.dart';
import 'office/people/people_count.dart';
import 'office/people/people_simulation.dart';
import 'office/scene/camera_yaw.dart';
import 'office/scene/office_scene_builder.dart';
import 'office/scene/office_scene_view.dart';

void main() {
  final data = officeDataForUri(Uri.base, dummyOfficeData);
  // 3D(名札の位置)とカード(現在の行動)で同じシミュレーションを共有する。
  final sim = PeopleSimulation(data);
  runApp(
    App(
      checkMode: isCheckMode(Uri.base),
      probe: FlutterSceneProbe(),
      officeView: FlutterSceneOfficeView(
        simulation: sim,
        cameraYawDegrees: parseCameraYaw(Uri.base) ?? 0,
      ),
      officeData: data,
      simulation: sim,
    ),
  );
}

class App extends StatelessWidget {
  const App({
    super.key,
    required this.checkMode,
    required this.probe,
    required this.officeView,
    this.officeData,
    this.simulation,
  });

  /// URL に `?check` があるか。true なら s0-check を表示する。
  final bool checkMode;
  final SceneProbe probe;

  /// s1-office の 3D 描画。
  final OfficeSceneView officeView;

  /// null なら [dummyOfficeData]。
  final OfficeData? officeData;

  /// 3D と共有する人の動き。カードの「現在の行動」が読む。
  final PeopleSimulation? simulation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 3D Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
      home: checkMode
          ? CheckPage(probe: probe, env: EnvInfo.current())
          : OfficePage(
              view: officeView,
              data: officeData ?? dummyOfficeData,
              simulation: simulation,
            ),
    );
  }
}
