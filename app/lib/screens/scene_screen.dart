import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import '../project_store.dart';
import '../scene_image.dart';
import '../shot_suggester.dart';
import '../sun.dart';
import '../theme.dart';
import '../weather.dart';
import '../widgets.dart';

class SceneScreen extends StatefulWidget {
  final Project plan;
  final Scene scene;
  final int total;
  const SceneScreen({super.key, required this.plan, required this.scene, required this.total});

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  late final SunTimes _sun = sunTimes(widget.plan.date, widget.plan.lat, widget.plan.lon);
  DayWeather? _weather;
  bool _loadingWeather = true;
  AiShots? _ai;
  String? _aiError;
  final _scrolled = ValueNotifier(false);

  static String _fmt(DateTime? d) => d == null ? '—' : DateFormat.jm().format(d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await fetchWeather(widget.plan.lat, widget.plan.lon, widget.plan.date);
    if (!mounted) return;
    setState(() {
      _weather = w;
      _loadingWeather = false;
    });
    await _askAi();
  }

  Map<String, Object?> get _conditions => {
        'date': DateFormat('yyyy-MM-dd').format(widget.plan.date),
        'sunrise': _fmt(_sun.sunrise),
        'sunset': _fmt(_sun.sunset),
        'golden_hour': '${_fmt(_sun.goldenEveningStart)} to ${_fmt(_sun.sunset)}',
        'blue_hour': '${_fmt(_sun.sunset)} to ${_fmt(_sun.blueEveningEnd)}',
        'weather': _weather?.summary,
        'overcast': _weather?.overcast ?? false,
      };

  Future<void> _askAi({bool refresh = false}) async {
    final cached = refresh ? null : cachedAiShots(widget.scene, _conditions);
    setState(() {
      _ai = cached;
      _aiError = null;
    });
    if (cached != null) return;
    try {
      final ai = await fetchAiShots(widget.scene, _conditions, refresh: refresh);
      if (!mounted) return;
      HapticFeedback.lightImpact(); // the plan has landed
      setState(() => _ai = ai);
    } catch (e) {
      if (mounted) setState(() => _aiError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scene;
    final thinking = _ai == null && _aiError == null;
    final shots = _ai?.shots ?? suggestShots(s, _sun, overcast: _weather?.overcast ?? false);

    return Scaffold(
      body: Stack(children: [
        _scroll(s, thinking, shots),
        // Keeps the status bar readable once the hero scrolls away.
        ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: MediaQuery.paddingOf(context).top,
            color: scrolled ? C.bg.withValues(alpha: 0.92) : Colors.transparent,
          ),
        ),
      ]),
    );
  }

  Widget _scroll(Scene s, bool thinking, List<Shot> shots) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _scrolled.value = n.metrics.pixels > 240;
        return false;
      },
      child: RefreshIndicator(
        color: C.accent,
        backgroundColor: C.surfaceHigh,
        // Pull down to ask the AI for a fresh plan.
        onRefresh: () => _askAi(refresh: true),
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverToBoxAdapter(child: _Hero(scene: s, total: widget.total, heroTag: sceneHeroTag(widget.plan, s))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          sliver: SliverList.list(children: [
            const _SectionTitle('Where and when'),
            _WhereWhen(plan: widget.plan),
            const SizedBox(height: 22),
            const _SectionTitle('Conditions on the day'),
            _Conditions(sun: _sun, weather: _weather, loading: _loadingWeather, fmt: _fmt),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: _SectionTitle('Recommended shots')),
              if (!thinking) Text('${shots.length} shots', style: Theme.of(context).textTheme.bodySmall),
            ]),
            _SourceLine(ai: _ai, error: _aiError, onRetry: _askAi),
            const SizedBox(height: S.m),
            // Cross-fade from placeholders to the plan; the shots then arrive one by one.
            AnimatedSwitcher(
              duration: Motion.medium,
              child: thinking
                  ? Column(
                      key: const ValueKey('loading'),
                      children: [
                        for (var i = 0; i < 3; i++)
                          const Padding(padding: EdgeInsets.only(bottom: S.m), child: Skeleton(height: 112)),
                      ],
                    )
                  : Column(
                      key: ValueKey(_ai ?? _aiError),
                      children: [
                        for (final (i, shot) in shots.indexed)
                          Entrance(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: S.m),
                              child: _ShotCard(index: i + 1, shot: shot),
                            ),
                          ),
                      ],
                    ),
            ),
          ]),
        ),
      ]),
      ),
    );
  }

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }
}

class _Hero extends StatelessWidget {
  final Scene scene;
  final int total;
  final Object heroTag;
  const _Hero({required this.scene, required this.total, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final part = dayPartOf(scene);
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 300 + top,
      child: Stack(fit: StackFit.expand, children: [
        // Grows out of the scene's thumbnail in the list.
        Hero(tag: heroTag, child: SceneImage(scene: scene, showCredit: true)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x800A0A12), Color(0x000A0A12), Color(0x4D0A0A12), C.bg],
              stops: [0, 0.3, 0.6, 1],
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: top + 8,
          child: Material(
            color: C.bg.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Back to scenes',
              icon: const Icon(Icons.chevron_left, color: C.text),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 10,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SCENE ${scene.number} OF $total', style: eyebrow),
            const SizedBox(height: 6),
            Text(scene.place, style: display(56), maxLines: 2),
            const SizedBox(height: 4),
            Text(scene.heading, style: script(color: const Color(0xFFD8D8E4))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Pill(dayPartLabel(part), icon: dayPartIcon(part)),
              Pill(scene.isExterior ? 'Exterior' : 'Interior'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: Theme.of(context).textTheme.titleMedium));
}

class _WhereWhen extends StatelessWidget {
  final Project plan;
  const _WhereWhen({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.place_outlined, color: C.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${plan.lat.toStringAsFixed(4)}, ${plan.lon.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        const Divider(height: 24),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, color: C.accent, size: 20),
          const SizedBox(width: 12),
          Text(DateFormat('EEE d MMM yyyy').format(plan.date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _Conditions extends StatelessWidget {
  final SunTimes sun;
  final DayWeather? weather;
  final bool loading;
  final String Function(DateTime?) fmt;
  const _Conditions({required this.sun, required this.weather, required this.loading, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = weather;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(w == null ? Icons.cloud_off_outlined : w.overcast ? Icons.cloud_outlined : Icons.wb_cloudy_outlined,
              color: C.text, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: loading
                ? Text('Fetching forecast…', style: t.bodyMedium)
                : w == null
                    ? Text('No forecast yet. Too far out or offline, so plan with seasonal norms.', style: t.bodyMedium)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${w.maxC.round()}° / ${w.minC.round()}°', style: display(30)),
                        Text('${w.cloudCover}% cloud · ${w.rainChance}% chance of rain', style: t.bodySmall),
                      ]),
          ),
        ]),
        const Divider(height: 28),
        _Time(Icons.wb_twilight, C.text, 'Sunrise', fmt(sun.sunrise)),
        _Time(Icons.wb_sunny, C.gold, 'Golden hour', '${fmt(sun.goldenEveningStart)} – ${fmt(sun.sunset)}'),
        _Time(Icons.wb_twilight, C.text, 'Sunset', fmt(sun.sunset)),
        _Time(Icons.nights_stay, C.blue, 'Blue hour', '${fmt(sun.sunset)} – ${fmt(sun.blueEveningEnd)}'),
      ]),
    );
  }
}

class _Time extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _Time(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: C.muted, fontSize: 14))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      );
}

class _SourceLine extends StatelessWidget {
  final AiShots? ai;
  final String? error;
  final VoidCallback onRetry;
  const _SourceLine({required this.ai, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    if (ai != null) {
      return Row(children: [
        const Icon(Icons.auto_awesome, size: 14, color: C.gold),
        const SizedBox(width: 6),
        Text('Planned by AI from your scene and the light', style: small),
      ]);
    }
    if (error != null) {
      return Row(children: [
        const Icon(Icons.cloud_off, size: 14, color: C.muted),
        const SizedBox(width: 6),
        Expanded(child: Text('AI unavailable, showing offline suggestions', style: small)),
        TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: C.accent))),
      ]);
    }
    return Row(children: [
      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: C.gold)),
      const SizedBox(width: 8),
      Text('Planning shots for this light…', style: small),
    ]);
  }
}

class _ShotCard extends StatelessWidget {
  final int index;
  final Shot shot;
  const _ShotCard({required this.index, required this.shot});

  // Opens the user's default video camera app (Blackmagic Camera if set as default).
  Future<void> _openCamera() => const AndroidIntent(action: 'android.media.action.VIDEO_CAMERA').launch();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: C.text,
          collapsedIconColor: C.muted,
          onExpansionChanged: (_) => HapticFeedback.selectionClick(),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(4)),
                child: Text(shot.size, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text('$index', style: display(22).copyWith(color: C.muted)),
            ]),
            const SizedBox(height: 6),
            Text(shot.name, style: display(28)),
            Text('${shot.lensMm}mm · ${shot.movement}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.muted)),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shot.reason, style: t.bodyMedium),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule, size: 16, color: C.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Best at ${shot.bestWindow}',
                      style: const TextStyle(color: C.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ]),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text('CAMERA SETTINGS', style: eyebrow.copyWith(color: C.muted, fontSize: 11)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                for (final (k, v) in shot.settings.rows)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: C.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(k, style: const TextStyle(color: C.muted, fontSize: 11)),
                      Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Open camera app'),
            ),
            const SizedBox(height: S.xs),
            Text('Dial these settings in before you roll.', style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
