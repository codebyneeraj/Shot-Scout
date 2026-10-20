import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'theme.dart';

class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const Pill(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color ?? C.chip, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: C.text), const SizedBox(width: 5)],
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.text)),
      ]),
    );
  }
}

/// The light a scripted time of day implies, used for hero art and chips.
enum DayPart { dawn, day, golden, dusk, night }

DayPart dayPartOf(Scene s) {
  final t = s.scriptedTime;
  if (t.contains('NIGHT')) return DayPart.night;
  if (t.contains('SUNSET') || t.contains('SUNRISE') || t.contains('MAGIC')) return DayPart.golden;
  if (t.contains('DAWN')) return DayPart.dawn;
  if (t.contains('DUSK') || t.contains('TWILIGHT') || t.contains('EVENING')) return DayPart.dusk;
  return DayPart.day;
}

String dayPartLabel(DayPart p) => switch (p) {
      DayPart.dawn => 'Dawn',
      DayPart.day => 'Day',
      DayPart.golden => 'Golden hour',
      DayPart.dusk => 'Blue hour',
      DayPart.night => 'Night',
    };

IconData dayPartIcon(DayPart p) => switch (p) {
      DayPart.dawn => Icons.wb_twilight,
      DayPart.day => Icons.wb_sunny_outlined,
      DayPart.golden => Icons.wb_twilight,
      DayPart.dusk => Icons.nights_stay_outlined,
      DayPart.night => Icons.dark_mode_outlined,
    };

/// Sky gradients per time of day, in the style of the mockup's sunset hero.
List<Color> skyColors(DayPart p) => switch (p) {
      DayPart.dawn => const [Color(0xFF1B2347), Color(0xFF6A5D8F), Color(0xFFE8A7A0), Color(0xFF2A2236)],
      DayPart.day => const [Color(0xFF2E6FB7), Color(0xFF6FA8DC), Color(0xFFBFD9EE), Color(0xFF3A4A3A)],
      DayPart.golden => const [Color(0xFF2B1B4A), Color(0xFFB8456B), Color(0xFFF5A04A), Color(0xFF3A1F3D)],
      DayPart.dusk => const [Color(0xFF0E1435), Color(0xFF233A7A), Color(0xFF5B7BD8), Color(0xFF151A30)],
      DayPart.night => const [Color(0xFF05060C), Color(0xFF0D1024), Color(0xFF1A1E3A), Color(0xFF07080F)],
    };

/// Drawn time-of-day backdrop: sky, horizon, sun or moon, and an interior frame for INT scenes.
class SkyPainter extends CustomPainter {
  final DayPart part;
  final bool interior;
  SkyPainter(this.part, {this.interior = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final c = skyColors(part);
    final horizon = size.height * 0.62;
    // Scale the sun and moon to the box, so a thin thumbnail strip gets a small sun.
    final k = (size.shortestSide / 300).clamp(0.3, 1.0);
    final sky = Rect.fromLTWH(0, 0, size.width, horizon);
    canvas.drawRect(
      sky,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c.sublist(0, 3)).createShader(sky),
    );
    final ground = Rect.fromLTWH(0, horizon, size.width, size.height - horizon);
    canvas.drawRect(
      ground,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c[3], C.bg]).createShader(ground),
    );

    final cx = size.width * 0.68;
    switch (part) {
      case DayPart.night:
        canvas.drawCircle(Offset(cx, horizon * 0.35), 18 * k, Paint()..color = const Color(0xFFE8E6F0));
        canvas.drawCircle(Offset(cx + 8 * k, horizon * 0.35 - 5 * k), 16 * k, Paint()..color = c[1]);
        final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
        for (final (x, y) in const [(0.1, 0.15), (0.25, 0.32), (0.42, 0.12), (0.55, 0.4), (0.85, 0.2), (0.92, 0.45)]) {
          canvas.drawCircle(Offset(size.width * x, horizon * y), 1.3, star);
        }
      case DayPart.dusk:
        break;
      default:
        final r = (part == DayPart.day ? 26.0 : 34.0) * k;
        final sunY = part == DayPart.day ? horizon * 0.3 : horizon - r * 0.75;
        final sunColor = part == DayPart.day ? const Color(0xFFFFF4D6) : const Color(0xFFFFD38A);
        canvas.drawCircle(Offset(cx, sunY), r * 2.2, Paint()..color = sunColor.withValues(alpha: 0.18));
        canvas.drawCircle(Offset(cx, sunY), r, Paint()..color = sunColor);
        if (part != DayPart.day) {
          // Reflection lines on the water.
          final p = Paint()..color = sunColor.withValues(alpha: 0.45);
          for (var i = 0; i < 3; i++) {
            final w = (54.0 - i * 16) * k;
            canvas.drawRect(Rect.fromLTWH(cx - w / 2, horizon + (10 + i * 11) * k, w, 3 * k), p);
          }
        }
    }

    if (interior) {
      // Window frame: we are looking out from inside.
      final frame = Paint()..color = C.bg.withValues(alpha: 0.92);
      final w = size.width, h = size.height;
      canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.14, h), frame);
      canvas.drawRect(Rect.fromLTWH(w * 0.86, 0, w * 0.14, h), frame);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.12), frame);
      canvas.drawRect(Rect.fromLTWH(w * 0.495, 0, w * 0.01, h), frame);
      canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.012), frame);
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.part != part || old.interior != interior;
}

/// A bordered card with consistent padding.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// Shimmering placeholder block for loading states.
class Skeleton extends StatefulWidget {
  final double height;
  const Skeleton({super.key, this.height = 96});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            // A soft highlight band sweeping left to right.
            final x = -1.5 + _c.value * 3;
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment(x - 1, 0),
                  end: Alignment(x + 1, 0),
                  colors: const [C.surface, C.surfaceHigh, C.surface],
                ),
              ),
            );
          },
        ),
      );
}

/// Shrinks slightly while pressed and gives a light haptic tick on tap,
/// so every tappable card answers the finger.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides a child up into place, delayed by [index] so lists
/// arrive one item after another instead of all at once.
class Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 70).clamp(0, 420);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.medium + Duration(milliseconds: delay),
      curve: Interval(delay / (Motion.medium.inMilliseconds + delay), 1, curve: Motion.curve),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
