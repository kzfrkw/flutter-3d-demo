import 'package:flutter_3d_demo/notes/markdown_lite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空文字は空のリスト', () {
    expect(parseMarkdownLite(''), isEmpty);
  });

  test('見出しのレベル 1〜4', () {
    final b = parseMarkdownLite('# a\n\n## b\n\n### c\n\n#### d\n');
    expect(b.whereType<MdHeading>().map((h) => h.level), [1, 2, 3, 4]);
    expect((b[1] as MdHeading).text, 'b');
  });

  test('連続する行は 1 つの段落で、改行を保つ', () {
    final b = parseMarkdownLite('one\ntwo\n\nthree');
    expect(b, hasLength(2));
    final p = b[0] as MdParagraph;
    expect(p.spans.map((s) => s.text).join(), 'one\ntwo');
  });

  test('箇条書きと 1 段のネスト', () {
    final b = parseMarkdownLite('- a\n  - b\n- c');
    final l = b.single as MdBullets;
    expect(l.items.map((i) => i.depth), [0, 1, 0]);
    expect(l.items[1].spans.single.text, 'b');
  });

  test('表: ヘッダ+行。列数が揃わない行も許す', () {
    final b = parseMarkdownLite('| a | b |\n|---|---|\n| 1 | 2 |\n| 3 |');
    final t = b.single as MdTable;
    expect(t.header.map((c) => c.single.text), ['a', 'b']);
    expect(t.rows, hasLength(2));
    expect(t.rows[1], hasLength(1));
  });

  test('コードブロックの中身は解釈しない', () {
    final b = parseMarkdownLite('```\n# not heading\n- not bullet\n```\nafter');
    expect((b[0] as MdCode).text, '# not heading\n- not bullet');
    expect(b[1], isA<MdParagraph>());
  });

  test('太字とコード', () {
    final s = parseInline('a **b** `c` d');
    expect(s.map((e) => e.text), ['a ', 'b', ' ', 'c', ' d']);
    expect(s[1].bold, isTrue);
    expect(s[3].code, isTrue);
  });

  test('閉じていない記号は文字のまま残る', () {
    expect(parseInline('a **b').map((e) => e.text).join(), 'a **b');
    expect(parseInline('a `b').map((e) => e.text).join(), 'a `b');
  });

  test('閉じていないコードブロックでも例外を投げない', () {
    expect(() => parseMarkdownLite('```\nabc'), returnsNormally);
  });
}
