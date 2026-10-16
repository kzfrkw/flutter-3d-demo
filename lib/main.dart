import 'package:flutter/material.dart';

import 'check/check_mode.dart';
import 'check/check_page.dart';
import 'check/env_info.dart';
import 'check/flutter_scene_probe.dart';
import 'check/scene_probe.dart';

void main() {
  runApp(App(checkMode: isCheckMode(Uri.base), probe: FlutterSceneProbe()));
}

class App extends StatelessWidget {
  const App({super.key, required this.checkMode, required this.probe});

  /// URL に `?check` があるか。true なら s0-check を表示する。
  final bool checkMode;
  final SceneProbe probe;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 3D Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
      home: checkMode
          ? CheckPage(probe: probe, env: EnvInfo.current())
          : const Scaffold(body: Center(child: Text('準備中'))),
    );
  }
}
