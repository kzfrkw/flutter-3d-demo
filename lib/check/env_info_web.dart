import 'dart:js_interop';
import 'dart:js_interop_unsafe';

String currentUserAgent() {
  final navigator = globalContext['navigator'] as JSObject?;
  final ua = navigator?['userAgent'] as JSString?;
  return ua?.toDart ?? 'unknown';
}
