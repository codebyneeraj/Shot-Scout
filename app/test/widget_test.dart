import 'package:flutter_test/flutter_test.dart';
import 'package:shotscout/camera_settings.dart';
import 'package:shotscout/script_parser.dart';
import 'package:shotscout/shot_suggester.dart';
import 'package:shotscout/sun.dart';

void main() {
  test('parses scene headings', () {
    final scenes = parseScript('''
INT. KITCHEN - NIGHT
Rain hammers the window.

EXT. SEA PROMENADE - SUNSET
Meera walks alone.
INT./EXT. CAR - DAY
''');
    expect(scenes.length, 3);
    expect(scenes[0].intExt, 'INT');
    expect(scenes[0].scriptedTime, 'NIGHT');
    expect(scenes[0].summary, 'Rain hammers the window.');
    expect(scenes[1].intExt, 'EXT');
    expect(scenes[1].place, 'SEA PROMENADE');
    expect(scenes[2].intExt, 'INT/EXT');
  });

  test('sun times for Mumbai are plausible', () {
    // Mumbai, 7 Nov: sunrise ~06:44, sunset ~18:03 IST (UTC+5:30).
    final s = sunTimes(DateTime(2026, 11, 7), 18.944, 72.823);
    final rise = s.sunrise!.toUtc().add(const Duration(hours: 5, minutes: 30));
    final set = s.sunset!.toUtc().add(const Duration(hours: 5, minutes: 30));
    expect((rise.hour * 60 + rise.minute - (6 * 60 + 44)).abs(), lessThan(5));
    expect((set.hour * 60 + set.minute - (18 * 60 + 3)).abs(), lessThan(5));
    expect(s.goldenEveningStart!.isBefore(s.sunset!), isTrue);
    expect(s.blueEveningEnd!.isAfter(s.sunset!), isTrue);
  });

  test('sunset exterior gets golden hour settings', () {
    final scene = parseScript('EXT. BEACH - SUNSET\nWaves.').single;
    expect(lightForScene(scene), Light.goldenHour);
    final shots = suggestShots(scene, null);
    expect(shots.first.name, 'BACKLIT SILHOUETTE');
    expect(shots.first.settings.iso, 100);
    expect(shots.last.settings.fps, 60);
  });
}
