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
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Importer « ${archive.title ?? 'paquet'} » ?'),
      content: Text(
        [
          '${archive.items.length} connaissance(s), '
              '${archive.documents.length} contenu(s), '
              '${archive.anchors.length} recto/verso, '
              '${archive.notes.length} note(s).',
          if (included.isNotEmpty) '${included.length} PDF inclus.',
          if (toFetch.isNotEmpty)
            '${toFetch.length} PDF à télécharger : '
                '${toFetch.map((d) => d.title).join(', ')}.',
          'L\'arbre s\'ajoute à côté des vôtres, sans progression.',
        ].join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Importer'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

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
    trees = await store.importPack(archive, files: files);
  } catch (e) {
    navigator.pop();
    status.dispose();
    if (context.mounted) _notify(context, 'Import impossible : $e');
    return;
  }
  navigator.pop();
  status.dispose();
  if (!context.mounted) return;
  _notify(
    context,
    [
      '${trees.map((t) => '« ${t.title} »').join(', ')} ajouté.',
      if (failed.isNotEmpty)
        'PDF non récupéré(s) : ${failed.join(', ')} (miniatures conservées ; '
            'importez-les depuis la Bibliothèque).',
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
