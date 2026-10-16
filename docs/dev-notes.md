# 開発記録(F0 / s0-check)

後で s5-notes / F8 に転記する元の記録。

## 使用版

| 項目 | 版 |
|---|---|
| Flutter | 3.47.7(stable、framework abaf9c5、engine deb2874) |
| Dart | 3.13.5 |
| flutter_scene | 0.24.3(`pubspec.yaml` で完全固定、`pubspec.lock` も 0.24.3) |
| vector_math | ^2.2.0(lock は 2.4.3。flutter_scene と同じ型を使うため直接依存にした) |

## 依頼者への報告

**全項目 OK。代替案は不要。** ただし骨格アニメは未検証(回転する箱のみ確認)。F3(歩く人)に直結するため、必要なら CC0 の骨格アニメ付きモデルで別途検証する。

## s0-check の結果

確認日 2026-10-16〜17、ブラウザ Chrome(`flutter run -d chrome`、`?check`)。Chrome の版は未記録。人の目視。

| 項目 | 結果 | 備考 |
|---|---|---|
| glTF 表示 | OK | 箱が 1 つ見えた |
| 3D 面にウィジェット埋め込み | OK | 3回目の修正(UV 反転した四角形)後、人が「確認できました」(2026-10-17)。「Hello Widget」が見える |
| アニメ再生 | OK | 箱が回った |

- 経過: カメラ z=-4 では「Hello Widget」が左右反転して見えた。カメラを z=+4 に移すと、裏面カリングで見えなくなった。z=-4 に戻し、U を左右逆にした四角形(`_mirroredQuad`)を渡して直った。
- 教訓: 埋め込みウィジェットの面は、-Z 側から見える(+Z 側からは裏面カリングで見えない)。かつ UV の左右が逆なので、F4 では `_mirroredQuad` 相当のジオメトリを使い、カメラ側が -Z になるように置く。
- 自動判定の基準: glTF はメッシュを持つノードが得られたら OK。埋め込みはウィジェットのテクスチャが得られたら OK(10 秒で NG)。アニメは再生時刻が進んだら OK(10 秒で NG)。自動で OK でも向きや可視性は検出できないため、目視を必須とし、見えなければ NG とする。
- 未検証: 骨格アニメ。

## NG のときの代替案

- 埋め込みが NG: F4(名札・会議室パネル)を、3D 座標から画面座標に投影した 2D オーバーレイ(Scene の上に `Stack` と `Positioned` を重ねる)にする。データや画面の構成は変えない(structure.md 第4章)。
- アニメが NG: 骨格アニメを使わず、ノードの移動・回転の補間だけで「歩く」ように見せる(カプセルでの代用と組み合わせる)。
- glTF が NG: 箱とカプセル(プリミティブ)で組む。flutter_scene が Web で描画できない場合は「Web で作る」決定の見直しになるため、作り込まず依頼者に報告する。

## つまずいた点

- 導入: `flutter pub add flutter_scene:0.24.3` →`dart run flutter_scene:init`(エージェント用スキルは入れない)。`init` が `hook/build.dart`・`flutter_scene_generated/`・pubspec の assets 項目・`analysis_options.yaml` を足す。
- `flutter_scene/scene.dart` は `Material` を export するため、`package:flutter/material.dart` と併用するときは `hide Material` が要る。
- `hook/build.dart` は `hooks` を直接依存にしていないため lint が出る。`analysis_options.yaml` で `hook/**` を除外した。
- Web のユーザーエージェントは `dart:js_interop` で取る(`package:web` を足さない)。
- 実装者のサンドボックスでは `pub.dev` の名前解決ができず `flutter test` / `flutter pub get` が失敗した。`flutter pub get --offline`(キャッシュ済み)のあと `flutter test --no-pub` で実行した。

## 素材の出典とライセンス

- `assets/models/check_cube.glb`: `tool/make_check_model.py` で自作した、回転アニメ(`Spin`)付きの橙色の箱。**CC0 1.0**(第三者の素材を含まない)。再生成は `python3 tool/make_check_model.py`。
- 骨格アニメ付きの CC0 モデルは未入手。骨格アニメの検証は、必要なら別途 CC0 の素材を入れて行う(今回の「アニメ再生」はノードのアニメーションの検証)。
