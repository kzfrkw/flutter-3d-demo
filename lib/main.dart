import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'check/check_mode.dart';
import 'check/check_page.dart';
import 'check/env_info.dart';
import 'check/flutter_scene_probe.dart';
import 'check/scene_probe.dart';
import 'office/data/dummy_office_data.dart';
import 'office/data/office_models.dart';
import 'office/guide/guide_memory.dart';
import 'office/office_page.dart';
import 'office/people/avatar_controller.dart';
import 'office/people/people_count.dart';
import 'office/people/people_simulation.dart';
import 'office/scene/camera_yaw.dart';
import 'office/scene/office_scene_builder.dart';
import 'office/scene/office_scene_view.dart';
import 'office/status/virtual_clock.dart';

void main() {
  final data = officeDataForUri(Uri.base, dummyOfficeData);
  // 3D(名札の位置)とカード(現在の行動)で同じシミュレーションを共有する。
  final sim = PeopleSimulation(data);
  // 仮想時刻はカード・3D パネル・部屋の床が同じ時計を読む。進めるのは 3D の描画。
  final clock = VirtualClock(
    cycleLength: data.cycleLength,
    start: parseVirtualTimeStart(Uri.base, data.cycleLength) ?? Duration.zero,
  );
  // 十字キーで動かす自分。3D(描画)とページ(キー入力)で同じものを共有する。
  final avatar = AvatarController.forOffice(data);
  runApp(
    App(
      checkMode: isCheckMode(Uri.base),
      probe: FlutterSceneProbe(),
      officeView: FlutterSceneOfficeView(
        simulation: sim,
        clock: clock,
        avatar: avatar,
        cameraYawDegrees: parseCameraYaw(Uri.base) ?? 0,
      ),
      officeData: data,
      simulation: sim,
      avatar: avatar,
      virtualTime: clock,
      // 案内を閉じたかはこのページを開いている間だけ覚える(保存・送信しない)。
      guideMemory: GuideMemory(),
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
    this.avatar,
    this.virtualTime,
    this.guideMemory,
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

  /// 十字キーで動かす自分。3D と共有する。null なら十字キーは何もしない。
  final AvatarController? avatar;

  /// 仮想時刻。null なら 0 秒固定。
  final ValueListenable<Duration>? virtualTime;

  /// 操作案内を閉じた記録。null なら OfficePage ごとに独立。
  final GuideMemory? guideMemory;

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
              avatar: avatar,
              virtualTime: virtualTime,
              guideMemory: guideMemory,
            ),
    );
  }
}
