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
- s1-office のオフィスは flutter_scene の `CuboidGeometry`(箱)で構成。第三者の素材なし(CC0 の家具モデルは使っていない)。
- 骨格アニメ付きの CC0 モデルは未入手。骨格アニメの検証は、必要なら別途 CC0 の素材を入れて行う(今回の「アニメ再生」はノードのアニメーションの検証)。

## 歩く人(T3 / F2)

- 表し方: 骨格アニメ付きの人物モデルは素材が無い(外部から取らない)ため使わず、カプセル(高さ 1.6m・半径 0.25m)+前方の小さな箱(鼻)で表す。「歩行アニメ」は歩いた距離に連動した上下の揺れ(`bob`)と左右の傾き(`lean`)で代用した。向きは鼻で分かる。Node の name は `<personId>#body` / `<personId>#nose`。
- 動き: `lib/office/people/people_simulation.dart`(純 Dart)が Route の waypoint を順にたどる。壁・机を避ける仕組みは実行時の当たり判定ではなく、「経路は neighbors のグラフ上だけ」+「グラフの辺が壁・机から人の半径ぶん離れている」ことをテスト(`people_walk_test.dart`)で保証する方式。既定データは Waypoint の座標を直さずに通った。
- 向き: 目標の waypoint への方向 `atan2(dx, dz)` に、最大角速度 12 rad/s で近づける(折り返しも約 0.26 秒で一致)。
- 停滞時の再設定: 3 秒ごとの窓で歩いた距離が 0.5m 未満なら、今向かっている waypoint(無効な Route なら立っている waypoint)から、到達できる別の waypoint へ幅優先探索の最短経路を作り、往復の周回に差し替える。直線で近い点へは向かわない(壁を抜けるため)。通常データでは起きない保険。
- 10 人: `?people=10`(`people_count.dart`)で、追加の 4 人(席なし、既存の Waypoint をつなぐ Route)を足した OfficeData を渡す。
- fps の実測(AC13): **未測定**。実装者の環境では Chrome を起動できず、QA または人の確認で測る。測ったら環境と値をここに書く。目安 30fps を割る場合は、鼻の Node を省く → カプセルの分割数(16/4)を減らす、の順に試す。
- つまずき: ツールの `flutter test` は pub.dev に接続しようとして失敗する。実装者は `XDG_CONFIG_HOME` を一時ディレクトリにして `flutter pub get --offline` のあと `flutter test --no-pub` / `flutter analyze --no-pub` を Bash で実行した。

## 3D 面上ウィジェットと情報カード(T4 / F4, F3)

- 方式: 名札・会議室パネルは flutter_scene の `WidgetComponent`(`input: manual`、更新は 500ms 間隔)。T1 の教訓どおり、四角形は UV を左右逆にした `_mirroredQuad`(builder に複製)で、面の表は **ローカル -Z 側**。2D オーバーレイの代替は使っていない。
- ノード名の規約: 既存の `<entityId>#<部位>` に `<personId>#tag`(名札)・`<roomId>#panel`(パネル)を追加。`entity_pick.dart` が `#` より前の id をデータの表(人 → 席 → 会議室)で引いて `EntityRef` にする(部位名は解釈しない)。床・外壁・データに無い id は null = 背景。
- ビルボード: 名札・パネルは人の子ではなく別 Node(`labels`)。毎フレーム「位置を写す + `rotateY(billboardYaw(forward.x, forward.z))`」。正射影カメラなので `camera.forward` の水平成分を全ラベル共通で使う(`billboardYaw = atan2(dx, dz)`)。
- 選択: `EntityRef?` を OfficePage が 1 つ持つ(`_select` が唯一の更新口)。3D は `OfficeSceneView.build` の省略可の `onPick` で通知。タップは `GestureDetector` → `camera.screenPointToRay` → `Scene.raycast` → ノード名。T6 の一覧も `_select` を呼べばよい。
- カード: Stack で 3D の上に重ねる(3D を縮めない)。幅 600 未満(`officeNarrowBreakpoint`)は下シート(本体の 40%)、以上は右パネル(900 未満 320、以上 360)。`showModalBottomSheet` は 3D のタップを奪うので使わない。開いている間だけ 250ms の Timer で歩行中/停止中などを読み直す。
- 色: 会議室の 2 状態は固定色で `lib/office/status_style.dart` の 1 か所(パネルとカードのピルが共有)。文言は `office_status.dart` の列挙の `label` だけ。
- 視点指定(開発者用): `?cameraYaw=<度>`。0 = 手前(-Z 側)、90 = -X 側、180 = 奥(+Z 側)、-90 = +X 側。`rotateAboutY` のテストで固定。
- 制約: 3D 上の選択はマウス・タッチ専用(キーボードだけで選ぶ手段は T6 の一覧で提供)。3D 面の名札・パネルはテクスチャなので読み上げ対象外(同じ情報はカードで読める)。席は既定データでは全員「離席」(座る動きが無い)。
- 未確認(QA で確かめる): WidgetComponent の板が `Scene.raycast` に当たるか(当たらなくても人・席・壁は当たる)、名札の文字の読みやすさ・左右反転、Esc がキャンバスにフォーカスがあっても効くか、4 方向の視点でのビルボード。
- つまずき: ツールの `flutter test` が最初は pub.dev に接続しようとして失敗した。`XDG_CONFIG_HOME` を一時ディレクトリにして `flutter pub get --offline` を実行したあとはツール経由でも通った。

## カメラ操作・状態の動的変化・読み込み/エラー(T5 / F5, F6)

### カメラ
- 純 Dart の `CameraOrbit`(`lib/office/scene/camera_orbit.dart`)が方位・仰角・ズーム・注視点を持つ。flutter_scene の `OrbitCameraController` は使わない(正射影のズームは `projection.zoom` で、透視向けの dolly と合わない。テストで flutter_scene の型を使いたくない)。builder は毎フレーム(`onTick`)、同じ `OrthographicCamera` の `position/target/projection.zoom/far` に値を書き写すだけ。
- 向きの規約は `?cameraYaw` と同じ(方位 0 = 手前 -Z 側、正の値でカメラは -X 側へ回る)。右へドラッグ → 方位増、下へドラッグ → 仰角増(より見下ろす)、ホイールを奥へ → 拡大。
- 上限: 仰角 15°〜80°、ズーム 0.6〜4.0、注視点は床 ± 1m。方位は自由(毎回 (-π, π] に正規化)。NaN/無限大の入力は無視、1 回のズーム倍率は [1/4, 4] に丸める。
- 感度: 回転 0.006 rad/px(方位)・0.005 rad/px(仰角)、ホイール `exp(-dy × 0.0015)`。
- 近遠面: 目は注視点から 2 × reach、near = 0、far = 4 × reach(T4 の `framing` は far が足りず、パンで遠い側が切れるため変更)。
- 入力は `OrbitGestureLayer`(`Listener`)。マウス左 = 回転、右/中 = パン、ホイール/`PointerScaleEvent` = ズーム、タッチ 1 本 = 回転、2 本 = ピンチ + パン。スロップ(マウス 6px、タッチ 12px)以内で離した左ボタン/タッチだけがタップ(選択)。右クリックメニューは builder が `BrowserContextMenu.disableContextMenu()` で止める(Web のみ)。
- [視点リセット]: OfficePage の `ViewResetSignal` → 描画の `resetView` 引数 → `orbit.reset()`(アニメーションなし)。

### 仮想時刻
- `VirtualClock`(`ValueListenable<Duration>`)を `main()` で 1 つ作り、`FlutterSceneOfficeView(clock:)` と `App(virtualTime:)` に渡す。進めるのは描画の `onTick`(人の動きと同じ場所)。実時間 1 倍、`OfficeData.cycleLength`(5 分)で一巡、250ms 刻みで通知。タブが裏に回ると `onTick` も止まり、仮想時刻も止まる(戻ると続きから)。
- 開発者用 `?time=<秒>` で開始位置を指定できる(切り替わりの直前から見るため)。
- 3D パネル・部屋の床・カードは同じ時計から `roomStatusAt` で導出する(別の導出は作らない)。席の在席/離席の導出は変えていない(T4 の決定のまま。今のデータでは全席「離席」)。

### 部屋の見た目
- 各会議室に薄い床の箱 `<roomId>#floor`(`BoxKind.roomFloor`)を足し、部屋ごとの材質の `baseColorFactor` を空き/使用中で書き換える(状態が変わった部屋だけ)。色は `status_style.dart` の `roomFloorColor` 1 か所。部屋の床のクリックは会議室の選択になる。
- 注意: 「床以外の箱 = 障害物」とみなすテスト 2 か所では `roomFloor` も除外している。

### 読み込み/エラー
- `scene_loading.dart`(flutter_scene を import しない)に `SceneLoading`(10 秒超で補足)と `SceneErrorView`。
- 判定: `isWebGL2Supported()`(`canvas.getContext('webgl2')`)が false なら初期化を試さず「WebGL2 非対応」、`Scene.initializeStaticResources()` 以降の例外は「読み込み失敗」(例外文字列は詳細に出す)。非 Web は判定しない。
- [再読み込み]: Web はページ全体の再読み込み(`location.reload()`)。非 Web はシーンの初期化のやり直し。

### Web での未確認点(QA で確認)
flutter_scene は `flutter test` で動かないため、次は Chrome 実機で確認する: 材質の色の書き換えが再描画に反映されるか(効かなければ空き用・使用中用の 2 材質を作ってメッシュの材質を差し替える)、右クリックメニューの抑止(足りなければ `contextmenu` の `preventDefault`)、トラックパッドの 2 本指スクロール/ピンチが Scroll/Scale として届くか、部屋の床と床の Z ファイティング、WebGL2 を無効にした Chrome でのエラー表示。
