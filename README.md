# flutter_3d_demo

Flutter(iOS)の 3D デモアプリ。

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
