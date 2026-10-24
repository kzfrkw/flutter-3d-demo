# 開発記録

Flutter と flutter_scene で作った 3D オフィスデモ(s1-office)の作り方の記録です。「次の企画に進むか」を判断するために、作る手間とつまずき、Web での制約を1か所にまとめました。対象ブラウザは Chrome(最新版)です。データはすべてコード内固定のダミーです。更新日 2026-10-22。

この文書がデモ内の [記録] ページの本文です(リポジトリの `docs/dev-notes.md` と同じファイル)。公開手順は `docs/deploy.md` にあります。

## 1. 使用版

| 項目 | 版 |
|---|---|
| Flutter | 3.47.7(stable、framework abaf9c5、engine deb2874) |
| Dart | 3.13.5 |
| flutter_scene | 0.24.3(`pubspec.yaml` で完全固定、`pubspec.lock` も 0.24.3) |
| vector_math | ^2.2.0(lock は 2.4.3。flutter_scene と同じ型を使うため直接依存にした) |

版を変えるときは、この表と `test/version_pin_test.dart` を一緒に直します(`test/notes/dev_notes_content_test.dart` も、この表と pubspec の版が合っているかを調べます)。

## 2. 工数の目安

### 実績(実際にかかった期間)

実装はエージェント(agent-crew)が行い、人は確認と回答をしました。人が使った時間は記録していないので **未記録** です。日付は各作業のコミット日です。

| 作業 | 内容 | 実装した日 |
|---|---|---|
| 雛形 | Flutter の雛形、テスト基盤 | 2026-10-15 |
| T1 | s0-check(技術検証: glTF・埋め込み・アニメ) | 2026-10-17 |
| T2 | OfficeData(ダミー)・3D オフィス s1-office | 2026-10-17 |
| T3 | 歩く人(カプセルと移動シミュレーション) | 2026-10-17 |
| T4 | 3D 面上の名札・会議室パネル、情報カード | 2026-10-20 |
| T5 | カメラ操作、仮想時刻による状態の変化、読み込み/エラー表示 | 2026-10-20 |
| T6 | ツールバー、操作案内、2D 一覧 | 2026-10-22 |
| T7 | 開発記録と公開準備(この文書) | 2026-10-22 |

雛形から T7 まで、暦の上では 2026-10-15〜10-22 の約 1 週間です。ただし人の確認や回答の待ち時間を含み、作業時間そのものではありません。

### 推定(Flutter 経験者が手で作る場合)

**以下は推定であり、実測ではありません。** 各チケットの差分の規模(テストを含めて全体で約 7,000 行)とつまずきの数から見積もった幅です。Flutter の画面作りに慣れていて、3D は未経験という前提です。

| 作業 | 推定日数 | 根拠 |
|---|---|---|
| 雛形・テスト基盤・導入 | 0.5〜1 日 | flutter_scene の導入と `hook/build.dart` の扱いで詰まりやすい |
| T1 s0-check | 1〜2 日 | 埋め込み面の向きと UV 反転の原因探しが主 |
| T2 3D オフィス | 1〜2 日 | 箱を並べる処理は単純。座標系とカメラの理解が要る |
| T3 歩く人 | 2〜3 日 | 経路・向き・停滞の扱いを純 Dart で作りテストする |
| T4 名札・パネル・カード | 2〜3 日 | ビルボード、選択(raycast)、カードの配置 |
| T5 カメラ・仮想時刻 | 2〜3 日 | 正射影カメラの自前操作、入力の判別、エラー表示 |
| T6 ツールバー・案内・一覧 | 2〜3 日 | 通常の Flutter 画面なので経験が活きる |
| T7 開発記録・公開準備 | 1 日 | 文書とページ 1 つ |
| 合計 | 11〜18 日 | 目安は約 3 週間 |

## 3. つまずき

詳しい経過は付録にあります。

- **導入**: `flutter pub add flutter_scene:0.24.3` のあと `dart run flutter_scene:init` が要る。`init` が `hook/build.dart`・`flutter_scene_generated/`・pubspec の assets・`analysis_options.yaml` を足す。→ そのとおり実行した。
- **`Material` の名前の衝突**: `flutter_scene/scene.dart` が `Material` を export するので、`package:flutter/material.dart` と併用すると衝突する。→ `hide Material` を付けた。
- **`hook/build.dart` の lint**: `hooks` を直接依存にしていないため lint が出る。→ `analysis_options.yaml` で `hook/**` を除外した。
- **3D 面に埋め込んだウィジェットが左右反転・見えない**: 埋め込み面は -Z 側からしか見えず(+Z 側は裏面カリング)、UV の左右も逆だった。カメラを +Z に移すと見えなくなった。→ U を逆にした四角形を使い、カメラ側が -Z になるように置いた(3 回目の修正で解決)。
- **pub.dev に繋がらない環境**: 実装の環境では名前解決ができず `flutter pub get` や `flutter test` が失敗した。→ `flutter pub get --offline` のあと `flutter test --no-pub` で実行した。
- **選択(raycast)と材質の色**: 名札・パネルの板が `Scene.raycast` に当たるか、材質の色の書き換えが再描画に反映されるかは、テストでは確かめられず Chrome 実機での確認が要った。→ 当たらなくても人・席・壁は選べる設計にし、反映されない場合は材質を 2 つ用意して差し替える案を用意した。
- **テストで flutter_scene が動かない**: `flutter test` では flutter_scene を動かせない。→ 3D 描画を差し替え口(`OfficeSceneView`)の向こうに置き、ページの側は偽物でテストした。ロジック(経路・カメラ・状態の導出)は純 Dart にしてテストした。
- **`pumpAndSettle` で終わらない**: 画面に定期 Timer があるテストで `pumpAndSettle` が終わらなかった。→ 有限回の `pump` で待つ方針にした。
- **カメラ操作**: flutter_scene の `OrbitCameraController` は透視向けの dolly で、正射影のズームと合わない。→ 純 Dart の `CameraOrbit` を自作した。パンで遠い側が切れたため、近遠面(far)を広げた。
- **Web で Chrome を起動できない開発環境**: 画面の見た目や fps は、実装の環境では確かめられなかった。→ 人の確認に任せた(第 5 節)。

## 4. Web での制約・使えなかった機能と代替

| 機能 | 制約・使えなかった理由 | 代替 |
|---|---|---|
| 骨格アニメ付きの人物モデル | CC0 で骨格アニメ付きのモデルを入手していない(外部から取らない方針) | カプセル+前方の小さな箱(向き)に、歩いた距離に連動した上下の揺れと傾きを付けた |
| 3D 面上の名札・会議室パネルの読み上げ | テクスチャなので支援技術から読めない | 同じ情報を情報カードと 2D 一覧で読める |
| キーボードだけでの 3D 上の選択 | 3D の選択はマウス・タッチ専用 | 2D 一覧からキーボードで選べる |
| `OrbitCameraController` | 透視向けで、正射影のズームと合わない | 自前の `CameraOrbit`(回転・ズーム・パン・リセット) |
| ブラウザの右クリックメニュー | 右ボタンのドラッグ(パン)と重なる | Web で `BrowserContextMenu.disableContextMenu()` により止める |
| WebGL2 が使えない Chrome | flutter_scene が動かない | 初期化を試さず「WebGL2 非対応」のエラー表示を出す |
| 外部リンクを開く | `url_launcher` などの依存を増やさない方針 | URL は文字で書き、クリックできるリンクにしない |
| Safari・Firefox・Edge | 動作確認をしていない | 対象は Chrome(最新版)のみ |

## 5. 動作確認したブラウザ

s0-check(技術検証)の結果です。確認日 2026-10-16〜17、Chrome(`flutter run -d chrome`、URL に `?check`)、人の目視です。**Chrome の版は未記録** です。

| 項目 | 結果 | 備考 |
|---|---|---|
| glTF 表示 | OK | 箱が 1 つ見えた |
| 3D 面にウィジェット埋め込み | OK | 3 回目の修正(UV 反転した四角形)後、人が「確認できました」(2026-10-17)。「Hello Widget」が見える |
| アニメ再生 | OK | 箱が回った |

ブラウザごとの可否です。依頼者の回答(2026-10-22)は「ブラウザは Chrome で」でした。

| ブラウザ | 可否 | 備考 |
|---|---|---|
| Chrome | 動作確認済み(人の確認) | 版は未記録 |
| Safari | 未確認 | |
| Firefox | 未確認 | |
| Edge | 未確認 | |

- `?people=10` の滑らかさ・fps: **未測定**(実装の環境では Chrome を起動できなかった)。測ったら環境と値をここに書く。
- 骨格アニメは未検証(回転する箱のノードアニメーションのみ確認)。

## 6. 素材の出典とライセンス

| ファイル | 出典 | ライセンス |
|---|---|---|
| `assets/models/check_cube.glb` | `tool/make_check_model.py` で自作した、回転アニメ(`Spin`)付きの橙色の箱。再生成は `python3 tool/make_check_model.py` | CC0 1.0 |

- オフィスは flutter_scene の `CuboidGeometry`(箱)で、人はカプセルで作っている。画像・フォント・3D モデルなど、第三者の素材を含まない。
- 骨格アニメ付きの CC0 モデルは未入手。
- 依存パッケージ(flutter_scene など)のライセンスは、それぞれのパッケージに従う。

## 7. 所感

**Flutter 経験者が 3D 未経験でも、この規模(箱のオフィス+カプセルの人+カード・一覧)なら作れる。** ただし 3D の部分は、通常の Flutter 画面より時間がかかり、Chrome での目視確認が欠かせない。

根拠:

- 実際に、s0-check から一覧・案内まで、約 1 週間(暦の上)で動くデモが出来た。実装はエージェントで、人の時間は未記録のため、人が手で作る場合は第 2 節の推定(約 11〜18 日)で見る。
- 簡単だった点: ツールバー、カード、一覧、案内といった通常の Flutter 画面は、3D の知識なしで作れた。ロジック(経路・カメラ・状態の導出)を純 Dart にして、テストで固められた。
- 難しかった点: 3D 面に埋め込むウィジェットの向きと UV、座標系とカメラ、画面で見ないと分からない不具合(反転、見えない、切れる)。テストでは flutter_scene が動かず、確認は Chrome の目視に頼る。
- 次の企画に進むときの注意: ブラウザは Chrome のみ確認済みで、他は未確認。fps は未測定。骨格アニメと実際の素材(人物モデル、家具)は使っておらず、使う場合は素材の入手とライセンスの確認、骨格アニメの検証が別に要る。
- これは1本のデモを作った範囲での所感で、より大きな 3D 表現(多数のモデル、凝った照明)への見通しは含まない。

## 付録: 実装メモ(T1〜T6)

各作業のときの記録です。内容は節 1〜7 の元になっています。

### s0-check の依頼者への報告

**全項目 OK。代替案は不要。** ただし骨格アニメは未検証(回転する箱のみ確認)。F3(歩く人)に直結するため、必要なら CC0 の骨格アニメ付きモデルで別途検証する。

### s0-check の結果

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

### NG のときの代替案

- 埋め込みが NG: F4(名札・会議室パネル)を、3D 座標から画面座標に投影した 2D オーバーレイ(Scene の上に `Stack` と `Positioned` を重ねる)にする。データや画面の構成は変えない(structure.md 第4章)。
- アニメが NG: 骨格アニメを使わず、ノードの移動・回転の補間だけで「歩く」ように見せる(カプセルでの代用と組み合わせる)。
- glTF が NG: 箱とカプセル(プリミティブ)で組む。flutter_scene が Web で描画できない場合は「Web で作る」決定の見直しになるため、作り込まず依頼者に報告する。

### つまずいた点(T1〜T2)

- 導入: `flutter pub add flutter_scene:0.24.3` →`dart run flutter_scene:init`(エージェント用スキルは入れない)。`init` が `hook/build.dart`・`flutter_scene_generated/`・pubspec の assets 項目・`analysis_options.yaml` を足す。
- `flutter_scene/scene.dart` は `Material` を export するため、`package:flutter/material.dart` と併用するときは `hide Material` が要る。
- `hook/build.dart` は `hooks` を直接依存にしていないため lint が出る。`analysis_options.yaml` で `hook/**` を除外した。
- Web のユーザーエージェントは `dart:js_interop` で取る(`package:web` を足さない)。
- 実装者のサンドボックスでは `pub.dev` の名前解決ができず `flutter test` / `flutter pub get` が失敗した。`flutter pub get --offline`(キャッシュ済み)のあと `flutter test --no-pub` で実行した。

### 素材の出典とライセンス

- `assets/models/check_cube.glb`: `tool/make_check_model.py` で自作した、回転アニメ(`Spin`)付きの橙色の箱。**CC0 1.0**(第三者の素材を含まない)。再生成は `python3 tool/make_check_model.py`。
- s1-office のオフィスは flutter_scene の `CuboidGeometry`(箱)で構成。第三者の素材なし(CC0 の家具モデルは使っていない)。
- 骨格アニメ付きの CC0 モデルは未入手。骨格アニメの検証は、必要なら別途 CC0 の素材を入れて行う(今回の「アニメ再生」はノードのアニメーションの検証)。

### 歩く人(T3 / F2)

- 表し方: 骨格アニメ付きの人物モデルは素材が無い(外部から取らない)ため使わず、カプセル(高さ 1.6m・半径 0.25m)+前方の小さな箱(鼻)で表す。「歩行アニメ」は歩いた距離に連動した上下の揺れ(`bob`)と左右の傾き(`lean`)で代用した。向きは鼻で分かる。Node の name は `<personId>#body` / `<personId>#nose`。
- 動き: `lib/office/people/people_simulation.dart`(純 Dart)が Route の waypoint を順にたどる。壁・机を避ける仕組みは実行時の当たり判定ではなく、「経路は neighbors のグラフ上だけ」+「グラフの辺が壁・机から人の半径ぶん離れている」ことをテスト(`people_walk_test.dart`)で保証する方式。既定データは Waypoint の座標を直さずに通った。
- 向き: 目標の waypoint への方向 `atan2(dx, dz)` に、最大角速度 12 rad/s で近づける(折り返しも約 0.26 秒で一致)。
- 停滞時の再設定: 3 秒ごとの窓で歩いた距離が 0.5m 未満なら、今向かっている waypoint(無効な Route なら立っている waypoint)から、到達できる別の waypoint へ幅優先探索の最短経路を作り、往復の周回に差し替える。直線で近い点へは向かわない(壁を抜けるため)。通常データでは起きない保険。
- 10 人: `?people=10`(`people_count.dart`)で、追加の 4 人(席なし、既存の Waypoint をつなぐ Route)を足した OfficeData を渡す。
- fps の実測(AC13): **未測定**。実装者の環境では Chrome を起動できず、QA または人の確認で測る。測ったら環境と値をここに書く。目安 30fps を割る場合は、鼻の Node を省く → カプセルの分割数(16/4)を減らす、の順に試す。
- つまずき: ツールの `flutter test` は pub.dev に接続しようとして失敗する。実装者は `XDG_CONFIG_HOME` を一時ディレクトリにして `flutter pub get --offline` のあと `flutter test --no-pub` / `flutter analyze --no-pub` を Bash で実行した。

### 3D 面上ウィジェットと情報カード(T4 / F4, F3)

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

### カメラ操作・状態の動的変化・読み込み/エラー(T5 / F5, F6)

#### カメラ
- 純 Dart の `CameraOrbit`(`lib/office/scene/camera_orbit.dart`)が方位・仰角・ズーム・注視点を持つ。flutter_scene の `OrbitCameraController` は使わない(正射影のズームは `projection.zoom` で、透視向けの dolly と合わない。テストで flutter_scene の型を使いたくない)。builder は毎フレーム(`onTick`)、同じ `OrthographicCamera` の `position/target/projection.zoom/far` に値を書き写すだけ。
- 向きの規約は `?cameraYaw` と同じ(方位 0 = 手前 -Z 側、正の値でカメラは -X 側へ回る)。右へドラッグ → 方位増、下へドラッグ → 仰角増(より見下ろす)、ホイールを奥へ → 拡大。
- 上限: 仰角 15°〜80°、ズーム 0.6〜4.0、注視点は床 ± 1m。方位は自由(毎回 (-π, π] に正規化)。NaN/無限大の入力は無視、1 回のズーム倍率は [1/4, 4] に丸める。
- 感度: 回転 0.006 rad/px(方位)・0.005 rad/px(仰角)、ホイール `exp(-dy × 0.0015)`。
- 近遠面: 目は注視点から 2 × reach、near = 0、far = 4 × reach(T4 の `framing` は far が足りず、パンで遠い側が切れるため変更)。
- 入力は `OrbitGestureLayer`(`Listener`)。マウス左 = 回転、右/中 = パン、ホイール/`PointerScaleEvent` = ズーム、タッチ 1 本 = 回転、2 本 = ピンチ + パン。スロップ(マウス 6px、タッチ 12px)以内で離した左ボタン/タッチだけがタップ(選択)。右クリックメニューは builder が `BrowserContextMenu.disableContextMenu()` で止める(Web のみ)。
- [視点リセット]: OfficePage の `ViewResetSignal` → 描画の `resetView` 引数 → `orbit.reset()`(アニメーションなし)。

#### 仮想時刻
- `VirtualClock`(`ValueListenable<Duration>`)を `main()` で 1 つ作り、`FlutterSceneOfficeView(clock:)` と `App(virtualTime:)` に渡す。進めるのは描画の `onTick`(人の動きと同じ場所)。実時間 1 倍、`OfficeData.cycleLength`(5 分)で一巡、250ms 刻みで通知。タブが裏に回ると `onTick` も止まり、仮想時刻も止まる(戻ると続きから)。
- 開発者用 `?time=<秒>` で開始位置を指定できる(切り替わりの直前から見るため)。
- 3D パネル・部屋の床・カードは同じ時計から `roomStatusAt` で導出する(別の導出は作らない)。席の在席/離席の導出は変えていない(T4 の決定のまま。今のデータでは全席「離席」)。

#### 部屋の見た目
- 各会議室に薄い床の箱 `<roomId>#floor`(`BoxKind.roomFloor`)を足し、部屋ごとの材質の `baseColorFactor` を空き/使用中で書き換える(状態が変わった部屋だけ)。色は `status_style.dart` の `roomFloorColor` 1 か所。部屋の床のクリックは会議室の選択になる。
- 注意: 「床以外の箱 = 障害物」とみなすテスト 2 か所では `roomFloor` も除外している。

#### 読み込み/エラー
- `scene_loading.dart`(flutter_scene を import しない)に `SceneLoading`(10 秒超で補足)と `SceneErrorView`。
- 判定: `isWebGL2Supported()`(`canvas.getContext('webgl2')`)が false なら初期化を試さず「WebGL2 非対応」、`Scene.initializeStaticResources()` 以降の例外は「読み込み失敗」(例外文字列は詳細に出す)。非 Web は判定しない。
- [再読み込み]: Web はページ全体の再読み込み(`location.reload()`)。非 Web はシーンの初期化のやり直し。

#### Web での未確認点(QA で確認)
flutter_scene は `flutter test` で動かないため、次は Chrome 実機で確認する: 材質の色の書き換えが再描画に反映されるか(効かなければ空き用・使用中用の 2 材質を作ってメッシュの材質を差し替える)、右クリックメニューの抑止(足りなければ `contextmenu` の `preventDefault`)、トラックパッドの 2 本指スクロール/ピンチが Scroll/Scale として届くか、部屋の床と床の Z ファイティング、WebGL2 を無効にした Chrome でのエラー表示。

### 操作できる人(#12)
- 方式: 十字キーで動かす「自分」を 1 人足した。↑ は画面の奥、↓ は手前、← は左、→ は右へ進む(戦車式の旋回はしない。人のコメントで「左右はそのまま左右へ動く」に変更)。体の向きは進む向きへ最大 12 rad/s で近づける。斜めは速さを 1.5 m/s に正規化する。
- 画面基準: カメラは自由に回せるので、「画面の上」は毎フレーム `OrbitFrame.groundAxes(pose)`(視線の水平成分)から求める。右 = `(fz, -fx)` は `CameraOrbit.pan` と同じ式で、符号をこの 1 か所に集めた。
- 入力: `OfficePage` の最外側 `Focus.onKeyEvent` が、ページ自身が主フォーカスのときだけ押下状態を書き換える(一覧の行・ボタンにフォーカスがあるとき、案内が開いているときは何もしない)。フォーカスを失ったとき、アプリが `resumed` 以外になったとき、案内を開いたときに全部離す。3D をクリックするとページにフォーカスを戻す。ページには Timer / Ticker を足していない(`pumpAndSettle` が止まらなくなるため)。時間を進めるのは描画の `onTick`。
- 当たり判定: 自分だけが実行時に持つ(歩く人は従来どおり経路の上だけ)。外壁・会議室の壁・机・椅子の箱と半径 0.25m の円の重なりを見て、X 軸 → Z 軸の順に別々に動かして壁沿いに滑る。止められた軸は二分探索で壁の手前まで詰める。1 ステップの最大移動量(`speed × maxDt` = 0.15m)が円の直径より小さいので、薄い壁(0.15m)を飛び越えない。自分と歩く人は重なる。
- 描画への写し方: `AvatarController` は純 Dart。`main()` で 1 つ作り、描画(`FlutterSceneOfficeView(avatar:)`)とページ(`OfficePage(avatar:)`)で共有する。描画は毎フレーム step して Node の変換に写すだけ。ノード名は `player#body / nose / tag / mark`(データの表に無い id なので、クリックは背景扱い)。見分けは黒い体・黄色の足元の板・名札「あなた」。
- 未測定・未確認(Chrome の QA で確認): ← → の向きが実際に画面の左右になるか、`?cameraYaw=90/180/-90` でも ↑ が画面の上か、押しっぱなしのなめらかさ(fps は未測定)、足元の板と会議室の床の見え方、ウィンドウが裏に回ったときに KeyUp が届かない場合の取りこぼし。
