import 'dart:math';

/// Sun times for one day, in the device's local time zone.
class SunTimes {
  final DateTime? sunrise, sunset;
  final DateTime? goldenMorningEnd, goldenEveningStart;
  final DateTime? blueMorningStart, blueEveningEnd;

  SunTimes({
    this.sunrise,
    this.sunset,
    this.goldenMorningEnd,
    this.goldenEveningStart,
    this.blueMorningStart,
    this.blueEveningEnd,
  });
}

double _rad(double d) => d * pi / 180;
double _deg(double r) => r * 180 / pi;

/// NOAA-style solar calculation. Returns the UTC time the sun crosses
/// [altitude] degrees, rising if [rising], or null if it never does that day.
DateTime? _crossing(DateTime dateUtc, double lat, double lon, double altitude,
    bool rising) {
  final dayStart = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
  final n = dayStart.difference(DateTime.utc(2000, 1, 1, 12)).inDays + 0.0008 + 1;
  final jStar = n - lon / 360;
  final m = (357.5291 + 0.98560028 * jStar) % 360;
  final c = 1.9148 * sin(_rad(m)) + 0.02 * sin(_rad(2 * m)) + 0.0003 * sin(_rad(3 * m));
  final lambda = (m + c + 180 + 102.9372) % 360;
  final jTransit = 2451545.0 + jStar + 0.0053 * sin(_rad(m)) - 0.0069 * sin(_rad(2 * lambda));
  final decl = asin(sin(_rad(lambda)) * sin(_rad(23.4397)));
  final cosH = (sin(_rad(altitude)) - sin(_rad(lat)) * sin(decl)) /
      (cos(_rad(lat)) * cos(decl));
  if (cosH < -1 || cosH > 1) return null;
  final h = _deg(acos(cosH));
  final j = rising ? jTransit - h / 360 : jTransit + h / 360;
  final ms = ((j - 2440587.5) * 86400000).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

SunTimes sunTimes(DateTime date, double lat, double lon) {
  final d = DateTime.utc(date.year, date.month, date.day);
  DateTime? t(double alt, bool rising) => _crossing(d, lat, lon, alt, rising)?.toLocal();
  return SunTimes(
    sunrise: t(-0.833, true),
    sunset: t(-0.833, false),
    goldenMorningEnd: t(6, true),
    goldenEveningStart: t(6, false),
    blueMorningStart: t(-6, true),
    blueEveningEnd: t(-6, false),
  );
}
