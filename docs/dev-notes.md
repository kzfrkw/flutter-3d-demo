# 開発記録(F0 / s0-check)

後で s5-notes / F8 に転記する元の記録。

## 使用版

| 項目 | 版 |
|---|---|
| Flutter | 3.47.7(stable、framework abaf9c5、engine deb2874) |
| Dart | 3.13.5 |
| flutter_scene | 0.24.3(`pubspec.yaml` で完全固定、`pubspec.lock` も 0.24.3) |
| vector_math | ^2.2.0(lock は 2.4.3。flutter_scene と同じ型を使うため直接依存にした) |

## s0-check の結果

確認日 2026-10-16、ブラウザ Chrome(`flutter run -d chrome`、`?check`)。人の目視。

| 項目 | 結果 | 備考 |
|---|---|---|
| glTF 表示 | OK | 箱が 1 つ見えた |
| 3D 面にウィジェット埋め込み | NG(2回目の修正後も未解決)→3回目の修正済み(要再確認) | 初回は「Hello Widget」が反転して見えた。自動判定は OK だったが見た目と不一致 |
| アニメ再生 | OK | 箱が回った |

- 経過: カメラ z=-4 では「Hello Widget」が反転して見えた(NG)。カメラを z=+4 に移すと、今度はパネルが見えなくなった(裏面カリング。人の目視 2026-10-17)。
- 3回目の修正: カメラを z=-4 に戻し、U を左右逆にした四角形(`_mirroredQuad`)を渡して反転を直した。Chrome での再確認は人が行い、この表を更新する。直らなければ代替案(F4 の 2D オーバーレイ化)を採り、依頼者に報告する。
- 以前の推定(誤り): 反転の原因: `WidgetComponent` の面は +Z 向きだが、カメラを z=-4 に置いて裏から見ていた。カメラを z=+4 に移して修正した(テクスチャの上下の問題ではなく面の向き)。修正後の Chrome での再確認は人が行い、この表を更新する。
- 教訓: 埋め込みウィジェットの面は +Z 向き。F4 のパネルはカメラ側が +Z になるように置く。裏から見ると左右反転する。
- 自動判定の基準: glTF はメッシュを持つノードが得られたら OK。埋め込みはウィジェットのテクスチャが得られたら OK(10 秒で NG)。アニメは再生時刻が進んだら OK(10 秒で NG)。自動で OK でも目で見えなければ NG とする。
- 未検証: 骨格アニメ(回転する箱のみ確認)。F3 に影響するため依頼者に報告する。
- 代替案(F4 の 2D オーバーレイ化)は、向きの修正で表示できれば不要。修正後も NG なら下記を採る。

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
