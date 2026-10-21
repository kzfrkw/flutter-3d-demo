import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../card/status_pill.dart';
import '../data/office_models.dart';
import '../status/office_status.dart';
import '../status_style.dart';

/// s4-list。会議室・席・人の 2D 一覧。選択は持たず、親(OfficePage)が渡す。
/// 状態の導出は `office_status.dart` を呼ぶだけで、独自の Timer は持たない。
class OfficeListPanel extends StatefulWidget {
  const OfficeListPanel({
    super.key,
    required this.data,
    required this.time,
    required this.lookup,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final OfficeData data;

  /// 会議室の状態を決める仮想時刻。
  final ValueListenable<Duration> time;

  /// 席・人の状態の問い合わせ口。
  final PersonLookup lookup;

  /// 今カードが開いている対象(行の選択表示)。
  final EntityRef? selected;
  final ValueChanged<EntityRef> onSelect;
  final VoidCallback onClose;

  @override
  State<OfficeListPanel> createState() => _OfficeListPanelState();
}

class _OfficeListPanelState extends State<OfficeListPanel> {
  final FocusNode _firstRowFocus = FocusNode(debugLabel: 'list-first-row');
  final FocusNode _closeFocus = FocusNode(debugLabel: 'list-close');

  bool get _hasRows =>
      widget.data.rooms.isNotEmpty ||
      widget.data.seats.isNotEmpty ||
      widget.data.people.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 開いた直後は先頭の行(無ければ [×])にフォーカスを移す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_hasRows ? _firstRowFocus : _closeFocus).requestFocus();
    });
  }

  @override
  void dispose() {
    _firstRowFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    var first = true;

    Widget row({
      required EntityKind kind,
      required String id,
      required IconData icon,
      required String kindLabel,
      required String name,
      String? sub,
      required StatusPillStyle pill,
    }) {
      final ref = EntityRef(kind, id);
      final focus = first ? _firstRowFocus : null;
      first = false;
      return _ListRow(
        key: ValueKey('list-item-${kind.name}-$id'),
        focusNode: focus,
        icon: icon,
        name: name,
        sub: sub,
        pill: pill,
        selected: widget.selected == ref,
        semanticsLabel: [
          kindLabel,
          name,
          pill.label,
          if (sub != null) sub.replaceAll(' ', ''),
        ].join(' '),
        onTap: () => widget.onSelect(ref),
      );
    }

    Widget section(Key key, String heading, List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              heading,
              key: key,
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '該当なし',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          ...rows,
      ],
    );

    return Material(
      color: scheme.surfaceContainerLow,
      child: ListenableBuilder(
        listenable: widget.time,
        builder: (context, _) {
          final time = widget.time.value;
          final data = widget.data;
          final lookup = widget.lookup;
          first = true;
          final rooms = [
            for (final r in data.rooms)
              row(
                kind: EntityKind.room,
                id: r.id,
                icon: Icons.meeting_room_outlined,
                kindLabel: '会議室',
                name: r.name,
                sub: '定員 ${r.capacity}名',
                pill: roomOccupancyStyle(
                  roomStatusAt(data, r, time).occupancy,
                ),
              ),
          ];
          final seats = [
            for (final s in data.seats)
              row(
                kind: EntityKind.seat,
                id: s.id,
                icon: Icons.event_seat_outlined,
                kindLabel: '席',
                name: s.label,
                pill: pillStyleOf(seatStatusAt(data, s, lookup), scheme),
              ),
          ];
          final people = [
            for (final p in data.people)
              row(
                kind: EntityKind.person,
                id: p.id,
                icon: Icons.person_outline,
                kindLabel: '人',
                name: p.displayName,
                pill: pillStyleOf(personStatusAt(p, lookup), scheme),
              ),
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          '一覧',
                          key: const Key('list-panel-title'),
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      focusNode: _closeFocus,
                      tooltip: '閉じる',
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      section(const Key('list-heading-room'), '会議室', rooms),
                      section(const Key('list-heading-seat'), '席', seats),
                      section(const Key('list-heading-person'), '人', people),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListRow extends StatefulWidget {
  const _ListRow({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.name,
    required this.sub,
    required this.pill,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final FocusNode? focusNode;
  final IconData icon;
  final String name;
  final String? sub;
  final StatusPillStyle pill;
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      selected: widget.selected,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: widget.selected ? scheme.secondaryContainer : null,
          border: widget.selected
              ? Border(left: BorderSide(color: scheme.primary, width: 4))
              : null,
        ),
        child: InkWell(
          focusNode: widget.focusNode,
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: scheme.onSurface.withValues(alpha: 0.08),
          focusColor: scheme.primary.withValues(alpha: 0.08),
          onFocusChange: (v) => setState(() => _focused = v),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Row(
              children: [
                Icon(widget.icon, size: 24, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge,
                      ),
                      if (widget.sub != null)
                        Text(
                          widget.sub!,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(style: widget.pill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
