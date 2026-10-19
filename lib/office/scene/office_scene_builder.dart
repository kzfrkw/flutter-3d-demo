import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../data/office_models.dart' hide Route;
import '../people/people_simulation.dart';
import '../status/office_status.dart';
import 'camera_yaw.dart';
import 'entity_pick.dart';
import 'label_placement.dart';
import 'office_layout.dart';
import 'office_scene_view.dart';
import 'scene_labels.dart';

/// flutter_scene で実際に描く本物の実装。箱だけでオフィスを組む。
/// Flutter GPU / WebGL2 が要るため `flutter test` では動かない(QA で確かめる)。
class FlutterSceneOfficeView implements OfficeSceneView {
  const FlutterSceneOfficeView({
    this.style = const LayoutStyle(),
    this.simulation,
    this.cameraYawDegrees = 0,
  });

  final LayoutStyle style;

  /// 開発者用: 初期カメラの水平方向を Y 軸まわりに回す(度)。0 = 手前(-Z 側)。
  final double cameraYawDegrees;

  /// 人の動き。null なら描画側が [data] から作る。渡すときは、同じ data から作ったものであること
  /// (T4 で名札などと共有するため)。
  final PeopleSimulation? simulation;

  @override
  Widget build(
    BuildContext context,
    OfficeData data, {
    ValueChanged<EntityRef?>? onPick,
    ValueListenable<Duration>? virtualTime,
  }) => _OfficeSceneWidget(
    data: data,
    style: style,
    simulation: simulation,
    cameraYawDegrees: cameraYawDegrees,
    onPick: onPick,
    virtualTime: virtualTime,
  );
}

class _OfficeSceneWidget extends StatefulWidget {
  const _OfficeSceneWidget({
    required this.data,
    required this.style,
    this.simulation,
    this.cameraYawDegrees = 0,
    this.onPick,
    this.virtualTime,
  });

  final OfficeData data;
  final LayoutStyle style;
  final PeopleSimulation? simulation;
  final double cameraYawDegrees;
  final ValueChanged<EntityRef?>? onPick;
  final ValueListenable<Duration>? virtualTime;

  @override
  State<_OfficeSceneWidget> createState() => _OfficeSceneWidgetState();
}

class _OfficeSceneWidgetState extends State<_OfficeSceneWidget> {
  final Scene _scene = Scene();
  Camera? _camera;
  String? _error;
  PeopleSimulation? _sim;
  final List<_PersonNode> _personNodes = [];
  final List<_TagNode> _tagNodes = [];
  final List<_PanelNode> _panelNodes = [];
  final ValueNotifier<Duration> _zeroTime = ValueNotifier(Duration.zero);
  final LabelStyle _labelStyle = const LabelStyle();

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
      _buildLabels(widget.data, sim);
      _camera = _buildCamera(widget.data, boxes, widget.cameraYawDegrees);
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
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onTap(camera, d.localPosition, constraints.biggest),
        child: SceneView(_scene, camera: camera, onTick: _onTick),
      ),
    );
  }

  /// タップ位置 → レイ → 当たったノード名 → EntityRef。何も無い所は null(背景)。
  void _onTap(Camera camera, Offset position, Size size) {
    final onPick = widget.onPick;
    if (onPick == null) return;
    final hit = _scene.raycast(camera.screenPointToRay(position, size));
    onPick(
      hit == null ? null : entityRefForNodeName(hit.node.name, widget.data),
    );
  }

  @override
  void dispose() {
    _zeroTime.dispose();
    super.dispose();
  }

  /// 名札(人ごと)と会議室パネル(部屋ごと)を、人とは別の Node に載せる。
  void _buildLabels(OfficeData data, PeopleSimulation sim) {
    final labels = Node(name: 'labels');
    final time = widget.virtualTime ?? _zeroTime;
    const update = WidgetUpdatePolicy.interval(Duration(milliseconds: 500));
    for (final walker in sim.walkers) {
      final person = data.personById(walker.personId);
      if (person == null) continue;
      final node = Node(name: tagNodeName(person.id));
      node.addComponent(
        WidgetComponent(
          size: const Size(180, 54),
          pixelRatio: 2,
          worldHeight: _labelStyle.tagHeight,
          geometry: _mirroredQuad(
            width: _labelStyle.tagWidth,
            height: _labelStyle.tagHeight,
          ),
          input: WidgetInput.manual,
          update: update,
          child: PersonTag(name: person.displayName),
        ),
      );
      labels.add(node);
      _tagNodes.add(_TagNode(walker, node));
    }
    for (final room in data.rooms) {
      final place = panelPlacement(room, style: _labelStyle);
      final node = Node(name: panelNodeName(room.id));
      node.addComponent(
        WidgetComponent(
          size: const Size(144, 96),
          pixelRatio: 2,
          worldHeight: _labelStyle.panelHeight,
          geometry: _mirroredQuad(
            width: _labelStyle.panelWidth,
            height: _labelStyle.panelHeight,
          ),
          input: WidgetInput.manual,
          update: update,
          child: ValueListenableBuilder<Duration>(
            valueListenable: time,
            builder: (context, t, _) =>
                RoomPanel(status: roomStatusAt(data, room, t)),
          ),
        ),
      );
      labels.add(node);
      _panelNodes.add(_PanelNode(place.center, node));
    }
    _scene.add(labels);
  }

  /// 面の表(ローカル -Z 側)を、カメラの視線の逆に向ける Y 軸まわりの角度。
  /// 正射影カメラなので全ラベル共通の視線方向を使う。
  double _billboardYaw() {
    final f = _camera?.forward;
    return f == null ? 0 : billboardYaw(f.x, f.z);
  }

  void _applyLabels() {
    final yaw = _billboardYaw();
    for (final t in _tagNodes) {
      final c = tagCenter(t.walker.position, style: _labelStyle);
      t.node.mutateLocalTransform((m) {
        m
          ..setIdentity()
          ..setTranslationRaw(c.x, c.y, c.z)
          ..rotateY(yaw);
      });
    }
    for (final p in _panelNodes) {
      p.node.mutateLocalTransform((m) {
        m
          ..setIdentity()
          ..setTranslationRaw(p.center.x, p.center.y, p.center.z)
          ..rotateY(yaw);
      });
    }
  }

  void _buildPeople(OfficeData data, PeopleSimulation sim) {
    final bodyGeometry = CapsuleGeometry(
      radius: personRadius,
      height: personHeight - 2 * personRadius,
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
    _applyLabels();
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
          ..translateByDouble(0, personHeight / 2, 0, 1);
      });
    }
  }
}

class _PersonNode {
  _PersonNode(this.walker, this.node);

  final Walker walker;
  final Node node;
}

class _TagNode {
  _TagNode(this.walker, this.node);

  final Walker walker;
  final Node node;
}

class _PanelNode {
  _PanelNode(this.center, this.node);

  final Point3 center;
  final Node node;
}

/// 既定の四角形と同じ頂点・巻き順で、U だけ左右逆にした四角形(s0-check と同じ)。
/// 既定の四角形は -Z 側のカメラから見えるが文字が反転するため、UV で直す。
MeshGeometry _mirroredQuad({required double width, required double height}) {
  final hw = width / 2;
  final hh = height / 2;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw,
      -hh,
      0,
      -hw,
      -hh,
      0,
      -hw,
      hh,
      0,
      hw,
      hh,
      0,
    ]),
    texCoords: Float32List.fromList([1, 1, 0, 1, 0, 0, 1, 0]),
    indices: [0, 1, 3, 3, 1, 2],
  );
}

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
Camera _buildCamera(OfficeData data, List<LayoutBox> boxes, double yawDegrees) {
  final maxHeight = boxes.map((b) => b.bottomY + b.height).reduce(math.max);
  final minY = boxes.map((b) => b.bottomY).reduce(math.min);
  final bounds = vm.Aabb3.minMax(
    vm.Vector3(-data.floorSize.width / 2, minY, -data.floorSize.depth / 2),
    vm.Vector3(data.floorSize.width / 2, maxHeight, data.floorSize.depth / 2),
  );
  final xz = rotateAboutY(0.35, -1, yawDegrees);
  return OrthographicCamera.framing(
    bounds,
    direction: vm.Vector3(xz.x, 0.9, xz.z),
  );
}
