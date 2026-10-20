import 'models.dart';

/// The light a shot is planned for.
enum Light { harshSun, goldenHour, overcast, blueHour, night, interiorDay, interiorNight }

/// Suggests settings to dial into the camera app. Assumes a phone or
/// mirrorless camera shooting 24p with the 180-degree shutter rule.
CameraSettings settingsFor(Light light, {bool slowMotion = false, bool shallowFocus = false}) {
  final fps = slowMotion ? 60 : 24;
  final shutter = slowMotion ? '1/120 (180°)' : '1/50 (180°)';
  final aperture = shallowFocus ? 'f/1.8 – f/2.8' : 'f/4 – f/5.6';

  final (iso, wb, nd) = switch (light) {
    Light.harshSun => (100, 5600, shallowFocus ? 'ND 1.8 (6 stops)' : 'ND 1.2 (4 stops)'),
    Light.goldenHour => (100, 5600, shallowFocus ? 'ND 0.9 (3 stops)' : 'ND 0.6 (2 stops)'),
    Light.overcast => (200, 6000, shallowFocus ? 'ND 0.9 (3 stops)' : 'ND 0.3 (1 stop)'),
    Light.blueHour => (800, 5000, 'None'),
    Light.night => (1600, 4300, 'None'),
    Light.interiorDay => (400, 5000, 'None'),
    Light.interiorNight => (800, 3200, 'None'),
  };

  return CameraSettings(
    fps: fps,
    shutter: shutter,
    iso: iso,
    whiteBalanceK: wb,
    nd: nd,
    aperture: aperture,
    profile: 'Log / flat, 4K, 16:9',
  );
}

Light lightForScene(Scene s, {bool overcast = false}) {
  final t = s.scriptedTime;
  final night = t.contains('NIGHT');
  if (!s.isExterior) return night ? Light.interiorNight : Light.interiorDay;
  if (night) return Light.night;
  if (t.contains('DUSK') || t.contains('DAWN') || t.contains('TWILIGHT')) return Light.blueHour;
  if (t.contains('SUNSET') || t.contains('SUNRISE') || t.contains('MAGIC')) return Light.goldenHour;
  return overcast ? Light.overcast : Light.harshSun;
}
