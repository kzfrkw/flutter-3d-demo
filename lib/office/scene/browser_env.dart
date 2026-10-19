import 'browser_env_stub.dart'
    if (dart.library.js_interop) 'browser_env_web.dart'
    as impl;

/// ブラウザが WebGL2 を使えるか。Web 以外は判定しない(null)。
bool? isWebGL2Supported() => impl.isWebGL2Supported();

/// ページを再読み込みする。Web では true、それ以外は何もせず false。
bool reloadPage() => impl.reloadPage();
