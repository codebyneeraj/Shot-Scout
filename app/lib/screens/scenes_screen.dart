import 'package:flutter/material.dart';

import '../models.dart';
import '../project_store.dart';
import '../scene_image.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scene_screen.dart';

class ScenesScreen extends StatelessWidget {
  final Project plan;
  final List<Scene> scenes;
  const ScenesScreen({super.key, required this.plan, required this.scenes});

  @override
  Widget build(BuildContext context) {
    final ext = scenes.where((s) => s.isExterior).length;
    final night = scenes.where((s) => dayPartOf(s) == DayPart.night).length;
    return Scaffold(
      appBar: AppBar(title: Text(plan.title.toUpperCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text('${scenes.length} scenes found in your script', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: S.xs),
          Text('Tap a scene to plan its shots around the light.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            _Stat('${scenes.length - ext}', 'interior'),
            _Stat('$ext', 'exterior'),
            _Stat('$night', 'night'),
          ]),
          const SizedBox(height: 20),
          Text('SCENES', style: eyebrow.copyWith(color: C.muted)),
          const SizedBox(height: 10),
          for (final (i, s) in scenes.indexed)
            Entrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: S.m),
                child: _SceneCard(scene: s, plan: plan, total: scenes.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, style: display(32)),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _SceneCard extends StatelessWidget {
  final Scene scene;
  final Project plan;
  final int total;
  const _SceneCard({required this.scene, required this.plan, required this.total});

  @override
  Widget build(BuildContext context) {
    final part = dayPartOf(scene);
    return Semantics(
      button: true,
      label: 'Scene ${scene.number}, ${scene.heading}. ${dayPartLabel(part)}. Open shots.',
      excludeSemantics: true,
      child: Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SceneScreen(plan: plan, scene: scene, total: total)),
      ),
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // The scene's photo; it grows into the scene screen's header on tap.
            SizedBox(width: 88, child: Hero(tag: sceneHeroTag(plan, scene), child: SceneImage(scene: scene))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SCENE ${scene.number}', style: eyebrow.copyWith(fontSize: 11, color: C.muted)),
                  const SizedBox(height: 4),
                  Text(scene.heading, style: script(size: 14)),
                  if (scene.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(scene.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill(dayPartLabel(part), icon: dayPartIcon(part), color: C.surfaceHigh),
                    Pill(scene.isExterior ? 'EXT' : 'INT', color: C.surfaceHigh),
                  ]),
                ]),
              ),
            ),
            const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right, color: C.muted)),
          ]),
        ),
      ),
      ),
    );
  }
}
