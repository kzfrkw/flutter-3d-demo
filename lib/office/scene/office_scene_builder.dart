import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../data/office_models.dart';
import 'office_layout.dart';
import 'office_scene_view.dart';

/// flutter_scene で実際に描く本物の実装。箱だけでオフィスを組む。
/// Flutter GPU / WebGL2 が要るため `flutter test` では動かない(QA で確かめる)。
class FlutterSceneOfficeView implements OfficeSceneView {
  const FlutterSceneOfficeView({this.style = const LayoutStyle()});

  final LayoutStyle style;

  @override
  Widget build(BuildContext context, OfficeData data) =>
      _OfficeSceneWidget(data: data, style: style);
}

class _OfficeSceneWidget extends StatefulWidget {
  const _OfficeSceneWidget({required this.data, required this.style});

  final OfficeData data;
  final LayoutStyle style;

  @override
  State<_OfficeSceneWidget> createState() => _OfficeSceneWidgetState();
}

class _OfficeSceneWidgetState extends State<_OfficeSceneWidget> {
  final Scene _scene = Scene();
  Camera? _camera;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<void> _setUp() async {
    try {
      await Scene.initializeStaticResources();
      final boxes = buildOfficeLayout(widget.data, style: widget.style);
      _scene.add(_buildOfficeNode(boxes));
      _camera = _buildCamera(widget.data, boxes);
    } catch (e, st) {
      debugPrint('s1-office: $e\n$st');
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Text('3D の読み込みに失敗しました: $error'));
    }
    final camera = _camera;
    if (camera == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SceneView(_scene, camera: camera);
  }
}

/// 箱の一覧から Node の木を作る。Node の name は [LayoutBox.id]。
Node _buildOfficeNode(List<LayoutBox> boxes) {
  final materials = <int, PhysicallyBasedMaterial>{};
  PhysicallyBasedMaterial materialFor(int argb) =>
      materials.putIfAbsent(argb, () {
        return PhysicallyBasedMaterial()
          ..baseColorFactor = vm.Vector4(
            ((argb >> 16) & 0xFF) / 255,
            ((argb >> 8) & 0xFF) / 255,
            (argb & 0xFF) / 255,
            ((argb >> 24) & 0xFF) / 255,
          )
          ..metallicFactor = 0
          ..roughnessFactor = 0.9;
      });

  final root = Node(name: 'office');
  for (final box in boxes) {
    final transform = vm.Matrix4.identity()
      ..translateByVector3(
        vm.Vector3(box.center.x, box.bottomY + box.height / 2, box.center.z),
      )
      ..rotateY(box.yaw);
    root.add(
      Node(
        name: box.id,
        localTransform: transform,
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(box.width, box.height, box.depth)),
          materialFor(box.color),
        ),
      ),
    );
  }
  return root;
}

/// -Z 側(手前)の斜め上から全体を収める、固定のアイソメ風カメラ。
/// (3D 面に載せるウィジェットは -Z 側から見えるため、T4 の都合でこちら側に置く。)
Camera _buildCamera(OfficeData data, List<LayoutBox> boxes) {
  final maxHeight = boxes.map((b) => b.bottomY + b.height).reduce(math.max);
  final minY = boxes.map((b) => b.bottomY).reduce(math.min);
  final bounds = vm.Aabb3.minMax(
    vm.Vector3(-data.floorSize.width / 2, minY, -data.floorSize.depth / 2),
    vm.Vector3(data.floorSize.width / 2, maxHeight, data.floorSize.depth / 2),
  );
  return OrthographicCamera.framing(
    bounds,
    direction: vm.Vector3(0.35, 0.9, -1),
  );
}
