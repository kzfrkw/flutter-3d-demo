import 'env_info_stub.dart' if (dart.library.js_interop) 'env_info_web.dart';

/// pubspec.yaml で固定している版と同じ値。
const flutterSceneVersion = '0.24.3';

/// 「ブラウザ・版」の行に表示する情報。
class EnvInfo {
  const EnvInfo({required this.userAgent});

  factory EnvInfo.current() => EnvInfo(userAgent: currentUserAgent());

  final String userAgent;

  String get summary =>
      '$userAgent / Flutter >=3.47.0 / flutter_scene $flutterSceneVersion';
}
