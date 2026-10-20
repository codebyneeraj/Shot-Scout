import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Backend base URL. 10.0.2.2 is the host PC as seen from the Android emulator.
/// Override with: flutter run --dart-define=API_URL=http://192.168.1.10:8000
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Shared key the production backend checks (its APP_KEY). Set at build time:
/// --dart-define=APP_KEY=... It keeps casual callers off the API; it is not a
/// strong secret, since anything inside an APK can be extracted.
const _appKey = String.fromEnvironment('APP_KEY');

Map<String, String> get _headers => {
      'Content-Type': 'application/json',
      if (_appKey.isNotEmpty) 'X-App-Key': _appKey,
    };

/// Wakes the backend: Render's free plan sleeps after 15 idle minutes and takes
/// up to a minute to start, so ping it as soon as the app opens.
void wakeBackend() {
  http.get(Uri.parse('$apiUrl/health')).timeout(const Duration(seconds: 90)).ignore();
}

const _sizeNames = {
  'EWS': 'EXTREME WIDE', 'WS': 'WIDE', 'MWS': 'MEDIUM WIDE', 'MS': 'MEDIUM',
  'MCU': 'MEDIUM CLOSE-UP', 'CU': 'CLOSE-UP', 'ECU': 'EXTREME CLOSE-UP',
  'OTS': 'OVER THE SHOULDER',
};

class AiShots {
  final List<Shot> shots;
  final String model;
  AiShots(this.shots, this.model);
}

final _shotCache = <String, AiShots>{};

/// The AI shots already fetched for this scene and these conditions, if any.
AiShots? cachedAiShots(Scene scene, Map<String, Object?> conditions) =>
    _shotCache[_shotKey(scene, conditions)];

String _shotKey(Scene scene, Map<String, Object?> conditions) =>
    jsonEncode([scene.heading, scene.body, conditions]);

/// Asks the backend for AI shot suggestions. Throws on any failure so the
/// caller can keep the offline rule-based shots. Results are cached for the
/// session, so reopening a scene is instant; pass [refresh] to ask again.
Future<AiShots> fetchAiShots(Scene scene, Map<String, Object?> conditions, {bool refresh = false}) async {
  final key = _shotKey(scene, conditions);
  if (!refresh && _shotCache[key] != null) return _shotCache[key]!;
  return _shotCache[key] = await _requestAiShots(scene, conditions);
}

Future<AiShots> _requestAiShots(Scene scene, Map<String, Object?> conditions) async {
  final res = await http
      .post(
        Uri.parse('$apiUrl/suggest-shots'),
        headers: _headers,
        body: jsonEncode({'heading': scene.heading, 'text': scene.body, 'conditions': conditions}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw Exception('Backend ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final shots = [
    for (final s in data['shots'] as List)
      Shot(
        size: _sizeNames[s['size']] ?? s['size'],
        name: (s['name'] as String).toUpperCase(),
        lensMm: s['lens_mm'],
        movement: _capitalize(s['movement']),
        reason: s['reason'],
        bestWindow: s['best_window'],
        stockQuery: s['stock_query'],
        settings: CameraSettings(
          fps: s['settings']['fps'],
          shutter: s['settings']['shutter'],
          iso: s['settings']['iso'],
          whiteBalanceK: s['settings']['white_balance_k'],
          nd: s['settings']['nd'],
          aperture: s['settings']['aperture'],
          profile: s['settings']['profile'],
        ),
      ),
  ];
  return AiShots(shots, data['model']);
}

class StockImage {
  final String url, credit, link;
  StockImage(this.url, this.credit, this.link);
}

final _imageCache = <String, Future<StockImage?>>{};
final _pending = <String, (Scene, Completer<StockImage?>)>{};
Timer? _batchTimer;

/// The cover photo for a scene, or null if none (no stock key, offline, no
/// match). The backend's AI writes the photo search from the scene text.
/// Requests made within 50ms (a whole scene list building) go out as one
/// batch, so a list costs one AI call instead of one per scene.
Future<StockImage?> fetchSceneImage(Scene scene) {
  final key = '${scene.heading}\n${scene.body}';
  final cached = _imageCache[key];
  if (cached != null) return cached;
  final c = Completer<StockImage?>();
  _imageCache[key] = c.future;
  _pending[key] = (scene, c);
  _batchTimer ??= Timer(const Duration(milliseconds: 50), _flushImages);
  return c.future;
}

Future<void> _flushImages() async {
  _batchTimer = null;
  final batch = Map.of(_pending);
  _pending.clear();
  final entries = batch.entries.toList();
  for (var i = 0; i < entries.length; i += 30) {
    final chunk = entries.sublist(i, (i + 30).clamp(0, entries.length));
    List? images;
    try {
      final res = await http
          .post(
            Uri.parse('$apiUrl/scene-images'),
            headers: _headers,
            body: jsonEncode({
              'scenes': [for (final e in chunk) {'heading': e.value.$1.heading, 'text': e.value.$1.body}],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) images = jsonDecode(res.body)['images'];
    } catch (_) {}
    for (final (j, e) in chunk.indexed) {
      final img = images != null && j < images.length ? images[j] : null;
      if (img == null || img['url'] == null) {
        // Try again on the next visit, e.g. once a stock key is added.
        _imageCache.remove(e.key);
        e.value.$2.complete(null);
      } else {
        e.value.$2.complete(StockImage(img['url'], img['credit'], img['link']));
      }
    }
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
