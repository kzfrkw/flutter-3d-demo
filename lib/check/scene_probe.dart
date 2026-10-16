import 'package:flutter/widgets.dart';

import 'check_result.dart';

typedef CheckReporter = void Function(CheckItem item, CheckResult result);

/// 3D 描画の検証を行う差し替え口。本物は flutter_scene を呼び、
/// テストでは決まった結果を返す偽物を使う。
abstract class SceneProbe {
  /// 検証用の 3D ビューを作る。検証が進むたびに [report] で結果を知らせる。
  Widget buildView(BuildContext context, CheckReporter report);
}
