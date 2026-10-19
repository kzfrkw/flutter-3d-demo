import 'package:flutter_3d_demo/office/scene/camera_yaw.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCameraYaw', () {
    double? p(String q) => parseCameraYaw(Uri.parse('http://x/$q'));
    test('無い・数でない・有限でない → null', () {
      expect(p(''), isNull);
      expect(p('?cameraYaw=abc'), isNull);
      expect(p('?cameraYaw='), isNull);
      expect(p('?cameraYaw=NaN'), isNull);
      expect(p('?cameraYaw=Infinity'), isNull);
    });
    test('数値と正規化', () {
      expect(p('?cameraYaw=90'), 90);
      expect(p('?cameraYaw=-90'), -90);
      expect(p('?cameraYaw=270'), -90);
      expect(p('?cameraYaw=180'), 180);
      expect(p('?cameraYaw=-180'), 180);
      expect(p('?cameraYaw=360'), 0);
      expect(p('?cameraYaw=45.5'), 45.5);
    });
  });

  group('rotateAboutY', () {
    void expectXz(({double x, double z}) r, double x, double z) {
      expect(r.x, closeTo(x, 1e-9));
      expect(r.z, closeTo(z, 1e-9));
    }

    test('0 / 90 / 180 / -90', () {
      expectXz(rotateAboutY(0, -1, 0), 0, -1);
      expectXz(rotateAboutY(0, -1, 90), -1, 0); // -X 側
      expectXz(rotateAboutY(0, -1, 180), 0, 1); // +Z 側(奥)
      expectXz(rotateAboutY(0, -1, -90), 1, 0); // +X 側
    });
  });
}
