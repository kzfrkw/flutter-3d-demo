import 'dart:math' as math;

/// 開発者用: `?cameraYaw=<度>`。無い・数でない・有限でないときは null。
/// 範囲は (−180, 180] に正規化する。
double? parseCameraYaw(Uri uri) {
  final raw = uri.queryParameters['cameraYaw'];
  if (raw == null) return null;
  final v = double.tryParse(raw);
  if (v == null || !v.isFinite) return null;
  var r = v % 360;
  if (r > 180) r -= 360;
  if (r <= -180) r += 360;
  return r;
}

/// (x, z) を Y 軸まわりに degrees 度回す(vm.Matrix4.rotationY と同じ向き)。
({double x, double z}) rotateAboutY(double x, double z, double degrees) {
  final t = degrees * math.pi / 180;
  final c = math.cos(t);
  final s = math.sin(t);
  return (x: x * c + z * s, z: -x * s + z * c);
}
