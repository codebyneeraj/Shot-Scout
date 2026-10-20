class Scene {
  final int number;
  final String heading;
  final String intExt; // INT, EXT, INT/EXT
  final String place;
  final String scriptedTime; // DAY, NIGHT, DAWN, SUNSET...
  final String body;

  Scene({
    required this.number,
    required this.heading,
    required this.intExt,
    required this.place,
    required this.scriptedTime,
    required this.body,
  });

  bool get isExterior => intExt.contains('EXT');

  String get summary {
    final line = body.split('\n').map((l) => l.trim()).firstWhere(
          (l) => l.isNotEmpty,
          orElse: () => '',
        );
    return line;
  }
}

class CameraSettings {
  final int fps;
  final String shutter;
  final int iso;
  final int whiteBalanceK;
  final String nd;
  final String aperture;
  final String profile;

  const CameraSettings({
    required this.fps,
    required this.shutter,
    required this.iso,
    required this.whiteBalanceK,
    required this.nd,
    required this.aperture,
    required this.profile,
  });

  List<(String, String)> get rows => [
        ('Frame rate', '$fps fps'),
        ('Shutter', shutter),
        ('ISO', '$iso'),
        ('White balance', '${whiteBalanceK}K'),
        ('ND', nd),
        ('Aperture', aperture),
        ('Profile', profile),
      ];
}

class Shot {
  final String size; // WIDE, CLOSE-UP...
  final String name;
  final int lensMm;
  final String movement;
  final String reason;
  final String bestWindow;
  final String stockQuery;
  final CameraSettings settings;

  const Shot({
    required this.size,
    required this.name,
    required this.lensMm,
    required this.movement,
    required this.reason,
    required this.bestWindow,
    required this.stockQuery,
    required this.settings,
  });
}
