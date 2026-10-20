import 'models.dart';

// Matches scene headings like "INT. KITCHEN - NIGHT" or "EXT./INT. CAR - DAY".
final _heading = RegExp(
  r'^\s*(INT\./EXT\.|EXT\./INT\.|INT/EXT\.?|I/E\.?|INT\.|EXT\.)\s*(.+?)(?:\s+-\s+(.+))?\s*$',
  caseSensitive: false,
);

List<Scene> parseScript(String text) {
  final scenes = <Scene>[];
  String? heading, intExt, place, time;
  final body = StringBuffer();

  void flush() {
    if (heading == null) return;
    scenes.add(Scene(
      number: scenes.length + 1,
      heading: heading,
      intExt: intExt!,
      place: place!,
      scriptedTime: time!,
      body: body.toString().trim(),
    ));
    body.clear();
  }

  for (final line in text.split(RegExp(r'\r?\n'))) {
    final m = _heading.firstMatch(line);
    if (m != null) {
      flush();
      final prefix = m.group(1)!.toUpperCase();
      intExt = (prefix.contains('INT') && prefix.contains('EXT')) || prefix.startsWith('I/E')
          ? 'INT/EXT'
          : prefix.startsWith('EXT')
              ? 'EXT'
              : 'INT';
      place = m.group(2)!.trim().toUpperCase();
      time = (m.group(3) ?? 'DAY').trim().toUpperCase();
      heading = line.trim().toUpperCase();
    } else if (heading != null) {
      body.writeln(line);
    }
  }
  flush();
  return scenes;
}
