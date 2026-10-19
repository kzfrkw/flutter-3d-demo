import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card/info_card.dart';
import 'data/office_models.dart';
import 'people/people_simulation.dart';
import 'scene/office_scene_view.dart';
import 'status/office_status.dart';

/// 幅がこれ未満なら下シート、以上なら右の固定パネルでカードを出す。
const double officeNarrowBreakpoint = 600;

/// [視点リセット] ボタンの文言。
const String resetViewLabel = '視点リセット';

/// s1-office と s2-card。3D のオフィス(差し替え口の向こう)の上に情報カードを重ねる。
class OfficePage extends StatefulWidget {
  const OfficePage({
    super.key,
    required this.view,
    required this.data,
    this.simulation,
    this.virtualTime,
  });

  final OfficeSceneView view;
  final OfficeData data;

  /// カードの「現在の行動」「在席/離席」が読む。null なら全員 停止中・離席。
  final PeopleSimulation? simulation;

  /// 仮想時刻。null なら Duration.zero 固定。
  final ValueListenable<Duration>? virtualTime;

  @override
  State<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends State<OfficePage> {
  final ValueNotifier<Duration> _fixedTime = ValueNotifier(Duration.zero);
  final ViewResetSignal _resetView = ViewResetSignal();
  EntityRef? _selected;
  Timer? _timer;

  ValueListenable<Duration> get _time => widget.virtualTime ?? _fixedTime;

  /// 選択の唯一の更新口(3D の onPick・将来の一覧が呼ぶ)。
  void _select(EntityRef? ref) {
    if (ref == _selected) return;
    setState(() => _selected = ref);
    _syncTimer();
  }

  /// カードが出ている間だけ、歩行中/停止中などを読み直すタイマーを動かす。
  void _syncTimer() {
    if (_selected == null) {
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
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fixedTime.dispose();
    _resetView.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Scene Demo (ダミーデータ)'),
        actions: [
          // 狭い幅は題名が欠けるので、ボタンは 3D の右上に重ねる(_buildBody)。
          if (MediaQuery.sizeOf(context).width >= officeNarrowBreakpoint)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const Key('reset-view-button'),
                onPressed: _resetView.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text(resetViewLabel),
              ),
            ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _select(null),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(builder: _buildBody),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = constraints.maxWidth < officeNarrowBreakpoint;
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

    return Stack(
      children: [
        Positioned.fill(
          child: widget.view.build(
            context,
            widget.data,
            onPick: _select,
            virtualTime: _time,
            resetView: _resetView,
          ),
        ),
        if (narrow)
          Positioned(
            top: 8,
            right: 8,
            child: FilledButton.tonalIcon(
              key: const Key('reset-view-button'),
              onPressed: _resetView.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text(resetViewLabel),
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
