import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../data/office_models.dart' hide Route;
import '../people/people_simulation.dart';
import 'office_layout.dart';
import 'office_scene_view.dart';

/// flutter_scene で実際に描く本物の実装。箱だけでオフィスを組む。
/// Flutter GPU / WebGL2 が要るため `flutter test` では動かない(QA で確かめる)。
class FlutterSceneOfficeView implements OfficeSceneView {
  const FlutterSceneOfficeView({
    this.style = const LayoutStyle(),
    this.simulation,
  });

  final LayoutStyle style;

  /// 人の動き。null なら描画側が [data] から作る。渡すときは、同じ data から作ったものであること
  /// (T4 で名札などと共有するため)。
  final PeopleSimulation? simulation;

  @override
  Widget build(BuildContext context, OfficeData data) =>
      _OfficeSceneWidget(data: data, style: style, simulation: simulation);
}

class _OfficeSceneWidget extends StatefulWidget {
  const _OfficeSceneWidget({
    required this.data,
    required this.style,
    this.simulation,
  });

  final OfficeData data;
  final LayoutStyle style;
  final PeopleSimulation? simulation;

  @override
  State<_OfficeSceneWidget> createState() => _OfficeSceneWidgetState();
}

class _OfficeSceneWidgetState extends State<_OfficeSceneWidget> {
  final Scene _scene = Scene();
  Camera? _camera;
  String? _error;
  PeopleSimulation? _sim;
  final List<_PersonNode> _personNodes = [];

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
      final sim = widget.simulation ?? PeopleSimulation(widget.data);
      _sim = sim;
      _buildPeople(widget.data, sim);
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
    return SceneView(_scene, camera: camera, onTick: _onTick);
  }

  void _buildPeople(OfficeData data, PeopleSimulation sim) {
    final bodyGeometry = CapsuleGeometry(
      radius: _personRadius,
      height: _personHeight - 2 * _personRadius,
      radialSegments: 16,
      capRings: 4,
    );
    final noseGeometry = CuboidGeometry(vm.Vector3(0.14, 0.14, 0.2));
    final noseMaterial = _colorMaterial(_noseColor);
    final bodyMaterials = <int, PhysicallyBasedMaterial>{};
    final people = Node(name: 'people');
    for (final walker in sim.walkers) {
      final index = data.people.indexWhere((p) => p.id == walker.personId);
      final color = _personPalette[index % _personPalette.length];
      final material = bodyMaterials.putIfAbsent(
        color,
        () => _colorMaterial(color),
      );
      final body = Node(
        name: '${walker.personId}#body',
        mesh: Mesh(bodyGeometry, material),
      );
      body.add(
        Node(
          name: '${walker.personId}#nose',
          localTransform: vm.Matrix4.translation(vm.Vector3(0, 0.5, 0.27)),
          mesh: Mesh(noseGeometry, noseMaterial),
        ),
      );
      people.add(body);
      _personNodes.add(_PersonNode(walker, body));
    }
    _scene.add(people);
    _applyTransforms();
  }

  void _onTick(Duration elapsed, double dt) {
    _sim?.step(dt);
    _applyTransforms();
  }

  /// Walker の値を Node の変換に写す: T(x, bob, z) · Ry(yaw) · Rz(lean) · T(0, 0.8, 0)。
  void _applyTransforms() {
    for (final p in _personNodes) {
      final w = p.walker;
      p.node.mutateLocalTransform((m) {
        m
          ..setIdentity()
          ..setTranslationRaw(w.x, w.bob, w.z)
          ..rotateY(w.yaw)
          ..rotateZ(w.lean)
          ..translateByDouble(0, _personHeight / 2, 0, 1);
      });
    }
  }
}

class _PersonNode {
  _PersonNode(this.walker, this.node);

  final Walker walker;
  final Node node;
}

const double _personHeight = 1.6;
const double _personRadius = 0.25;
const int _noseColor = 0xFFFFE066;

/// 人ごとの色(OfficeData の people の順に使う)。
const List<int> _personPalette = [
  0xFFE4572E,
  0xFF29B6F6,
  0xFF66BB6A,
  0xFFAB47BC,
  0xFFFFA726,
  0xFFEC407A,
  0xFF26A69A,
  0xFF8D6E63,
  0xFF5C6BC0,
  0xFFD4E157,
];

PhysicallyBasedMaterial _colorMaterial(int argb) => PhysicallyBasedMaterial()
  ..baseColorFactor = vm.Vector4(
    ((argb >> 16) & 0xFF) / 255,
    ((argb >> 8) & 0xFF) / 255,
    (argb & 0xFF) / 255,
    ((argb >> 24) & 0xFF) / 255,
  )
  ..metallicFactor = 0
  ..roughnessFactor = 0.8;

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
