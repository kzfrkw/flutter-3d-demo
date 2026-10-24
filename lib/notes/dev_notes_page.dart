import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'markdown_lite.dart';

/// 本文(Markdown)を返す口。既定は rootBundle.loadString(devNotesAssetPath)。
typedef DevNotesLoader = Future<String> Function();

/// pubspec.yaml の assets に入れるパス。リポジトリの正本と同じファイル。
const String devNotesAssetPath = 'docs/dev-notes.md';

/// 戻るボタンの文言。
const String backToDemoLabel = '← デモに戻る';

const String _loadFailedTitle = '開発記録を読み込めませんでした';
const String _loadFailedHint = 'リポジトリの docs/dev-notes.md を直接お読みください。';
const double _readingWidth = 760;
const double _narrowBreakpoint = 600;

/// s5-notes: 開発記録の別ページ。`docs/dev-notes.md` を読んで描く。
class DevNotesPage extends StatefulWidget {
  const DevNotesPage({super.key, this.loader});

  /// null なら rootBundle。
  final DevNotesLoader? loader;

  @override
  State<DevNotesPage> createState() => _DevNotesPageState();
}

class _DevNotesPageState extends State<DevNotesPage> {
  late final Future<List<MdBlock>> _blocks =
      (widget.loader ?? () => rootBundle.loadString(devNotesAssetPath))().then(
        parseMarkdownLite,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < _narrowBreakpoint;
    final gutter = narrow ? 16.0 : 24.0;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Flutter Scene Demo (ダミーデータ)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Column(
                  gutter: gutter - 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Semantics(
                        label: 'デモに戻る',
                        excludeSemantics: true,
                        child: const Text(backToDemoLabel),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MdBlock>>(
              future: _blocks,
              builder: (context, snap) {
                if (snap.hasError || (snap.hasData && snap.data!.isEmpty)) {
                  return const _LoadFailed();
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
                  );
                }
                return _Body(blocks: snap.data!, gutter: gutter);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 最大幅 760 の中央寄せ列。
class _Column extends StatelessWidget {
  const _Column({required this.gutter, required this.child});
  final double gutter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _readingWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.error_outline, size: 48, color: scheme.error),
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _loadFailedTitle,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadFailedHint,
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.blocks, required this.gutter});
  final List<MdBlock> blocks;
  final double gutter;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SelectionArea(
      child: Scrollbar(
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          padding: EdgeInsets.only(top: 24, bottom: 48 + bottom),
          child: _Column(
            gutter: widget.gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.blocks.length; i++)
                  _blockView(context, widget.blocks[i], first: i == 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _blockView(BuildContext context, MdBlock block, {required bool first}) {
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  switch (block) {
    case MdHeading():
      final (style, top, bottom) = switch (block.level) {
        1 => (text.headlineMedium, 0.0, 12.0),
        2 => (text.titleLarge, 40.0, 12.0),
        3 => (text.titleMedium, 24.0, 8.0),
        _ => (text.titleSmall, 16.0, 4.0),
      };
      Widget h = Text(
        block.text,
        style: style?.copyWith(
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
        ),
      );
      if (block.level == 2) {
        h = Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: h,
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: first ? 0 : top, bottom: bottom),
        child: Semantics(header: true, child: h),
      );
    case MdParagraph():
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(
          _inline(context, block.spans, text.bodyLarge!.copyWith(height: 1.7)),
        ),
      );
    case MdBullets():
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in block.items)
              Padding(
                padding: EdgeInsets.only(
                  left: 8.0 + (item.depth == 0 ? 0 : 20),
                  bottom: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text(
                        item.depth == 0 ? '•' : '◦',
                        style: text.bodyLarge!.copyWith(height: 1.7),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        _inline(
                          context,
                          item.spans,
                          text.bodyLarge!.copyWith(height: 1.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    case MdCode():
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: text.bodyMedium!.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    case MdTable():
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _TableView(table: block),
      );
  }
}

TextSpan _inline(BuildContext context, List<MdSpan> spans, TextStyle base) {
  final scheme = Theme.of(context).colorScheme;
  return TextSpan(
    style: base,
    children: [
      for (final s in spans)
        TextSpan(
          text: s.text,
          style: TextStyle(
            fontWeight: s.bold ? FontWeight.w700 : null,
            fontFamily: s.code ? 'monospace' : null,
            fontSize: s.code && base.fontSize != null
                ? base.fontSize! * 0.9
                : null,
            backgroundColor: s.code ? scheme.surfaceContainerHighest : null,
          ),
        ),
    ],
  );
}

class _TableView extends StatefulWidget {
  const _TableView({required this.table});
  final MdTable table;

  @override
  State<_TableView> createState() => _TableViewState();
}

class _TableViewState extends State<_TableView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium!;
    final columns = [
      widget.table.header.length,
      for (final r in widget.table.rows) r.length,
    ].reduce((a, b) => a > b ? a : b);
    final line = BorderSide(color: scheme.outlineVariant);

    Widget cell(List<MdSpan>? spans, {required bool header}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: spans == null
            ? const SizedBox.shrink()
            : Text.rich(
                _inline(
                  context,
                  spans,
                  header ? base.copyWith(fontWeight: FontWeight.w700) : base,
                ),
              ),
      ),
    );

    TableRow row(List<List<MdSpan>> cells, {required bool header}) => TableRow(
      decoration: BoxDecoration(
        color: header ? scheme.surfaceContainerHigh : null,
        border: Border(bottom: line),
      ),
      children: [
        for (var c = 0; c < columns; c++)
          cell(c < cells.length ? cells[c] : null, header: header),
      ],
    );

    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            border: TableBorder(top: line),
            children: [
              row(widget.table.header, header: true),
              for (final r in widget.table.rows) row(r, header: false),
            ],
          ),
        ),
      ),
    );
  }
}
