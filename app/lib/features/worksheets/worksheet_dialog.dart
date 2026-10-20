import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import 'math_raster.dart';
import 'worksheet_pdf.dart';

/// Exercices corrigés automatiquement parmi [items] (modèles lisibles).
List<WorksheetSource> worksheetSources(Iterable<KnowledgeItem> items) => [
  for (final item in items)
    if (item.autoExercise case final source? when source.trim().isNotEmpty)
      if (_template(source) case final template?)
        WorksheetSource(itemId: item.id, title: item.title, template: template),
];

ExerciseTemplate? _template(String source) {
  try {
    final template = ExerciseTemplate.parse(source);
    return template.check() == null ? template : null;
  } catch (_) {
    return null;
  }
}

Future<Object?> _saveFile(String fileName, Uint8List bytes) =>
    FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Enregistrer les fiches',
    );

/// Liste d'élèves de la dernière impression, proposée à la suivante.
String _lastStudents = '';

/// Imprime une fiche d'exercices par élève, tirés des exercices corrigés
/// automatiquement de [items] (une branche, un arbre).
Future<void> printWorksheets(
  BuildContext context, {
  required String title,
  required Iterable<KnowledgeItem> items,
  MathRasterizer raster = rasterizeMath,
  Future<Object?> Function(String fileName, Uint8List bytes) save = _saveFile,
}) async {
  final sources = worksheetSources(items);
  final messenger = ScaffoldMessenger.of(context);
  if (sources.isEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Aucun exercice corrigé automatiquement dans « $title ».',
        ),
      ),
    );
    return;
  }
  final request = await showDialog<_Request>(
    context: context,
    builder: (_) => _WorksheetDialog(title: title, sources: sources),
  );
  if (request == null || !context.mounted) return;
  _lastStudents = request.students.join('\n');
  final now = DateTime.now();
  final date =
      '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year}';
  final List<Worksheet> sheets;
  final Uint8List bytes;
  try {
    sheets = planWorksheets(
      students: request.students,
      sources: request.sources,
      perSheet: request.perSheet,
      session: '${now.microsecondsSinceEpoch}',
    );
    bytes = await buildWorksheetPdf(
      sheets,
      title: request.title,
      date: date,
      answerKey: request.answerKey,
      raster: raster,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Fiches impossibles à créer : $e')),
    );
    return;
  }
  final uri = await save(
    '${request.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}.pdf',
    bytes,
  );
  if (uri != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${sheets.length} fiche${sheets.length > 1 ? 's' : ''} '
          'enregistrée${sheets.length > 1 ? 's' : ''}.',
        ),
      ),
    );
  }
}

typedef _Request = ({
  String title,
  List<String> students,
  List<WorksheetSource> sources,
  int perSheet,
  bool answerKey,
});

class _WorksheetDialog extends StatefulWidget {
  const _WorksheetDialog({required this.title, required this.sources});

  final String title;
  final List<WorksheetSource> sources;

  @override
  State<_WorksheetDialog> createState() => _WorksheetDialogState();
}

class _WorksheetDialogState extends State<_WorksheetDialog> {
  late final _title = TextEditingController(text: widget.title);
  final _students = TextEditingController(text: _lastStudents);
  late final _chosen = {for (final s in widget.sources) s.itemId};
  late var _perSheet = widget.sources.length.clamp(1, 4);
  var _answerKey = true;

  @override
  void dispose() {
    _title.dispose();
    _students.dispose();
    super.dispose();
  }

  List<String> get _names => [
    for (final line in _students.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = [
      for (final s in widget.sources)
        if (_chosen.contains(s.itemId)) s,
    ];
    final perSheet = _perSheet.clamp(1, chosen.isEmpty ? 1 : chosen.length);
    return AlertDialog(
      title: const Text('Fiches d\'exercices par élève'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _students,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Élèves',
                  hintText: 'Un nom par ligne',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text('Exercices', style: theme.textTheme.titleSmall),
              for (final s in widget.sources)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(s.title),
                  value: _chosen.contains(s.itemId),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _chosen.add(s.itemId);
                    } else {
                      _chosen.remove(s.itemId);
                    }
                  }),
                ),
              if (chosen.length > 1)
                Row(
                  children: [
                    const Expanded(child: Text('Exercices par fiche')),
                    DropdownButton<int>(
                      value: perSheet,
                      items: [
                        for (var n = 1; n <= chosen.length; n++)
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: (v) => setState(() => _perSheet = v ?? 1),
                    ),
                  ],
                ),
              if (perSheet < chosen.length)
                Text(
                  'Chaque élève reçoit $perSheet exercice'
                  '${perSheet > 1 ? 's' : ''} tirés parmi ${chosen.length}.',
                  style: theme.textTheme.bodySmall,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ajouter le corrigé'),
                subtitle: const Text('Pages finales, réponses de chaque élève'),
                value: _answerKey,
                onChanged: (v) => setState(() => _answerKey = v),
              ),
              Text(
                'Chaque fiche porte un QR code : ses énoncés pourront être '
                'retrouvés pour la correction.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _names.isEmpty || chosen.isEmpty
              ? null
              : () => Navigator.pop<_Request>(context, (
                  title: _title.text.trim().isEmpty
                      ? widget.title
                      : _title.text.trim(),
                  students: _names,
                  sources: chosen,
                  perSheet: perSheet,
                  answerKey: _answerKey,
                )),
          child: Text(
            _names.isEmpty
                ? 'Créer les fiches'
                : 'Créer ${_names.length} fiche${_names.length > 1 ? 's' : ''}',
          ),
        ),
      ],
    );
  }
}
