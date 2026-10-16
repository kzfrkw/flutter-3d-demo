import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'check_result.dart';
import 'scene_probe.dart';

/// flutter_scene を実際に呼んで 3 項目を確かめる本物の実装。
/// Flutter GPU / WebGL2 が要るため `flutter test` では動かない(QA で確かめる)。
class FlutterSceneProbe implements SceneProbe {
  @override
  Widget buildView(BuildContext context, CheckReporter report) =>
      _ProbeView(report: report);
}

const _modelPath = 'assets/models/check_cube.glb';

class _ProbeView extends StatefulWidget {
  const _ProbeView({required this.report});

  final CheckReporter report;

  @override
  State<_ProbeView> createState() => _ProbeViewState();
}

class _ProbeViewState extends State<_ProbeView> {
  final Scene _scene = Scene();
  bool _ready = false;
  WidgetComponent? _panel;
  AnimationClip? _clip;
  bool _embedReported = false;
  bool _animReported = false;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<void> _setUp() async {
    try {
      await Scene.initializeStaticResources();
      final model = await loadScene(_modelPath);
      final meshCount = model.meshNodes.length;
      if (meshCount == 0) {
        throw StateError('モデルにメッシュが無い');
      }
      _scene.add(model);
      widget.report(CheckItem.gltf, const CheckResult.ok());
      _setUpWidget();
      _setUpAnimation(model);
    } catch (e, st) {
      debugPrint('s0-check: $e\n$st');
      widget.report(CheckItem.gltf, CheckResult.ng('$e'));
      widget.report(
        CheckItem.widgetEmbed,
        const CheckResult.ng('glTF の読み込みに失敗したため未確認'),
      );
      widget.report(
        CheckItem.animation,
        const CheckResult.ng('glTF の読み込みに失敗したため未確認'),
      );
    }
    if (mounted) setState(() => _ready = true);
  }

  void _setUpWidget() {
    try {
      final panel = WidgetComponent(
        size: const Size(240, 80),
        pixelRatio: 2,
        worldHeight: 0.5,
        child: const Material(
          color: Colors.white,
          child: Center(
            child: Text(
              'Hello Widget',
              style: TextStyle(fontSize: 28, color: Colors.black),
            ),
          ),
        ),
      );
      final node = Node(name: 'widget-panel')..position = vm.Vector3(0, 1.3, 0);
      node.addComponent(panel);
      _scene.add(node);
      _panel = panel;
    } catch (e, st) {
      debugPrint('s0-check: $e\n$st');
      widget.report(CheckItem.widgetEmbed, CheckResult.ng('$e'));
    }
  }

  void _setUpAnimation(Node model) {
    try {
      final owner = _findAnimationOwner(model);
      if (owner == null) {
        throw StateError('モデルにアニメーションが無い');
      }
      final clip = owner.createAnimationClip(owner.parsedAnimations.first)
        ..loop = true
        ..play();
      _clip = clip;
    } catch (e, st) {
      debugPrint('s0-check: $e\n$st');
      widget.report(CheckItem.animation, CheckResult.ng('$e'));
    }
  }

  Node? _findAnimationOwner(Node node) {
    if (node.parsedAnimations.isNotEmpty) return node;
    for (final child in node.children) {
      final found = _findAnimationOwner(child);
      if (found != null) return found;
    }
    return null;
  }

  /// 毎フレーム呼ばれる。実際に値が動いたことを見て OK にする。
  void _onTick(Duration elapsed, double dt) {
    final clip = _clip;
    if (!_animReported && clip != null && clip.playbackTime > 0) {
      _animReported = true;
      widget.report(CheckItem.animation, const CheckResult.ok());
    }
    final panel = _panel;
    if (!_embedReported && panel != null) {
      if (panel.controller.texture != null) {
        _embedReported = true;
        widget.report(CheckItem.widgetEmbed, const CheckResult.ok());
      } else if (elapsed > const Duration(seconds: 10)) {
        _embedReported = true;
        widget.report(
          CheckItem.widgetEmbed,
          const CheckResult.ng('10 秒たってもウィジェットのテクスチャが得られない'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return SceneView(
      _scene,
      camera: PerspectiveCamera(
        position: vm.Vector3(0, 1.2, -4),
        target: vm.Vector3(0, 0.6, 0),
      ),
      onTick: _onTick,
    );
  }
}
