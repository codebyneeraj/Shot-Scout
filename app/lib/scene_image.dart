import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'project_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shared-element tag linking a scene's list thumbnail to its header image.
String sceneHeroTag(Project p, Scene s) => 'scene-${p.id}-${s.number}';

/// A stock photo matching the scene's setting and mood. Falls back to the drawn
/// sky while loading, offline, or when no stock API key is set.
class SceneImage extends StatelessWidget {
  final Scene scene;
  final bool showCredit;
  const SceneImage({super.key, required this.scene, this.showCredit = false});

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(painter: SkyPainter(dayPartOf(scene), interior: !scene.isExterior));
    // Decorative: the heading text next to it already says what it shows.
    return ExcludeSemantics(child: FutureBuilder<StockImage?>(
      future: fetchSceneImage(scene),
      builder: (context, snap) {
        final img = snap.data;
        if (img == null) return fallback;
        return Stack(fit: StackFit.expand, children: [
          fallback,
          // Cached on disk, so lists and revisits don't download again.
          CachedNetworkImage(
            imageUrl: img.url,
            fit: BoxFit.cover,
            fadeInDuration: Motion.medium,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
          if (showCredit)
            Positioned(
              right: 8,
              top: MediaQuery.paddingOf(context).top + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.bg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                child: Text(img.credit, style: const TextStyle(fontSize: 10, color: C.text)),
              ),
            ),
        ]);
      },
    ));
  }
}
