# flutter_3d_demo

Flutter と flutter_scene による 3D デモアプリ。主な対象は Web(Chrome)。iOS の雛形は残してあるが、確認の対象外。

## Web での起動

```sh
flutter run -d chrome
```

URL の末尾に `?check` を付けて開くと、技術検証ページ s0-check が表示される(glTF 表示・3D 面へのウィジェット埋め込み・アニメ再生の OK/NG)。`?check` が無いときは s1-office(箱で組んだ架空オフィスの俯瞰/アイソメ表示。データはコード内固定のダミー)が出る。結果の記録は `docs/dev-notes.md`。

- 開発記録: デモ内の [記録] ボタン、またはリポジトリの `docs/dev-notes.md`(同じファイル。使用版・工数・つまずき・Web の制約・動作確認したブラウザ・素材・所感)
- 公開手順: `docs/deploy.md`(当面サーバには置かず、ビルドした成果物を手元で開く/フォルダで渡す)

## ファイル構成(`lib/office/`)

- `data/`: `OfficeData` と、コード内固定のダミー(`dummy_office_data.dart`)。純 Dart で、描画ライブラリを import しない
- `scene/`: `office_layout.dart`(`OfficeData` → 置く箱の一覧、純 Dart)、`office_scene_view.dart`(描画の差し替え口)、`office_scene_builder.dart`(flutter_scene で実際に描く唯一のファイル)
- `people/`: 人の移動(純 Dart)。`people_simulation.dart`(歩行者の状態・区間の移動・向き・揺れ・停滞の検出)、`route_planner.dart`(neighbors 上の最短経路)、`people_count.dart`(`?people=N` の解釈)、`avatar_controller.dart`・`avatar_collision.dart`(十字キーで動かす自分と、壁・机・椅子との当たり判定)
- `card/`・`guide/`・`list/`・`toolbar/`・`status/`: 情報カード、操作案内、2D 一覧、ツールバー、仮想時刻と会議室の状態
- `office_page.dart`: s1-office の画面

`lib/notes/`: 開発記録のページ(`dev_notes_page.dart`)と、本文を読むための小さな Markdown 部分集合の解析器(`markdown_lite.dart`)。本文は `docs/dev-notes.md`(pubspec の assets に入れて同じファイルを表示する)。

開発者用の URL パラメータ(性能や見た目の確認用):

- `?people=10`: 人を 10 人に増やして開く(5〜10 に丸める)
- `?cameraYaw=<度>`: 開始時の視点の向き(0 = 手前、90 = -X 側、180 = 奥、-90 = +X 側)
- `?time=<秒>`: 仮想時刻の開始位置(会議室の状態が切り替わる直前から見るため)

シーン側は ID(`EntityRef`、箱の `<entityId>#<部位>`)で `OfficeData` を参照し、値を書き写さない。

## 版の固定

- Flutter 3.47.x(`environment.flutter: ">=3.47.0"`。確認に使った版は `docs/dev-notes.md`)
- flutter_scene は `0.24.3` に完全固定(`^` を付けない)。`pubspec.lock` もコミットする
- 版を変えるときは `test/version_pin_test.dart` と `docs/dev-notes.md` も合わせて更新する(合っていないと `test/notes/dev_notes_content_test.dart` が落ちる)

## 開発の手順

依存の準備:

```sh
flutter pub get
```

全テストの実行:

```sh
flutter test
```

全テストが成功すると終了コード 0、1つでも失敗すると非 0 で終わります(`echo $?` で確認できます)。

静的解析:

```sh
flutter analyze
```

問題が無ければ `No issues found!` と表示され、終了コード 0 になります。

## テストの置き場所

テストは `test/` 配下に `*_test.dart` という名前で置きます。`flutter test` が自動で見つけて実行します。
