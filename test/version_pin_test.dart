import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec.yaml で flutter_scene が 0.24.3 に完全固定されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'^  flutter_scene: 0\.24\.3\s*$',
        multiLine: true,
      ).hasMatch(pubspec),
      isTrue,
      reason: '^ や範囲指定を付けず flutter_scene: 0.24.3 と書く',
    );
  });

  test('environment.flutter が >=3.47.0', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'''^  flutter: ["']>=3\.47\.0["']\s*$''',
        multiLine: true,
      ).hasMatch(pubspec),
      isTrue,
    );
  });

  test('pubspec.lock の flutter_scene も 0.24.3', () {
    final lock = File('pubspec.lock').readAsStringSync();
    final m = RegExp(
      r'^  flutter_scene:\n(?:    .*\n)*?    version: "([^"]+)"',
      multiLine: true,
    ).firstMatch(lock);
    expect(m, isNotNull, reason: 'pubspec.lock に flutter_scene が無い');
    expect(m!.group(1), '0.24.3');
  });
}
