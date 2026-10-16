import 'package:flutter_3d_demo/check/check_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('/?check は s0-check', () {
    expect(isCheckMode(Uri.parse('http://localhost:8080/?check')), isTrue);
  });

  test('/?check#/ (ハッシュ方式の URL) も s0-check', () {
    expect(isCheckMode(Uri.parse('http://localhost:8080/?check#/')), isTrue);
  });

  test('クエリなしは s0-check ではない', () {
    expect(isCheckMode(Uri.parse('http://localhost:8080/')), isFalse);
  });

  test('check 以外のクエリは s0-check ではない', () {
    expect(isCheckMode(Uri.parse('http://localhost:8080/?other=1')), isFalse);
  });
}
