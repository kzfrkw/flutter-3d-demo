import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notes/dev_notes_page.dart';
import 'card/info_card.dart';
import 'data/office_models.dart';
import 'guide/guide_memory.dart';
import 'guide/operation_guide.dart';
import 'list/office_list_panel.dart';
import 'people/avatar_controller.dart';
import 'people/people_simulation.dart';
import 'scene/office_scene_view.dart';
import 'status/office_status.dart';
import 'toolbar/office_toolbar.dart';

/// 幅がこれ未満ならスマホ配置(下部ツールバー・下シート)、以上なら右の固定パネルでカードを出す。
const double officeNarrowBreakpoint = 600;

/// 幅がこれ以上のときだけ、一覧とカードを同時に出す(未満は片方を閉じる)。
const double officeListBesideCardBreakpoint = 1100;

/// [視点リセット] ボタンの文言。
const String resetViewLabel = '視点リセット';

/// s1-office と s2-card・s3-guide・s4-list。3D のオフィス(差し替え口の向こう)の上に重ねる。
class OfficePage extends StatefulWidget {
  const OfficePage({
    super.key,
    required this.view,
    required this.data,
    this.simulation,
    this.virtualTime,
    this.guideMemory,
    this.notesLoader,
    this.avatar,
  });

  final OfficeSceneView view;
  final OfficeData data;

  /// カードの「現在の行動」「在席/離席」が読む。null なら全員 停止中・離席。
  final PeopleSimulation? simulation;

  /// 仮想時刻。null なら Duration.zero 固定。
  final ValueListenable<Duration>? virtualTime;

  /// 操作案内を閉じたかの記録(メモリ内)。null ならこのページ専用の記録を持つ(= 案内が出る)。
  final GuideMemory? guideMemory;

  /// 開発記録の本文の読み込み口。null なら DevNotesPage の既定(rootBundle)。
  final DevNotesLoader? notesLoader;

  /// 十字キーで動かす自分。3D の描画と共有する。null なら十字キーは何もしない。
  final AvatarController? avatar;

  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage> with WidgetsBindingObserver {
  static final _keyMap = {
    LogicalKeyboardKey.arrowUp: AvatarKey.forward,
    LogicalKeyboardKey.arrowDown: AvatarKey.back,
    LogicalKeyboardKey.arrowLeft: AvatarKey.left,
    LogicalKeyboardKey.arrowRight: AvatarKey.right,
  };

  final ValueNotifier<Duration> _fixedTime = ValueNotifier(Duration.zero);
  final ViewResetSignal _resetView = ViewResetSignal();
  final FocusNode _pageFocus = FocusNode(debugLabel: 'office-page');
  final FocusNode _listButtonFocus = FocusNode(debugLabel: 'list-button');
  final FocusNode _helpButtonFocus = FocusNode(debugLabel: 'help-button');
  late final GuideMemory _ownMemory = GuideMemory();
  EntityRef? _selected;
  bool _guideOpen = false;

  /// 案内を [ヘルプ] から開いたか(閉じたときのフォーカス先を決める)。
  bool _guideFromHelp = false;
  bool _listOpen = false;
  double _width = 0;
  Timer? _timer;

  GuideMemory get _memory => widget.guideMemory ?? _ownMemory;
  ValueListenable<Duration> get _time => widget.virtualTime ?? _fixedTime;
  bool get _listBesideCard => _width >= officeListBesideCardBreakpoint;

  @override
  void initState() {
    super.initState();
    _guideOpen = !_memory.dismissed;
    _pageFocus.addListener(_onPageFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onPageFocusChange() {
    if (!_pageFocus.hasPrimaryFocus) widget.avatar?.releaseAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.avatar?.releaseAll();
  }

  /// 十字キー → 自分の操作。ページ自身が主フォーカスのときだけ受ける
  /// (一覧の行・ボタンなど子孫にフォーカスがあるときは、その部品の働きを優先する)。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final avatar = widget.avatar;
    final key = _keyMap[event.logicalKey];
    if (avatar == null || key == null) return KeyEventResult.ignored;
    if (!_pageFocus.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      avatar.setKey(key, false);
      return KeyEventResult.handled;
    }
    if (_guideOpen) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    if (kb.isMetaPressed || kb.isControlPressed || kb.isAltPressed) {
      return KeyEventResult.ignored;
    }
    avatar.setKey(key, true);
    return KeyEventResult.handled;
  }

  /// 選択の唯一の更新口(3D の onPick・一覧・カードの × が呼ぶ)。
  void _select(EntityRef? ref) {
    if (ref == _selected) return;
    final closesList = ref != null && _listOpen && !_listBesideCard;
    setState(() {
      _selected = ref;
      // 狭い幅は一覧とカードを同時に出さない。
      if (closesList) _listOpen = false;
    });
    _syncTimer();
    _restoreFocus(preferred: closesList ? _listButtonFocus : null);
  }

  /// 3D の onPick。背景(null)ではカードと一覧を閉じる。案内は閉じない。
  void _onPick(EntityRef? ref) {
    if (ref != null) {
      _select(ref);
    } else {
      setState(() {
        _selected = null;
        _listOpen = false;
      });
      _syncTimer();
      _restoreFocus();
    }
    // 3D をクリックしたら十字キーが効くよう、ページにフォーカスを戻す。
    _pageFocus.requestFocus();
  }

  void _openNotes() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DevNotesPage(loader: widget.notesLoader),
      ),
    );
  }

  void _openGuide() {
    widget.avatar?.releaseAll();
    setState(() {
      _guideOpen = true;
      _guideFromHelp = true;
    });
  }

  void _closeGuide() {
    _memory.dismissed = true;
    setState(() => _guideOpen = false);
    // 起動時に自動で開いた案内には開いたボタンが無い。ページへ戻して十字キーを効かせる。
    _restoreFocus(preferred: _guideFromHelp ? _helpButtonFocus : null);
  }

  void _toggleList() {
    setState(() {
      _listOpen = !_listOpen;
      if (_listOpen && !_listBesideCard) _selected = null;
    });
    _syncTimer();
    if (!_listOpen) _restoreFocus(preferred: _listButtonFocus);
  }

  void _closeList() {
    setState(() => _listOpen = false);
    _syncTimer();
    _restoreFocus(preferred: _listButtonFocus);
  }

  /// 案内 → カード → 一覧 の順に、開いている最初の 1 つだけ閉じる。
  void _onEscape() {
    if (_guideOpen) {
      _closeGuide();
    } else if (_selected != null) {
      _select(null);
    } else if (_listOpen) {
      _closeList();
    }
  }

  /// 閉じた部品の中にあったフォーカスが消えたら、開いたボタン(なければページ)へ戻す。
  void _restoreFocus({FocusNode? preferred}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageFocus.hasFocus) return;
      final target = preferred?.context != null ? preferred! : _pageFocus;
      target.requestFocus();
    });
  }

  /// カードやタイマーのために、カードか一覧が出ている間だけ定期的に読み直す。
  void _syncTimer() {
    if (_selected == null && !_listOpen) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  TargetStatus? _statusOfSelected() {
    final ref = _selected;
    if (ref == null) return null;
    return statusOf(
      ref,
      widget.data,
      time: _time.value,
      lookup: personLookupOf(widget.simulation),
    );
  }

  @override
  void didUpdateWidget(OfficePage old) {
    super.didUpdateWidget(old);
    if (_selected != null && _statusOfSelected() == null) {
      _selected = null;
    }
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageFocus.removeListener(_onPageFocusChange);
    widget.avatar?.releaseAll();
    _timer?.cancel();
    _fixedTime.dispose();
    _resetView.dispose();
    _pageFocus.dispose();
    _listButtonFocus.dispose();
    _helpButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _onEscape},
      child: Focus(
        focusNode: _pageFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            final narrow = _width < officeNarrowBreakpoint;
            final items = <ToolbarItem>[
              ToolbarItem(
                key: const Key('reset-view-button'),
                label: resetViewLabel,
                icon: Icons.restart_alt,
                onPressed: _resetView.reset,
              ),
              ToolbarItem(
                key: const Key('list-button'),
                label: '一覧',
                icon: Icons.list_alt,
                onPressed: _toggleList,
                selected: _listOpen,
                focusNode: _listButtonFocus,
              ),
              ToolbarItem(
                key: const Key('notes-button'),
                menuKey: const Key('menu-notes'),
                label: '記録',
                icon: Icons.menu_book_outlined,
                onPressed: _openNotes,
                inMenuOnNarrow: true,
              ),
              ToolbarItem(
                key: const Key('help-button'),
                menuKey: const Key('menu-help'),
                label: 'ヘルプ',
                icon: Icons.help_outline,
                onPressed: _openGuide,
                inMenuOnNarrow: true,
                focusNode: _helpButtonFocus,
              ),
            ];
            final scaffold = Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Flutter Scene Demo (ダミーデータ)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: narrow
                    ? [OfficeMenuButton(items: items)]
                    : officeToolbarActions(context, items),
              ),
              bottomNavigationBar: narrow
                  ? OfficeBottomToolbar(items: items)
                  : null,
              body: LayoutBuilder(
                builder: (context, body) => _buildBody(context, body, narrow),
              ),
            );
            // 案内はツールバーも含めた全面を覆う(最前面)。
            return Stack(
              fit: StackFit.expand,
              children: [
                scaffold,
                if (_guideOpen)
                  Positioned.fill(
                    child: OperationGuideOverlay(onClose: _closeGuide),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BoxConstraints constraints,
    bool narrow,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final card = _selected == null
        ? null
        : ListenableBuilder(
            listenable: _time,
            builder: (context, _) {
              final status = _statusOfSelected();
              if (status == null) return const SizedBox.shrink();
              return InfoCard(status: status, onClose: () => _select(null));
            },
          );
    final hasCard = card != null && _statusOfSelected() != null;
    final list = _listOpen
        ? OfficeListPanel(
            data: widget.data,
            time: _time,
            lookup: personLookupOf(widget.simulation),
            selected: hasCard ? _selected : null,
            onSelect: _select,
            onClose: _closeList,
          )
        : null;

    return Stack(
      children: [
        Positioned.fill(
          child: widget.view.build(
            context,
            widget.data,
            onPick: _onPick,
            virtualTime: _time,
            resetView: _resetView,
          ),
        ),
        if (list != null && !narrow)
          Positioned(
            key: const Key('list-panel-side'),
            top: 0,
            bottom: 0,
            left: 0,
            width: _listBesideCard ? 300 : 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              ),
              child: list,
            ),
          ),
        if (list != null && narrow)
          Positioned(
            key: const Key('list-sheet'),
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * 0.7,
            child: Material(
              color: scheme.surfaceContainerLow,
              elevation: 3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: list,
            ),
          ),
        if (hasCard && !narrow)
          Positioned(
            key: const Key('info-card-side'),
            top: 0,
            bottom: 0,
            right: 0,
            width: constraints.maxWidth < 900 ? 320 : 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(left: BorderSide(color: scheme.outlineVariant)),
              ),
              child: card,
            ),
          ),
        if (hasCard && narrow)
          Positioned(
            key: const Key('info-card-sheet'),
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * 0.4,
            child: Material(
              color: scheme.surfaceContainerLow,
              elevation: 3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: card,
            ),
          ),
      ],
    );
  }
}
