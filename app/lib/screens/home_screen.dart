import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../project_store.dart';
import '../scene_image.dart';
import '../theme.dart';
import '../widgets.dart';
import 'import_screen.dart';
import 'scenes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project>? _projects; // null while loading

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await ProjectStore.load();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _newProject() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen()));
    _reload();
  }

  Future<void> _open(Project p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ScenesScreen(plan: p, scenes: p.scenes)));
    _reload();
  }

  /// Removes at once and offers Undo, instead of asking "are you sure?" first.
  Future<void> _delete(Project p) async {
    HapticFeedback.mediumImpact();
    setState(() => _projects!.removeWhere((x) => x.id == p.id));
    await ProjectStore.delete(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${p.title}"'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: C.accent,
          onPressed: () async {
            await ProjectStore.save(p);
            _reload();
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final projects = _projects;
            return ListView(
              padding: const EdgeInsets.fromLTRB(S.xl, S.l, S.xl, S.xxl),
              children: [
                Semantics(header: true, child: Text('SHOTSCOUT', style: display(44))),
                Text('Plan every shot around the light.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: S.xl),
                if (projects == null) ...[
                  const Skeleton(height: 250),
                  const SizedBox(height: S.m),
                  const Skeleton(height: 76),
                ] else if (projects.isEmpty)
                  Entrance(index: 0, child: _Welcome(onStart: _newProject))
                else ...[
                  Text('CONTINUE PLANNING', style: eyebrow.copyWith(color: C.accent)),
                  const SizedBox(height: S.m),
                  Entrance(index: 0, child: _ContinueCard(project: projects.first, onTap: () => _open(projects.first))),
                  const SizedBox(height: S.l),
                  OutlinedButton.icon(onPressed: _newProject, icon: const Icon(Icons.add), label: const Text('New project')),
                  const SizedBox(height: S.xxl),
                  Text('YOUR PROJECTS', style: eyebrow.copyWith(color: C.muted)),
                  const SizedBox(height: S.xs),
                  Text('Swipe left on a project to delete it.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: S.m),
                  for (final (i, p) in projects.indexed)
                    Entrance(
                      index: i + 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: S.m),
                        child: Dismissible(
                          key: ValueKey(p.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: S.xl),
                            decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(12)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_outline, color: Colors.white),
                              SizedBox(width: S.s),
                              Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                          onDismissed: (_) => _delete(p),
                          child: _ProjectRow(project: p, onTap: () => _open(p), onDelete: () => _delete(p)),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Text('QUICK START', style: eyebrow.copyWith(color: C.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _QuickTile(Icons.notes, 'Paste a script', 'Plain text works', _newProject)),
                  const SizedBox(width: 10),
                  const Expanded(child: _QuickTile(Icons.upload_file, 'Import a file', 'Fountain, FDX, PDF · soon', null)),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _projectLine(Project p) =>
    '${p.scenes.length} scene${p.scenes.length == 1 ? '' : 's'} · Shoot ${DateFormat('EEE d MMM').format(p.date)}';

class _ContinueCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  const _ContinueCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = project.scenes.isEmpty ? null : project.scenes.first;
    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 170,
            child: Stack(fit: StackFit.expand, children: [
              if (cover != null) SceneImage(scene: cover) else Container(color: C.surfaceHigh),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0A12), Color(0xE614141F)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Text(project.title.toUpperCase(), style: display(40), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 14),
            child: Row(children: [
              Expanded(child: Text(_projectLine(project), style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600))),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                child: const Text('Continue'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  final VoidCallback onTap, onDelete;
  const _ProjectRow({required this.project, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cover = project.scenes.isEmpty ? null : project.scenes.first;
    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          SizedBox(width: 76, height: 76, child: cover == null ? null : SceneImage(scene: cover)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(project.title.toUpperCase(), style: display(24), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_projectLine(project), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'Project options',
            icon: const Icon(Icons.more_vert, color: C.muted),
            color: C.surfaceHigh,
            onSelected: (_) => onDelete(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete project'))],
          ),
        ]),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.movie_filter_outlined, color: C.accent, size: 32),
          const SizedBox(height: 12),
          Text('YOUR FIRST SHOOT', style: display(32)),
          const SizedBox(height: 6),
          Text(
            'Paste a script, pick where and when you shoot, and ShotScout plans each shot around the real light and weather.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add), label: const Text('New project')),
        ]),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _QuickTile(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(S.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: C.accent),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}
