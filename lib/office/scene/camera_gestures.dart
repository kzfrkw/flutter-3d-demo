import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'camera_orbit.dart';

/// 3D ビューの入力(ドラッグ・ホイール・ピンチ・タップ)を [CameraOrbit] に反映する。
/// `GestureDetector` の scale 系は右ボタンを区別できないため、`Listener` で自前に判定する。
///
/// - マウス左ドラッグ = 回転、右/中ドラッグ = パン、ホイール = ズーム、PointerScale = ズーム
/// - タッチ 1 本 = 回転、2 本 = ピンチでズーム + 中点の移動でパン
/// - 押した位置からスロップ以内で離した左ボタン/タッチだけ [onTap]
class OrbitGestureLayer extends StatefulWidget {
  const OrbitGestureLayer({
    super.key,
    required this.orbit,
    required this.onTap,
    required this.child,
  });

  final CameraOrbit orbit;

  /// ドラッグでなかった 1 本指/左ボタンの押して離す。位置はこのウィジェットのローカル座標。
  final void Function(Offset localPosition, Size size) onTap;
  final Widget child;

  static const double mouseSlop = 6;
  static const double touchSlop = 12;

  @override
  State<OrbitGestureLayer> createState() => _OrbitGestureLayerState();
}

class _Pointer {
  _Pointer(this.kind, this.buttons, this.start) : last = start;

  final PointerDeviceKind kind;
  final int buttons;
  final Offset start;
  Offset last;
  bool dragging = false;

  bool get isMouse => kind == PointerDeviceKind.mouse;
}

class _OrbitGestureLayerState extends State<OrbitGestureLayer> {
  final Map<int, _Pointer> _pointers = {};
  Size _size = Size.zero;

  /// 途中で 2 本目が付いた(タップにしない)。
  bool _multi = false;
  double? _pinchDistance;
  Offset? _pinchCenter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          onPointerSignal: _signal,
          child: widget.child,
        );
      },
    );
  }

  void _down(PointerDownEvent e) {
    if (_pointers.isEmpty) _multi = false;
    _pointers[e.pointer] = _Pointer(e.kind, e.buttons, e.localPosition);
    if (_pointers.length >= 2) {
      _multi = true;
      final pts = _pointers.values.take(2).map((p) => p.last).toList();
      _pinchDistance = (pts[0] - pts[1]).distance;
      _pinchCenter = (pts[0] + pts[1]) / 2;
    }
  }

  void _move(PointerMoveEvent e) {
    final p = _pointers[e.pointer];
    if (p == null) return;
    if (_pointers.length >= 2) {
      p.last = e.localPosition;
      _pinch();
      return;
    }
    final slop = p.isMouse
        ? OrbitGestureLayer.mouseSlop
        : OrbitGestureLayer.touchSlop;
    if (!p.dragging) {
      if ((e.localPosition - p.start).distance <= slop) return;
      p.dragging = true;
      // 超えた時点からの差分を反映する(超える前の動きは捨てる)。
      p.last = e.localPosition;
      return;
    }
    final d = e.localPosition - p.last;
    p.last = e.localPosition;
    if (p.isMouse &&
        (p.buttons & (kSecondaryButton | kMiddleMouseButton)) != 0) {
      widget.orbit.pan(
        d.dx,
        d.dy,
        viewWidth: _size.width,
        viewHeight: _size.height,
      );
    } else {
      widget.orbit.rotate(d.dx, d.dy);
    }
  }

  void _pinch() {
    final pts = _pointers.values.take(2).map((p) => p.last).toList();
    final dist = (pts[0] - pts[1]).distance;
    final c = (pts[0] + pts[1]) / 2;
    final d0 = _pinchDistance;
    final c0 = _pinchCenter;
    _pinchDistance = dist;
    _pinchCenter = c;
    if (d0 == null || c0 == null) return;
    if (d0 > 0 && dist > 0) widget.orbit.zoomBy(dist / d0);
    final dc = c - c0;
    widget.orbit.pan(
      dc.dx,
      dc.dy,
      viewWidth: _size.width,
      viewHeight: _size.height,
    );
  }

  void _up(PointerUpEvent e) {
    final p = _pointers.remove(e.pointer);
    if (p == null) return;
    _pinchDistance = null;
    _pinchCenter = null;
    final primary = !p.isMouse || (p.buttons & kPrimaryButton) != 0;
    if (!p.dragging && !_multi && primary) {
      widget.onTap(e.localPosition, _size);
    }
  }

  void _cancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    _multi = true; // 残りの指があっても、この一連の操作はタップにしない。
    _pinchDistance = null;
    _pinchCenter = null;
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(e, (event) {
        widget.orbit.zoomByScroll((event as PointerScrollEvent).scrollDelta.dy);
      });
    } else if (e is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(e, (event) {
        widget.orbit.zoomBy((event as PointerScaleEvent).scale);
      });
    }
  }
}
