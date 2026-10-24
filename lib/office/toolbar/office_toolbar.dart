import 'package:flutter/material.dart';

/// ツールバーの 1 ボタン。項目を足すときはリストに 1 件足すだけ。
class ToolbarItem {
  const ToolbarItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.menuKey,
    this.inMenuOnNarrow = false,
    this.selected = false,
    this.focusNode,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// 狭い幅の ≡ メニュー内の項目のキー。
  final Key? menuKey;

  /// true なら狭い幅では下部ではなく ≡ メニューに入る。
  final bool inMenuOnNarrow;

  /// 一覧が開いている間など「選択中」の見た目。
  final bool selected;
  final FocusNode? focusNode;
}

/// 広い幅の AppBar 右側のボタン列(アイコン+文言)。
List<Widget> officeToolbarActions(
  BuildContext context,
  List<ToolbarItem> items,
) {
  final scheme = Theme.of(context).colorScheme;
  return [
    for (final item in items)
      Semantics(
        selected: item.selected,
        child: TextButton.icon(
          key: item.key,
          focusNode: item.focusNode,
          style: item.selected
              ? TextButton.styleFrom(backgroundColor: scheme.secondaryContainer)
              : null,
          onPressed: item.onPressed,
          icon: Icon(item.icon, size: 18),
          label: Text(item.label),
        ),
      ),
    const SizedBox(width: 8),
  ];
}

/// 狭い幅の下部ツールバー。`inMenuOnNarrow` でない項目を均等に並べる。
class OfficeBottomToolbar extends StatelessWidget {
  const OfficeBottomToolbar({super.key, required this.items});

  final List<ToolbarItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = items.where((i) => !i.inMenuOnNarrow);
    return Material(
      key: const Key('bottom-toolbar'),
      color: scheme.surfaceContainer,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (final item in shown)
                  Expanded(
                    child: Semantics(
                      selected: item.selected,
                      child: InkWell(
                        key: item.key,
                        focusNode: item.focusNode,
                        onTap: item.onPressed,
                        child: Ink(
                          color: item.selected
                              ? scheme.secondaryContainer
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.icon, size: 24),
                              Text(item.label, style: text.labelMedium),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 狭い幅の AppBar 右端の ≡ メニュー。`inMenuOnNarrow` の項目だけを入れる。
class OfficeMenuButton extends StatelessWidget {
  const OfficeMenuButton({super.key, required this.items});

  final List<ToolbarItem> items;

  @override
  Widget build(BuildContext context) {
    final inMenu = items.where((i) => i.inMenuOnNarrow).toList();
    if (inMenu.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<ToolbarItem>(
      key: const Key('menu-button'),
      tooltip: 'メニュー',
      icon: const Icon(Icons.menu),
      onSelected: (item) => item.onPressed(),
      itemBuilder: (context) => [
        for (final item in inMenu)
          PopupMenuItem<ToolbarItem>(
            key: item.menuKey,
            value: item,
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: 12),
                Text(item.label),
              ],
            ),
          ),
      ],
    );
  }
}
