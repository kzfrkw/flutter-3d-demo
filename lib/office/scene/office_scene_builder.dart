import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../data/office_models.dart' hide Route;
import '../people/avatar_controller.dart';
import '../people/people_simulation.dart';
import '../status/office_status.dart';
import '../status/virtual_clock.dart';
import '../status_style.dart';
import 'browser_env.dart';
import 'camera_gestures.dart';
import 'camera_orbit.dart';
import 'entity_pick.dart';
import 'label_placement.dart';
import 'office_layout.dart';
import 'office_scene_view.dart';
import 'scene_labels.dart';
import 'scene_loading.dart';

/// flutter_scene で実際に描く本物の実装。箱だけでオフィスを組む。
/// Flutter GPU / WebGL2 が要るため `flutter test` では動かない(QA で確かめる)。
class FlutterSceneOfficeView implements OfficeSceneView {
  const FlutterSceneOfficeView({
    this.style = const LayoutStyle(),
    this.simulation,
    this.cameraYawDegrees = 0,
    this.clock,
    this.avatar,
  });

  final LayoutStyle style;

  /// 仮想時刻の時計。描画の onTick が進める。null なら進めない(0 秒固定)。
  final VirtualClock? clock;

  /// 開発者用: 初期カメラの水平方向を Y 軸まわりに回す(度)。0 = 手前(-Z 側)。
  final double cameraYawDegrees;

  /// 人の動き。null なら描画側が [data] から作る。渡すときは、同じ data から作ったものであること
  /// (T4 で名札などと共有するため)。
  final PeopleSimulation? simulation;

  /// 十字キーで動かす自分。null なら出さない。OfficePage と同じものを共有する。
  final AvatarController? avatar;

  @override
  Widget build(
    BuildContext context,
    OfficeData data, {
    ValueChanged<EntityRef?>? onPick,
    ValueListenable<Duration>? virtualTime,
    ViewResetSignal? resetView,
  }) => _OfficeSceneWidget(
    data: data,
    style: style,
    simulation: simulation,
    avatar: avatar,
    cameraYawDegrees: cameraYawDegrees,
    clock: clock,
    onPick: onPick,
    virtualTime: virtualTime ?? clock,
    resetView: resetView,
  );
}

class _OfficeSceneWidget extends StatefulWidget {
  const _OfficeSceneWidget({
    required this.data,
    required this.style,
    this.simulation,
    this.avatar,
    this.cameraYawDegrees = 0,
    this.clock,
    this.onPick,
    this.virtualTime,
    this.resetView,
  });

  final OfficeData data;
  final LayoutStyle style;
  final PeopleSimulation? simulation;
  final AvatarController? avatar;
  final double cameraYawDegrees;
  final ValueChanged<EntityRef?>? onPick;
  final ValueListenable<Duration>? virtualTime;
  final VirtualClock? clock;
  final ViewResetSignal? resetView;

  @override
  State<_OfficeSceneWidget> createState() => _OfficeSceneWidgetState();
}

/// 外側。非 Web の [再読み込み] は `_attempt++` で中の State(Scene と読み込み)を作り直す。
class _OfficeSceneWidgetState extends State<_OfficeSceneWidget> {
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    // 右ドラッグ中のブラウザの右クリックメニューを出さない(3D ビューがある間だけ)。
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OfficeSceneBody(
    key: ValueKey(_attempt),
    widget: widget,
    onRetry: () => setState(() => _attempt++),
  );
}

class _OfficeSceneBody extends StatefulWidget {
  const _OfficeSceneBody({
    super.key,
    required this.widget,
    required this.onRetry,
  });

  final _OfficeSceneWidget widget;
  final VoidCallback onRetry;

  @override
  State<_OfficeSceneBody> createState() => _OfficeSceneBodyState();
}

class _OfficeSceneBodyState extends State<_OfficeSceneBody> {
  _OfficeSceneWidget get _w => widget.widget;
  final Scene _scene = Scene();
  Camera? _camera;
  CameraOrbit? _orbit;
  SceneLoadFailure? _failure;
  final Map<String, PhysicallyBasedMaterial> _roomFloorMaterials = {};
  final Map<String, RoomOccupancy> _roomFloorShown = {};
  PeopleSimulation? _sim;
  AvatarController? _avatar;
  Node? _avatarBody;
  Node? _avatarMark;
  final List<_PersonNode> _personNodes = [];
  final List<_TagNode> _tagNodes = [];
  final List<_PanelNode> _panelNodes = [];
  final ValueNotifier<Duration> _zeroTime = ValueNotifier(Duration.zero);
  final LabelStyle _labelStyle = const LabelStyle();

  @override
  void initState() {
    super.initState();
    _w.resetView?.addListener(_onReset);
    _setUp();
  }

  @override
  void didUpdateWidget(_OfficeSceneBody old) {
    super.didUpdateWidget(old);
    if (old.widget.resetView != _w.resetView) {
      old.widget.resetView?.removeListener(_onReset);
      _w.resetView?.addListener(_onReset);
    }
  }

  void _onReset() => _orbit?.reset();

  Future<void> _setUp() async {
    // WebGL2 が無いと分かっているときは、初期化を試さずに原因を出す。
    if (isWebGL2Supported() == false) {
      _failure = const SceneLoadFailure(SceneLoadFailureKind.webgl2Unsupported);
      if (mounted) setState(() {});
      return;
    }
    try {
      await Scene.initializeStaticResources();
      final boxes = buildOfficeLayout(_w.data, style: _w.style);
      _scene.add(_buildOfficeNode(boxes, _roomFloorMaterials));
      final sim = _w.simulation ?? PeopleSimulation(_w.data);
      _sim = sim;
      _buildPeople(_w.data, sim);
      _buildAvatar(_w.avatar);
      _buildLabels(_w.data, sim);
      final orbit = _buildOrbit(_w.data, boxes, _w.cameraYawDegrees);
      _orbit = orbit;
      _camera = _buildCamera(orbit);
      _applyCamera();
      _applyRoomFloors();
      (_w.virtualTime ?? _zeroTime).addListener(_applyRoomFloors);
    } catch (e, st) {
      debugPrint('s1-office: $e\n$st');
      _failure = SceneLoadFailure(
        SceneLoadFailureKind.loadFailed,
        detail: '$e',
      );
    }
    if (mounted) setState(() {});
  }

  /// [再読み込み]: Web ではページ全体を再読み込み(WebGL2 の状態を確実にやり直せる)。
  /// それ以外はシーンの初期化からやり直す。
  void _reload() {
    if (!reloadPage()) widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return SceneErrorView(failure: failure, onReload: _reload);
    }
    final camera = _camera;
    final orbit = _orbit;
    if (camera == null || orbit == null) {
      return const SceneLoading();
    }
    return Semantics(
      label: '3D オフィスビュー',
      child: OrbitGestureLayer(
        orbit: orbit,
        onTap: (position, size) => _onTap(camera, position, size),
        child: SceneView(_scene, camera: camera, onTick: _onTick),
      ),
    );
  }

  /// タップ位置 → レイ → 当たったノード名 → EntityRef。何も無い所は null(背景)。
  void _onTap(Camera camera, Offset position, Size size) {
    final onPick = _w.onPick;
    if (onPick == null) return;
    _applyCamera();
    final hit = _scene.raycast(camera.screenPointToRay(position, size));
    onPick(hit == null ? null : entityRefForNodeName(hit.node.name, _w.data));
  }

  @override
  void dispose() {
    _w.resetView?.removeListener(_onReset);
    (_w.virtualTime ?? _zeroTime).removeListener(_applyRoomFloors);
    _zeroTime.dispose();
    super.dispose();
  }

  /// 会議室の床の色を、パネル・カードと同じ roomStatusAt の結果に合わせる。
  /// 変わった部屋の材質だけ書き換える。
  void _applyRoomFloors() {
    final t = (_w.virtualTime ?? _zeroTime).value;
    for (final room in _w.data.rooms) {
      final material = _roomFloorMaterials[room.id];
      if (material == null) continue;
      final occ = roomStatusAt(_w.data, room, t).occupancy;
      if (_roomFloorShown[room.id] == occ) continue;
      _roomFloorShown[room.id] = occ;
      _setColor(material, roomFloorColor(occ).toARGB32());
    }
  }

  /// 名札(人ごと)と会議室パネル(部屋ごと)を、人とは別の Node に載せる。
  void _buildLabels(OfficeData data, PeopleSimulation sim) {
    final labels = Node(name: 'labels');
    final time = _w.virtualTime ?? _zeroTime;
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
      _tagNodes.add(_TagNode(() => walker.position, node));
    }
    final avatar = _avatar;
    if (avatar != null) {
      final node = Node(name: avatarTagNodeName());
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
          child: const AvatarTag(),
        ),
      );
      labels.add(node);
      _tagNodes.add(_TagNode(() => avatar.position, node));
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
      final c = tagCenter(t.position(), style: _labelStyle);
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

  /// 自分の体(カプセル + 鼻)と足元の印。ノード名は `player#...`(クリックは背景扱い)。
  void _buildAvatar(AvatarController? avatar) {
    if (avatar == null) return;
    _avatar = avatar;
    final body = Node(
      name: avatarBodyNodeName(),
      mesh: Mesh(
        CapsuleGeometry(
          radius: personRadius,
          height: personHeight - 2 * personRadius,
          radialSegments: 16,
          capRings: 4,
        ),
        _colorMaterial(_avatarColor),
      ),
    );
    body.add(
      Node(
        name: avatarNoseNodeName(),
        localTransform: vm.Matrix4.translation(vm.Vector3(0, 0.5, 0.27)),
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(0.14, 0.14, 0.2)),
          _colorMaterial(_noseColor),
        ),
      ),
    );
    // 足元の印: 体とは別 Node。x, z だけ追従する(向き・揺れは写さない)。
    final mark = Node(
      name: avatarMarkNodeName(),
      mesh: Mesh(
        CuboidGeometry(vm.Vector3(_avatarMarkSize, 0.02, _avatarMarkSize)),
        _colorMaterial(_avatarMarkColor),
      ),
    );
    final root = Node(name: 'avatar')
      ..add(body)
      ..add(mark);
    _scene.add(root);
    _avatarBody = body;
    _avatarMark = mark;
    _applyTransforms();
  }

  void _onTick(Duration elapsed, double dt) {
    _sim?.step(dt);
    final orbit = _orbit;
    if (orbit != null) {
      _avatar?.step(dt, view: orbit.frame.groundAxes(orbit.pose));
    }
    _w.clock?.advance(Duration(microseconds: (dt * 1e6).round()));
    _applyCamera();
    _applyTransforms();
    _applyLabels();
  }

  /// CameraOrbit の姿勢を、SceneView に渡した同じ Camera に書き写す。
  void _applyCamera() {
    final camera = _camera;
    final orbit = _orbit;
    if (camera is! OrthographicCamera || orbit == null) return;
    final frame = orbit.frame;
    final pose = orbit.pose;
    final eye = frame.eye(pose);
    final target = frame.target(pose);
    camera.position.setValues(eye.x, eye.y, eye.z);
    camera.target.setValues(target.x, target.y, target.z);
    camera.projection.zoom = pose.zoom;
    camera.projection.near = 0;
    camera.projection.far = frame.farDistance;
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
    final a = _avatar;
    if (a == null) return;
    _avatarBody?.mutateLocalTransform((m) {
      m
        ..setIdentity()
        ..setTranslationRaw(a.x, a.bob, a.z)
        ..rotateY(a.yaw)
        ..rotateZ(a.lean)
        ..translateByDouble(0, personHeight / 2, 0, 1);
    });
    // 会議室の床(高さ 0.02)の上に重ならない高さ。
    _avatarMark?.mutateLocalTransform((m) {
      m
        ..setIdentity()
        ..setTranslationRaw(a.x, 0.04, a.z);
    });
  }
}

class _PersonNode {
  _PersonNode(this.walker, this.node);

  final Walker walker;
  final Node node;
}

class _TagNode {
  _TagNode(this.position, this.node);

  /// 名札の下の人の床面位置(歩く人・自分で共通)。
  final FloorPoint Function() position;
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

/// 自分の体(ほぼ黒)。歩く人のパレットのどれとも違う。足元の印は鼻と同じ黄色の薄い板。
const int _avatarColor = 0xFF212121;
const int _avatarMarkColor = 0xFFFFE066;
const double _avatarMarkSize = 1.0;

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
  ..metallicFactor = 0
  ..roughnessFactor = 0.8
  ..baseColorFactor = _argbToVector4(argb);

vm.Vector4 _argbToVector4(int argb) => vm.Vector4(
  ((argb >> 16) & 0xFF) / 255,
  ((argb >> 8) & 0xFF) / 255,
  (argb & 0xFF) / 255,
  ((argb >> 24) & 0xFF) / 255,
);

void _setColor(PhysicallyBasedMaterial m, int argb) =>
    m.baseColorFactor = _argbToVector4(argb);

/// 箱の一覧から Node の木を作る。Node の name は [LayoutBox.id]。
/// 会議室の床(`<roomId>#floor`)は部屋ごとの材質を [roomFloorMaterials] に入れて、色を後から変えられるようにする。
Node _buildOfficeNode(
  List<LayoutBox> boxes,
  Map<String, PhysicallyBasedMaterial> roomFloorMaterials,
) {
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
    final ref = box.ref;
    final PhysicallyBasedMaterial material;
    if (box.kind == BoxKind.roomFloor && ref != null) {
      material = PhysicallyBasedMaterial()
        ..metallicFactor = 0
        ..roughnessFactor = 0.9
        ..baseColorFactor = _argbToVector4(box.color);
      roomFloorMaterials[ref.id] = material;
    } else {
      material = materialFor(box.color);
    }
    root.add(
      Node(
        name: box.id,
        localTransform: transform,
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(box.width, box.height, box.depth)),
          material,
        ),
      ),
    );
  }
  return root;
}

/// 全体を収める枠・上限・初期姿勢から [CameraOrbit] を作る。
/// 初期の見え方は T4 までの固定カメラ(-Z 側の斜め上、direction (0.35, 0.9, -1))と同じ。
/// (3D 面に載せるウィジェットは -Z 側から見えるため、T4 の都合でこちら側に置く。)
CameraOrbit _buildOrbit(
  OfficeData data,
  List<LayoutBox> boxes,
  double yawDegrees,
) {
  final maxHeight = boxes.map((b) => b.bottomY + b.height).reduce(math.max);
  final minY = boxes.map((b) => b.bottomY).reduce(math.min);
  final frame = OrbitFrame.fromBounds(
    minX: -data.floorSize.width / 2,
    minY: minY,
    minZ: -data.floorSize.depth / 2,
    maxX: data.floorSize.width / 2,
    maxY: maxHeight,
    maxZ: data.floorSize.depth / 2,
  );
  return CameraOrbit(
    frame: frame,
    limits: OrbitLimits.forFloor(data.floorSize),
    initial: initialPose(frame, yawDegrees: yawDegrees),
  );
}

/// 初期姿勢の正射影カメラ。以降は同じインスタンスを毎フレーム更新する(_applyCamera)。
Camera _buildCamera(CameraOrbit orbit) {
  final frame = orbit.frame;
  final camera = OrthographicCamera(
    projection: OrthographicProjection(
      size: OrthographicSize.contain(2 * frame.reach, 2 * frame.reach),
      far: frame.farDistance,
    ),
  );
  return camera;
}
