/// Markdown の部分集合(見出し・段落・箇条書き・表・コードブロック・太字・コード)の解析。
/// Flutter を import しない。例外は投げない。
library;

sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);
  final List<MdSpan> spans;
}

class MdBullets extends MdBlock {
  const MdBullets(this.items);
  final List<MdBullet> items;
}

class MdBullet {
  const MdBullet(this.depth, this.spans);
  final int depth;
  final List<MdSpan> spans;
}

class MdTable extends MdBlock {
  const MdTable(this.header, this.rows);
  final List<List<MdSpan>> header;
  final List<List<List<MdSpan>>> rows;
}

class MdCode extends MdBlock {
  const MdCode(this.text);
  final String text;
}

class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.code = false});
  final String text;
  final bool bold;
  final bool code;
}

final RegExp _headingRe = RegExp(r'^(#{1,4}) +(.*)$');
final RegExp _bulletRe = RegExp(r'^( *)- +(.*)$');
final RegExp _tableSepRe = RegExp(
  r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$',
);

bool _isTableRow(String line) => line.trimLeft().startsWith('|');

List<String> _cells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return t.split('|').map((c) => c.trim()).toList();
}

List<MdBlock> parseMarkdownLite(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = <MdBlock>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
    } else if (line.startsWith('```')) {
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      i++; // 閉じの ```(無ければ末尾)
      out.add(MdCode(buf.join('\n')));
    } else if (_headingRe.hasMatch(line)) {
      final m = _headingRe.firstMatch(line)!;
      out.add(MdHeading(m.group(1)!.length, m.group(2)!.trim()));
      i++;
    } else if (_isTableRow(line) &&
        i + 1 < lines.length &&
        _isTableRow(lines[i + 1]) &&
        _tableSepRe.hasMatch(lines[i + 1])) {
      final header = _cells(line).map(parseInline).toList();
      i += 2;
      final rows = <List<List<MdSpan>>>[];
      while (i < lines.length && _isTableRow(lines[i])) {
        rows.add(_cells(lines[i]).map(parseInline).toList());
        i++;
      }
      out.add(MdTable(header, rows));
    } else if (_bulletRe.hasMatch(line)) {
      final items = <MdBullet>[];
      while (i < lines.length && _bulletRe.hasMatch(lines[i])) {
        final m = _bulletRe.firstMatch(lines[i])!;
        items.add(
          MdBullet(m.group(1)!.length >= 2 ? 1 : 0, parseInline(m.group(2)!)),
        );
        i++;
      }
      out.add(MdBullets(items));
    } else {
      final buf = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('```') &&
          !_headingRe.hasMatch(lines[i]) &&
          !_bulletRe.hasMatch(lines[i]) &&
          !_isTableRow(lines[i])) {
        buf.add(lines[i].trim());
        i++;
      }
      if (buf.isEmpty) {
        // どの規則にも当たらない行(段落の途中の表など)は 1 行を段落にして進む。
        buf.add(lines[i].trim());
        i++;
      }
      out.add(MdParagraph(parseInline(buf.join('\n'))));
    }
  }
  return out;
}

/// `**太字**` と `` `コード` ``。閉じていない記号はそのまま文字として残す。
List<MdSpan> parseInline(String line) {
  final spans = <MdSpan>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isNotEmpty) {
      spans.add(MdSpan(plain.toString()));
      plain.clear();
    }
  }

  var i = 0;
  while (i < line.length) {
    if (line.startsWith('**', i)) {
      final end = line.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        spans.add(MdSpan(line.substring(i + 2, end), bold: true));
        i = end + 2;
        continue;
      }
    } else if (line[i] == '`') {
      final end = line.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        spans.add(MdSpan(line.substring(i + 1, end), code: true));
        i = end + 1;
        continue;
      }
    }
    plain.write(line[i]);
    i++;
  }
  flush();
  return spans;
}
