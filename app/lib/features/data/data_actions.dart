import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import 'pack_actions.dart';

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _today() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Enregistre une sauvegarde complète (JSON) à l'emplacement choisi.
Future<void> exportBackup(BuildContext context) async {
  final store = AppScope.of(context).store;
  final archive = await store.exportArchive();
  final bytes = utf8.encode(
    const JsonEncoder.withIndent(' ').convert(archive.toJson()),
  );
  final uri = await FilePicker.saveFile(
    fileName: 'verger-sauvegarde-${_today()}.json',
    bytes: Uint8List.fromList(bytes),
    mimeType: 'application/json',
    dialogTitle: 'Enregistrer la sauvegarde',
  );
  if (uri != null && context.mounted) {
    _notify(
      context,
      'Sauvegarde enregistrée (${archive.items.length} connaissances, '
      '${archive.reviews.length} révisions).',
    );
  }
}

Future<VergerArchive?> _pickArchive(BuildContext context) async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Choisir un fichier du Verger (.json)',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (file == null) return null;
  try {
    final text = await file.xFile.readAsString();
    return VergerArchive.fromJson(
      (jsonDecode(text) as Map).cast<String, Object?>(),
    );
  } on ArchiveFormatException catch (e) {
    if (context.mounted) _notify(context, e.message);
  } on FormatException {
    if (context.mounted) {
      _notify(context, 'Ce fichier n\'est pas un JSON valide.');
    }
  }
  return null;
}

/// Remplace toutes les données par une sauvegarde, après confirmation.
Future<void> restoreBackup(BuildContext context) async {
  final scope = AppScope.of(context);
  final archive = await _pickArchive(context);
  if (archive == null || !context.mounted) return;
  final ok = await confirmDestructive(
    context,
    title: 'Restaurer cette sauvegarde ?',
    message:
        'Toutes les données actuelles seront remplacées par la sauvegarde : '
        '${archive.nodes.length} nœuds, ${archive.items.length} connaissances, '
        '${archive.reviews.length} révisions.',
    confirm: 'Restaurer',
  );
  if (!ok) return;
  try {
    await scope.store.restoreArchive(archive);
    await scope.reloadSettings();
  } catch (e) {
    if (context.mounted) {
      _notify(context, 'Restauration impossible, rien n\'a été modifié : $e');
    }
    return;
  }
  if (context.mounted) _notify(context, 'Sauvegarde restaurée.');
}

/// Ajoute les arbres d'un fichier modèle, sans progression.
Future<void> importTemplateFile(BuildContext context) async {
  final store = AppScope.of(context).store;
  final archive = await _pickArchive(context);
  if (archive == null) return;
  try {
    final trees = await store.importTemplate(archive);
    if (context.mounted) _importedMessage(context, trees, archive);
  } catch (e) {
    if (context.mounted) _notify(context, 'Import impossible : $e');
  }
}

/// Ajoute l'arbre d'exemple « Algèbre ».
Future<void> loadSample(BuildContext context) async {
  final store = AppScope.of(context).store;
  final text = await rootBundle.loadString(
    'assets/samples/algebre_exemple.json',
  );
  final archive = VergerArchive.fromJson(
    (jsonDecode(text) as Map).cast<String, Object?>(),
  );
  final trees = await store.importTemplate(archive);
  if (context.mounted) _importedMessage(context, trees, archive);
}

void _importedMessage(
  BuildContext context,
  List<KnowledgeNode> trees,
  VergerArchive archive,
) {
  _notify(
    context,
    '${trees.map((t) => '« ${t.title} »').join(', ')} ajouté '
    '(${archive.items.length} connaissances).',
  );
}

/// Menu « Données » (sauvegarde, restauration, modèles).
class DataMenuButton extends StatelessWidget {
  const DataMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Données',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        'export' => exportBackup(context),
        'restore' => restoreBackup(context),
        'template' => importTemplateFile(context),
        'pack' => importPackFile(context),
        _ => loadSample(context),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.save_alt),
            title: Text('Exporter une sauvegarde'),
          ),
        ),
        PopupMenuItem(
          value: 'restore',
          child: ListTile(
            leading: Icon(Icons.settings_backup_restore),
            title: Text('Restaurer une sauvegarde'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'pack',
          child: ListTile(
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('Importer un paquet (arbre + contenus)'),
          ),
        ),
        PopupMenuItem(
          value: 'template',
          child: ListTile(
            leading: Icon(Icons.file_open_outlined),
            title: Text('Importer un arbre (modèle)'),
          ),
        ),
        PopupMenuItem(
          value: 'sample',
          child: ListTile(
            leading: Icon(Icons.park_outlined),
            title: Text('Ajouter l\'exemple « Algèbre »'),
          ),
        ),
      ],
    );
  }
}
