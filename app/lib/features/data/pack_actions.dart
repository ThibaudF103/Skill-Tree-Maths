import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../data/pack_file.dart';
import '../../pdf/pdf_tools.dart';

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Exporte [node] (et sa descendance) en paquet `.verger` à partager.
Future<void> exportTreePack(BuildContext context, KnowledgeNode node) async {
  final store = AppScope.of(context).store;
  final archive = await store.exportTree(node.id);
  if (!context.mounted) return;
  final pdfs = [
    for (final d in archive.documents)
      if (d.isPdf) d,
  ];
  final include = await showDialog<bool>(
    context: context,
    builder: (_) => _ExportDialog(archive: archive, pdfs: pdfs),
  );
  if (include == null || !context.mounted) return;
  final files = <String, Uint8List>{};
  for (final d in pdfs) {
    // Inclus sur demande, et toujours faute d'adresse de téléchargement.
    if (include || d.url == null) {
      final bytes = await store.documentBytes(d.id);
      if (bytes != null) files[d.id] = bytes;
    }
  }
  final bytes = PackFile.encode(archive, files);
  final uri = await FilePicker.saveFile(
    fileName: '${node.title}.${PackFile.extension}',
    bytes: bytes,
    dialogTitle: 'Enregistrer le paquet',
  );
  if (uri != null && context.mounted) {
    _notify(
      context,
      'Paquet « ${node.title} » enregistré (${archive.items.length} '
      'connaissances, ${archive.documents.length} contenu(s)).',
    );
  }
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.archive, required this.pdfs});

  final VergerArchive archive;
  final List<SourceDocument> pdfs;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  var _include = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.archive;
    return AlertDialog(
      title: Text('Partager « ${a.title} »'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${a.nodes.length} nœud(s), ${a.items.length} connaissance(s), '
              '${a.documents.length} contenu(s), ${a.anchors.length} '
              'recto/verso, ${a.notes.length} note(s). Sans historique de '
              'révision.',
            ),
            if (widget.pdfs.isNotEmpty) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _include,
                onChanged: (v) => setState(() => _include = v ?? true),
                title: const Text('Inclure les PDF dans le paquet'),
                subtitle: const Text(
                  'Sinon, les PDF ayant une adresse de téléchargement sont '
                  'récupérés à l\'import (idéal pour un poly public).',
                ),
              ),
              for (final d in widget.pdfs)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${d.title} : ${_include || d.url == null ? 'inclus' : 'par adresse'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _include),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Importe un paquet `.verger` : arbre, contenus (PDF inclus ou
/// téléchargés), ancres et notes.
Future<void> importPackFile(BuildContext context) async {
  final store = AppScope.of(context).store;
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Choisir un paquet (.verger)',
    type: FileType.custom,
    allowedExtensions: const [PackFile.extension, 'zip'],
  );
  if (picked == null || !context.mounted) return;
  final VergerArchive archive;
  final Map<String, Uint8List> included;
  try {
    (archive, included) = PackFile.decode(await picked.xFile.readAsBytes());
  } on ArchiveFormatException catch (e) {
    if (context.mounted) _notify(context, e.message);
    return;
  }
  if (!context.mounted) return;
  final local = {for (final d in await store.allDocuments()) d.contentHash};
  final toFetch = [
    for (final d in archive.documents)
      if (d.isPdf &&
          !included.containsKey(d.id) &&
          !local.contains(d.contentHash) &&
          d.url != null)
        d,
  ];
  if (!context.mounted) return;
  final PackImportPreview preview;
  try {
    preview = await store.previewPack(archive);
  } on ArchiveFormatException catch (e) {
    if (context.mounted) _notify(context, e.message);
    return;
  }
  if (!context.mounted) return;
  final mode = await showDialog<PackImportMode>(
    context: context,
    builder: (_) => PackImportDialog(
      archive: archive,
      preview: preview,
      details: [
        if (included.isNotEmpty) '${included.length} PDF inclus.',
        if (toFetch.isNotEmpty)
          '${toFetch.length} PDF à télécharger : '
              '${toFetch.map((d) => d.title).join(', ')}.',
      ],
    ),
  );
  if (mode == null || !context.mounted) return;

  final status = ValueNotifier<String>('Préparation…');
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Import du paquet…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, text, _) => Text(text),
            ),
          ],
        ),
      ),
    ),
  );
  final failed = <String>[];
  List<KnowledgeNode> trees;
  try {
    final files = <String, PackPdf>{};
    final sources = {...included, for (final d in toFetch) d.id: null};
    for (final d in archive.documents) {
      if (!sources.containsKey(d.id)) continue;
      var bytes = included[d.id];
      if (bytes == null) {
        status.value = 'Téléchargement de « ${d.title} »…';
        bytes = await _download(d.url!);
        if (bytes == null) {
          failed.add(d.title);
          continue;
        }
      }
      status.value = 'Analyse de « ${d.title} »…';
      try {
        final analysis = await analyzePdf(bytes);
        files[d.id] = (
          bytes: bytes,
          contentHash: analysis.contentHash,
          fingerprints: analysis.fingerprints,
        );
      } catch (_) {
        failed.add(d.title);
      }
    }
    status.value = 'Enregistrement…';
    trees = await store.importPack(archive, files: files, mode: mode);
  } catch (e) {
    navigator.pop();
    status.dispose();
    if (context.mounted) _notify(context, 'Import impossible : $e');
    return;
  }
  navigator.pop();
  status.dispose();
  if (!context.mounted) return;
  final updated = {for (final n in preview.existing) n.id};
  final allUpdated = trees.every((t) => updated.contains(t.id));
  _notify(
    context,
    [
      trees.length > 3
          ? '${trees.length} arbres ${allUpdated ? 'mis à jour' : 'importés'}.'
          : '${trees.map((t) => '« ${t.title} »').join(', ')} '
                '${allUpdated ? 'mis à jour' : (trees.length > 1 ? 'ajoutés' : 'ajouté')}.',
      if (failed.isNotEmpty)
        'PDF non récupéré(s) : ${failed.join(', ')}. Importez le fichier '
            'depuis la Bibliothèque : il sera rattaché aux recto et verso.',
    ].join(' '),
  );
}

Future<Uint8List?> _download(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 2));
    return response.statusCode == 200 ? response.bodyBytes : null;
  } catch (_) {
    return null;
  }
}

/// Confirmation de l'import d'un paquet. Si l'un de ses arbres est déjà
/// présent et que le paquet n'en contient pas tout, propose de remplacer
/// l'arbre local ou de combiner les deux. Renvoie le mode choisi, `null` si
/// annulé.
class PackImportDialog extends StatelessWidget {
  const PackImportDialog({
    super.key,
    required this.archive,
    required this.preview,
    this.details = const [],
  });

  final VergerArchive archive;
  final PackImportPreview preview;

  /// Lignes ajoutées au résumé (PDF inclus, à télécharger…).
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = preview;
    final treeCount = archive.nodes.where((n) => n.parentId == null).length;
    final names = p.existing.map((n) => '« ${n.title} »').join(', ');
    final lost = [
      if (p.branches > 0) '${p.branches} branche(s)',
      if (p.items > 0)
        '${p.items} connaissance(s)'
            '${p.reviews > 0 ? ' et ${p.reviews} révision(s)' : ''}',
      if (p.notes > 0) '${p.notes} note(s)',
      if (p.anchors > 0) '${p.anchors} recto/verso',
    ];
    return AlertDialog(
      title: Text('Importer « ${archive.title ?? 'paquet'} » ?'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                '${archive.items.length} connaissance(s), '
                    '${archive.documents.length} contenu(s), '
                    '${archive.anchors.length} recto/verso, '
                    '${archive.notes.length} note(s).',
                ...details,
                if (!p.updatesExisting)
                  treeCount > 1
                      ? 'Les $treeCount arbres s\'ajoutent à côté des vôtres, '
                            'sans progression.'
                      : 'L\'arbre s\'ajoute à côté des vôtres, sans '
                            'progression.'
                else
                  '$names ${p.existing.length > 1 ? 'sont' : 'est'} déjà dans '
                      'votre verger : mis à jour sans doublon, la progression '
                      'des connaissances communes est conservée.',
              ].join('\n'),
            ),
            if (p.wouldLose) ...[
              const SizedBox(height: 12),
              Text(
                'Le paquet ne contient pas tout ce que vous avez : '
                '${lost.join(', ')}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Remplacer : l\'arbre devient celui du paquet, ces éléments '
                'sont supprimés définitivement.\n'
                '• Combiner : le paquet met à jour l\'arbre, ces éléments '
                'sont conservés.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        if (p.wouldLose) ...[
          OutlinedButton(
            onPressed: () => Navigator.pop(context, PackImportMode.replace),
            child: const Text('Remplacer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, PackImportMode.combine),
            child: const Text('Combiner'),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context, PackImportMode.replace),
            child: Text(p.updatesExisting ? 'Mettre à jour' : 'Importer'),
          ),
      ],
    );
  }
}
