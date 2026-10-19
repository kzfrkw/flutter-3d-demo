import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/office_scene_view.dart';

/// 受け取った引数を覚えるだけの偽の描画。[pick] で「3D 上で選んだ」を外から起こせる。
class FakeOfficeSceneView implements OfficeSceneView {
  OfficeData? received;
  ValueChanged<EntityRef?>? receivedOnPick;
  ValueListenable<Duration>? receivedVirtualTime;
  static const viewKey = Key('fake-office-view');

  /// 3D 上で対象(null なら背景)をタップしたことにする。
  void pick(EntityRef? ref) => receivedOnPick?.call(ref);

  @override
  Widget build(
    BuildContext context,
    OfficeData data, {
    ValueChanged<EntityRef?>? onPick,
    ValueListenable<Duration>? virtualTime,
  }) {
    received = data;
    receivedOnPick = onPick;
    receivedVirtualTime = virtualTime;
    return const SizedBox.expand(key: viewKey);
  }
}
