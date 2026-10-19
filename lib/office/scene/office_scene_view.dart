import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/office_models.dart';

/// 3D のオフィスを描く部分の差し替え口。
/// 本物は flutter_scene(`FlutterSceneOfficeView`)、テストでは偽物を使う。
abstract class OfficeSceneView {
  /// 3D のオフィスを表すウィジェットを作る。親が与える制約いっぱいに広がること。
  ///
  /// [onPick]: 3D 上でタップした結果。対象に当たれば EntityRef、何も無い所・床・外壁なら
  /// null(背景)。描画側は選択中がどれかを知らない(通知だけ)。
  /// [virtualTime]: 仮想時刻。会議室パネルの空き/使用中に使う。null なら Duration.zero 固定。
  Widget build(
    BuildContext context,
    OfficeData data, {
    ValueChanged<EntityRef?>? onPick,
    ValueListenable<Duration>? virtualTime,
  });
}
