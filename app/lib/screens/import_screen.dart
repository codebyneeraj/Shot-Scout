import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../project_store.dart';
import '../script_parser.dart';
import '../theme.dart';
import 'scenes_screen.dart';

const _sample = '''INT. KITCHEN - NIGHT
Rain hammers the window. MEERA, 30s, stirs a pot that has long gone cold.

EXT. RAILWAY PLATFORM - DAWN
Mist over empty tracks. A single lamp still burns.

EXT. SEA PROMENADE - SUNSET
Meera walks alone as the tide comes in.
''';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _title = TextEditingController(text: 'Monsoon Short');
  final _script = TextEditingController(text: _sample);
  final _lat = TextEditingController(text: '18.9440'); // Marine Drive, Mumbai
  final _lon = TextEditingController(text: '72.8230');
  DateTime _date = DateTime.now().add(const Duration(days: 3));

  Future<void> _breakDown() async {
    final scenes = parseScript(_script.text);
    final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
    final problem = scenes.isEmpty
        ? 'No scenes found. Start each scene with a heading like "EXT. BEACH - SUNSET".'
        : lat == null || lat < -90 || lat > 90
            ? 'Latitude must be a number between -90 and 90, like 18.9440.'
            : lon == null || lon < -180 || lon > 180
                ? 'Longitude must be a number between -180 and 180, like 72.8230.'
                : null;
    if (problem != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem), behavior: SnackBarBehavior.floating));
      return;
    }
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final project = Project(
      id: now.microsecondsSinceEpoch.toString(),
      title: _title.text.trim().isEmpty ? 'Untitled project' : _title.text.trim(),
      script: _script.text,
      lat: lat!,
      lon: lon!,
      date: _date,
      updatedAt: now,
    );
    await ProjectStore.save(project);
    if (!mounted) return;
    // Replace this form, so Back from the scene list returns to Home.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ScenesScreen(plan: project, scenes: project.scenes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const coord = TextInputType.numberWithOptions(decimal: true, signed: true);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (Navigator.canPop(context))
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            Text('NEW PROJECT', style: eyebrow.copyWith(color: C.accent)),
            const SizedBox(height: 4),
            Text('SHOTSCOUT', style: display(48)),
            const SizedBox(height: 20),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Project title')),
            const SizedBox(height: 16),
            TextField(
              controller: _script,
              minLines: 10,
              maxLines: 16,
              style: script(bold: false, size: 14),
              decoration: const InputDecoration(
                labelText: 'Script text',
                alignLabelWithHint: true,
                helperText: 'Scenes are found from the INT. and EXT. lines.',
              ),
            ),
            const SizedBox(height: 20),
            Text('WHERE AND WHEN', style: eyebrow.copyWith(color: C.muted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: coord)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _lon, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: coord)),
            ]),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.calendar_today_outlined, color: C.accent),
                title: const Text('Shoot date', style: TextStyle(color: C.muted, fontSize: 13)),
                subtitle: Text(DateFormat('EEE d MMM yyyy').format(_date),
                    style: const TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right, color: C.muted),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _breakDown,
              icon: const Icon(Icons.movie_filter_outlined),
              label: const Text('Break down script'),
            ),
          ],
        ),
      ),
    );
  }
}
