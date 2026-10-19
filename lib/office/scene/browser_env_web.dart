import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool? isWebGL2Supported() {
  try {
    final document = globalContext['document'] as JSObject?;
    final canvas = document?.callMethod<JSObject?>(
      'createElement'.toJS,
      'canvas'.toJS,
    );
    if (canvas == null) return null;
    final ctx = canvas.callMethod<JSAny?>('getContext'.toJS, 'webgl2'.toJS);
    return ctx != null;
  } catch (_) {
    return null;
  }
}

bool reloadPage() {
  try {
    final location = globalContext['location'] as JSObject?;
    if (location == null) return false;
    location.callMethod<JSAny?>('reload'.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
