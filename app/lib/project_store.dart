import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'script_parser.dart';

/// A saved project. Scenes are parsed from the script on demand, so only the
/// inputs are stored.
class Project {
  final String id;
  final String title;
  final String script;
  final double lat, lon;
  final DateTime date;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.title,
    required this.script,
    required this.lat,
    required this.lon,
    required this.date,
    required this.updatedAt,
  });

  late final List<Scene> scenes = parseScript(script);

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'script': script,
        'lat': lat,
        'lon': lon,
        'date': date.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'],
        title: j['title'],
        script: j['script'],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        date: DateTime.parse(j['date']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}

/// Projects stored on the device as one JSON list. Fine for dozens of projects;
/// move to SQLite when scenes and shots need saving too.
class ProjectStore {
  static const _key = 'projects_v1';

  static Future<List<Project>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    final list = [for (final j in jsonDecode(raw) as List) Project.fromJson(j)];
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> save(Project p) async {
    final all = await load()
      ..removeWhere((x) => x.id == p.id)
      ..add(p);
    await _write(all);
  }

  static Future<void> delete(String id) async => _write((await load())..removeWhere((x) => x.id == id));

  static Future<void> _write(List<Project> all) async => (await SharedPreferences.getInstance())
      .setString(_key, jsonEncode([for (final p in all) p.toJson()]));
}
