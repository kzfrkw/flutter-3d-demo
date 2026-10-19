import 'package:flutter/widgets.dart';

import '../data/office_models.dart';

/// 3D のオフィスを描く部分の差し替え口。
/// 本物は flutter_scene(`FlutterSceneOfficeView`)、テストでは偽物を使う。
abstract class OfficeSceneView {
  /// 3D のオフィスを表すウィジェットを作る。親が与える制約いっぱいに広がること。
  Widget build(BuildContext context, OfficeData data);
}
