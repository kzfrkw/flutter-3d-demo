import 'dart:io';

import 'package:flutter_3d_demo/notes/markdown_lite.dart';
import 'package:flutter_test/flutter_test.dart';

const expectedSections = [
  '1. 使用版',
  '2. 工数の目安',
  '3. つまずき',
  '4. Web での制約・使えなかった機能と代替',
  '5. 動作確認したブラウザ',
  '6. 素材の出典とライセンス',
  '7. 所感',
];

/// `## ` 見出しごとの本文(生の文字列)。
Map<String, String> sections(String src) {
  final out = <String, String>{};
  String? current;
  final buf = StringBuffer();
  var inCode = false;
  for (final line in src.split('\n')) {
    if (line.startsWith('```')) inCode = !inCode;
    if (!inCode && line.startsWith('## ')) {
      if (current != null) out[current] = buf.toString();
      current = line.substring(3).trim();
      buf.clear();
    } else {
      buf.writeln(line);
    }
  }
  if (current != null) out[current] = buf.toString();
  return out;
}

void main() {
  final src = File('docs/dev-notes.md').readAsStringSync();
  final secs = sections(src);

  test('## 見出しは 7 項目がこの順で、8 件目が付録', () {
    final h2 = parseMarkdownLite(src)
        .whereType<MdHeading>()
        .where((h) => h.level == 2)
        .map((h) => h.text);
    expect(h2.take(7).toList(), expectedSections);
    expect(h2.elementAt(7), startsWith('付録'));
  });

  test('節 1 に pubspec.yaml / pubspec.lock の flutter_scene の版がある', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(
      r'^  flutter_scene: (\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    expect(secs['1. 使用版'], contains(v));
    final lock = File('pubspec.lock').readAsStringSync();
    expect(lock, contains('version: "$v"'));
  });

  test('節 6 に assets/ の全ファイルと CC0 、第三者の素材を含まない旨がある', () {
    final s = secs['6. 素材の出典とライセンス']!;
    final files = Directory('assets')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path);
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(s, contains(f), reason: '$f の出典とライセンスを書く');
    }
    expect(s, contains('CC0'));
    expect(s, contains('第三者の素材を含まない'));
  });

  test('節 5 にブラウザと s0-check の項目がある', () {
    final s = secs['5. 動作確認したブラウザ']!;
    for (final k in [
      'glTF 表示',
      '3D 面にウィジェット埋め込み',
      'アニメ再生',
      'Chrome',
      'Safari',
      'Firefox',
      'Edge',
      '未確認',
      '未測定',
    ]) {
      expect(s, contains(k));
    }
  });

  test('節 2・3・7 は空でない', () {
    for (final k in ['2. 工数の目安', '3. つまずき', '7. 所感']) {
      expect(secs[k]!.trim().length, greaterThan(100), reason: k);
    }
  });

  test('解析器が対応しない書式を使っていない', () {
    var inCode = false;
    for (final line in src.split('\n')) {
      if (line.startsWith('```')) inCode = !inCode;
      if (inCode) continue;
      expect(line.startsWith('>'), isFalse, reason: '引用: $line');
      expect(line.contains(']('), isFalse, reason: 'リンク: $line');
      expect(line.contains('!['), isFalse, reason: '画像: $line');
      expect(line.startsWith('<'), isFalse, reason: 'HTML: $line');
      if (!line.startsWith('#')) {
        expect(RegExp(r'^\s*\d+\. ').hasMatch(line), isFalse, reason: line);
      }
    }
  });

  test('正本は pubspec.yaml の assets にあり、deploy.md が README から辿れる', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- docs/dev-notes.md'),
    );
    expect(File('docs/deploy.md').existsSync(), isTrue);
    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('docs/deploy.md'));
    expect(readme, contains('docs/dev-notes.md'));
  });
}
