# flutter_3d_demo

Flutter と flutter_scene による 3D デモアプリ。主な対象は Web(Chrome)。iOS の雛形は残してあるが、確認の対象外。

## Web での起動

```sh
flutter run -d chrome
```

URL の末尾に `?check` を付けて開くと、技術検証ページ s0-check が表示される(glTF 表示・3D 面へのウィジェット埋め込み・アニメ再生の OK/NG)。`?check` が無いときは仮のホームが出る。結果の記録は `docs/dev-notes.md`。

## 版の固定

- Flutter 3.47.x(`environment.flutter: ">=3.47.0"`。確認に使った版は `docs/dev-notes.md`)
- flutter_scene は `0.24.3` に完全固定(`^` を付けない)。`pubspec.lock` もコミットする
- 版を変えるときは `test/version_pin_test.dart` と `docs/dev-notes.md` も合わせて更新する

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
