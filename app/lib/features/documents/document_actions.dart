import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../pdf/pdf_tools.dart';
import 'document_viewer_page.dart';

extension DocumentRoleLabel on DocumentRole {
  String get label => switch (this) {
    DocumentRole.course => 'Cours',
    DocumentRole.notes => 'Notes',
  };

  String get hint => switch (this) {
    DocumentRole.course => 'PDF d\'où viennent les énoncés (recto)',
    DocumentRole.notes => 'Notes manuscrites exportées, ex. CollaNote (verso)',
  };
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Choisit un PDF ; renvoie son nom (sans extension) et son contenu.
Future<(String, Uint8List)?> _pickPdf() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Choisir un PDF',
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (file == null) return null;
  final name = file.name.replaceFirst(
    RegExp(r'\.pdf$', caseSensitive: false),
    '',
  );
  return (name, await file.xFile.readAsBytes());
}

/// Analyse le PDF en affichant la progression.
Future<PdfAnalysis?> _analyzeWithProgress(
  BuildContext context,
  Uint8List bytes,
) async {
  final progress = ValueNotifier<double?>(null);
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Analyse du PDF…'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, value, _) => LinearProgressIndicator(value: value),
        ),
      ),
    ),
  );
  try {
    return await analyzePdf(
      bytes,
      onProgress: (done, total) => progress.value = done / total,
    );
  } catch (e) {
    if (context.mounted) _notify(context, 'PDF illisible : $e');
    return null;
  } finally {
    navigator.pop();
    progress.dispose();
  }
}

/// Importe un PDF dans la bibliothèque.
Future<SourceDocument?> importPdf(
  BuildContext context, {
  DocumentRole? role,
}) async {
  final store = AppScope.of(context).store;
  final picked = await _pickPdf();
  if (picked == null || !context.mounted) return null;
  final (name, bytes) = picked;

  final choice = await showDialog<(String, DocumentRole)>(
    context: context,
    builder: (_) => _ImportDialog(initialTitle: name, initialRole: role),
  );
  if (choice == null || !context.mounted) return null;

  final analysis = await _analyzeWithProgress(context, bytes);
  if (analysis == null || !context.mounted) return null;
  final existing = (await store.allDocuments())
      .where((d) => d.contentHash == analysis.contentHash)
      .firstOrNull;
  if (existing != null) {
    if (context.mounted) {
      _notify(
        context,
        'Ce PDF est déjà dans la bibliothèque : « ${existing.title} ».',
      );
    }
    return existing;
  }
  final document = await store.importDocument(
    title: choice.$1,
    role: choice.$2,
    bytes: bytes,
    contentHash: analysis.contentHash,
    fingerprints: analysis.fingerprints,
  );
  if (context.mounted) {
    _notify(
      context,
      '« ${document.title} » importé (${document.pageCount} pages).',
    );
  }
  return document;
}

/// Remplace le PDF par une nouvelle version et recale les ancres.
Future<void> updatePdf(BuildContext context, SourceDocument document) async {
  final store = AppScope.of(context).store;
  final picked = await _pickPdf();
  if (picked == null || !context.mounted) return;
  final (_, bytes) = picked;
  final analysis = await _analyzeWithProgress(context, bytes);
  if (analysis == null || !context.mounted) return;
  final hasFile = await store.documentBytes(document.id) != null;
  if (!context.mounted) return;
  if (analysis.contentHash == document.contentHash && hasFile) {
    _notify(context, 'C\'est déjà la version enregistrée.');
    return;
  }
  final DocumentUpdate result = await store.updateDocument(
    document.id,
    bytes: bytes,
    contentHash: analysis.contentHash,
    fingerprints: analysis.fingerprints,
  );
  if (!context.mounted) return;
  final lines = [
    '${analysis.pageCount} pages (version ${document.version + 1}).',
    if (result.newPages.isNotEmpty)
      result.newPages.length == 1
          ? '1 nouvelle page : p. ${result.newPages.single}.'
          : '${result.newPages.length} nouvelles pages.',
    if (result.moved > 0)
      '${result.moved} lien(s) recalé(s) sur une autre page.',
    if (result.flagged > 0)
      '${result.flagged} lien(s) à vérifier : page introuvable dans la nouvelle version '
          '(la miniature reste visible).',
  ];
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('« ${document.title} » mis à jour'),
      content: Text(lines.join('\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fermer'),
        ),
        if (result.newPages.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Voir les nouvelles pages'),
          ),
      ],
    ),
  );
  if (open == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerPage(
          documentId: document.id,
          initialPage: result.newPages.first,
        ),
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.initialTitle, this.initialRole});

  final String initialTitle;
  final DocumentRole? initialRole;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late DocumentRole _role = widget.initialRole ?? DocumentRole.course;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importer un PDF'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DocumentRole>(
              segments: [
                for (final role in DocumentRole.values)
                  ButtonSegment(value: role, label: Text(role.label)),
              ],
              selected: {_role},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _role.hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isNotEmpty) Navigator.pop(context, (title, _role));
          },
          child: const Text('Importer'),
        ),
      ],
    );
  }
}
