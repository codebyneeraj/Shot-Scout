import 'package:intl/intl.dart';

import 'camera_settings.dart';
import 'models.dart';
import 'sun.dart';

final _clock = DateFormat.jm();
String _range(DateTime? a, DateTime? b) =>
    a == null || b == null ? 'Any time' : '${_clock.format(a)} to ${_clock.format(b)}';

/// Rules-based coverage for v1, until the LLM backend exists.
/// Gives a master, a single, a movement shot and an insert for each scene.
List<Shot> suggestShots(Scene s, SunTimes? sun, {bool overcast = false}) {
  final light = lightForScene(s, overcast: overcast);
  final ext = s.isExterior;

  final window = switch (light) {
    Light.goldenHour when s.scriptedTime.contains('SUNRISE') =>
      _range(sun?.sunrise, sun?.goldenMorningEnd),
    Light.goldenHour => _range(sun?.goldenEveningStart, sun?.sunset),
    Light.blueHour when s.scriptedTime.contains('DAWN') =>
      _range(sun?.blueMorningStart, sun?.sunrise),
    Light.blueHour => _range(sun?.sunset, sun?.blueEveningEnd),
    Light.night => 'After ${sun?.blueEveningEnd == null ? 'dark' : _clock.format(sun!.blueEveningEnd!)}',
    Light.harshSun || Light.overcast => 'Morning or late afternoon; avoid noon on faces',
    _ => 'Light is not a concern',
  };

  final place = s.place.toLowerCase();
  final master = light == Light.goldenHour && ext
      ? ('BACKLIT SILHOUETTE', 'Put the low sun behind the subject; expose for the sky.')
      : ('ESTABLISHING MASTER', 'Shows the whole $place so the audience knows where they are.');

  return [
    Shot(
      size: 'WIDE',
      name: master.$1,
      lensMm: ext ? 24 : 28,
      movement: 'Static',
      reason: master.$2,
      bestWindow: window,
      stockQuery: '${light == Light.goldenHour ? 'sunset silhouette' : place} wide shot',
      settings: settingsFor(light),
    ),
    Shot(
      size: 'CLOSE-UP',
      name: 'SLOW PUSH-IN',
      lensMm: 85,
      movement: 'Dolly or gimbal in',
      reason: light == Light.harshSun
          ? 'Find shade or use diffusion; harsh sun is unflattering on faces.'
          : 'Holds on the character’s face for the emotional beat.',
      bestWindow: window,
      stockQuery: 'slow push in close up face',
      settings: settingsFor(light, shallowFocus: true),
    ),
    Shot(
      size: 'MEDIUM',
      name: ext ? 'TRACKING FROM BEHIND' : 'OVER THE SHOULDER',
      lensMm: 35,
      movement: ext ? 'Handheld or gimbal' : 'Static',
      reason: ext
          ? 'Follows the character through the $place.'
          : 'Covers dialogue and keeps both characters in the frame.',
      bestWindow: window,
      stockQuery: ext ? 'tracking shot walking from behind' : 'over the shoulder conversation',
      settings: settingsFor(light),
    ),
    Shot(
      size: 'INSERT',
      name: 'DETAIL CUTAWAY',
      lensMm: 50,
      movement: 'Static',
      reason: 'A cutaway for the edit. Shoot it last, in whatever light is left.',
      bestWindow: 'Any light',
      stockQuery: '$place detail close up',
      settings: settingsFor(light, slowMotion: true, shallowFocus: true),
    ),
  ];
}
