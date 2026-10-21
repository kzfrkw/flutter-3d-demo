import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('依存に通信・保存・解析のパッケージが無い', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final deps = <String>[];
    var inDeps = false;
    for (final l in lines) {
      if (RegExp(r'^(dependencies|dev_dependencies):').hasMatch(l)) {
        inDeps = true;
        continue;
      }
      if (RegExp(r'^\S').hasMatch(l)) inDeps = false;
      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(l);
      if (inDeps && m != null) deps.add(m.group(1)!);
    }
    expect(deps, isNotEmpty);
    final banned = RegExp(
      r'^(http|dio|shared_preferences|hive.*|sentry.*|web_socket.*|firebase_.*|.*analytics.*|.*crashlytics.*)$',
    );
    expect(deps.where(banned.hasMatch), isEmpty);
  });

  test('lib/ に保存・通信の API の利用が無い', () {
    final words = [
      'localStorage',
      'sessionStorage',
      'document.cookie',
      'HttpClient',
      'package:http',
      'XMLHttpRequest',
      'sendBeacon',
      'WebSocket',
    ];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final w in words) {
        expect(src.contains(w), isFalse, reason: '${f.path} に $w');
      }
    }
  });
}
