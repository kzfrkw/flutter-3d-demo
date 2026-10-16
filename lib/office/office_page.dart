import 'package:flutter/material.dart';

import 'data/office_models.dart';
import 'scene/office_scene_view.dart';

/// s1-office。見出しと、3D のオフィス(差し替え口の向こう)を置く。
class OfficePage extends StatelessWidget {
  const OfficePage({super.key, required this.view, required this.data});

  final OfficeSceneView view;
  final OfficeData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Scene Demo (ダミーデータ)')),
      body: view.build(context, data),
    );
  }
}
