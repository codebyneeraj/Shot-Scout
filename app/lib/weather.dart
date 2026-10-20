import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DayWeather {
  final double maxC, minC;
  final int rainChance;
  final int cloudCover;

  DayWeather(this.maxC, this.minC, this.rainChance, this.cloudCover);

  bool get overcast => cloudCover >= 70;
  String get summary =>
      '${cloudCover >= 70 ? 'Overcast' : cloudCover >= 30 ? 'Partly cloudy' : 'Clear'} · '
      '${maxC.round()}° / ${minC.round()}° · $rainChance% rain';
}

/// Open-Meteo daily forecast. Returns null beyond the ~16-day forecast range
/// or on any network error; the caller shows a seasonal estimate instead.
Future<DayWeather?> fetchWeather(double lat, double lon, DateTime day) async {
  final d = DateFormat('yyyy-MM-dd').format(day);
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
    'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,cloud_cover_mean',
    'timezone': 'auto',
    'start_date': d,
    'end_date': d,
  });
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final daily = jsonDecode(res.body)['daily'];
    num v(String k) => (daily[k] as List).first ?? 0;
    return DayWeather(
      v('temperature_2m_max').toDouble(),
      v('temperature_2m_min').toDouble(),
      v('precipitation_probability_max').toInt(),
      v('cloud_cover_mean').toInt(),
    );
  } catch (_) {
    return null;
  }
}
