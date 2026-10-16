import 'package:flutter/widgets.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/office_scene_view.dart';

/// 受け取った [OfficeData] を覚えるだけの偽の描画。
class FakeOfficeSceneView implements OfficeSceneView {
  OfficeData? received;
  static const viewKey = Key('fake-office-view');

  @override
  Widget build(BuildContext context, OfficeData data) {
    received = data;
    return const SizedBox.expand(key: viewKey);
  }
}
