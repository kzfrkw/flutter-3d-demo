import 'package:flutter/foundation.dart';

/// 仮想時刻の時計。`cycleLength` で一巡する速い時計で、実時間 1 倍で進む。
/// 進めるのは描画の onTick(人の動きと同じ場所)。外から [advance] で進めるのでテストで止められる。
class VirtualClock extends ChangeNotifier implements ValueListenable<Duration> {
  VirtualClock({
    required Duration cycleLength,
    Duration start = Duration.zero,
    this.resolution = const Duration(milliseconds: 250),
  }) : _cycle = cycleLength.inMicroseconds {
    _micros = _cycle > 0 ? start.inMicroseconds % _cycle : 0;
    _value = _quantize();
  }

  /// [value] の刻み。通知はこの刻みで変わったときだけ。
  final Duration resolution;
  final int _cycle;

  // 内部は μs の整数で積算する(浮動小数の誤差を貯めない)。
  int _micros = 0;
  late Duration _value;

  /// 現在の仮想時刻。[0, cycleLength) を resolution 単位に切り下げた値。
  @override
  Duration get value => _value;

  Duration _quantize() {
    final r = resolution.inMicroseconds;
    return Duration(microseconds: r > 0 ? _micros - _micros % r : _micros);
  }

  /// 実時間 [dt] ぶん進める。一巡したら先頭に戻る。
  /// value が変わったときだけ通知する。dt が負・cycleLength が 0 以下なら何もしない。
  void advance(Duration dt) {
    if (_cycle <= 0 || dt.isNegative) return;
    _micros = (_micros + dt.inMicroseconds % _cycle) % _cycle;
    final next = _quantize();
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}

/// 開発者用 `?time=<秒>`。無い・数でない・有限でない・負は null。範囲は [cycle] で剰余。
Duration? parseVirtualTimeStart(Uri uri, Duration cycle) {
  final raw = uri.queryParameters['time'];
  if (raw == null) return null;
  final v = double.tryParse(raw);
  if (v == null || !v.isFinite || v < 0) return null;
  final micros = (v * Duration.microsecondsPerSecond).round();
  if (cycle <= Duration.zero) return Duration(microseconds: micros);
  return Duration(microseconds: micros % cycle.inMicroseconds);
}
