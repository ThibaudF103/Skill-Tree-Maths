import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../pdf/pdf_tools.dart';
import '../../video/youtube.dart';
import '../trees/node_picker.dart';
import '../video/video_page.dart';
import 'document_viewer_page.dart';

/// Icône d'un contenu selon sa nature.
IconData resourceIcon(SourceDocument document) => switch (document.kind) {
  ResourceKind.pdf => Icons.picture_as_pdf_outlined,
  ResourceKind.video => Icons.smart_display_outlined,
};

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

/// Importe un PDF dans la bibliothèque, rattaché à [nodeId] s'il est donné
/// (sinon, au choix dans le formulaire).
Future<SourceDocument?> importPdf(
  BuildContext context, {
  String? nodeId,
}) async {
  final store = AppScope.of(context).store;
  final picked = await _pickPdf();
  if (picked == null || !context.mounted) return null;
  final (name, bytes) = picked;

  final choice = await showDialog<(String, String?)>(
    context: context,
    builder: (_) => _ImportDialog(initialTitle: name, nodeId: nodeId),
  );
  if (choice == null || !context.mounted) return null;
  final (title, targetNode) = choice;

  final analysis = await _analyzeWithProgress(context, bytes);
  if (analysis == null || !context.mounted) return null;
  final existing = (await store.allDocuments())
      .where((d) => d.contentHash == analysis.contentHash)
      .firstOrNull;
  if (existing != null) {
    if (targetNode != null) await store.linkResource(existing.id, targetNode);
    // Connu par ses empreintes seulement (paquet sans le PDF) : le fichier
    // est joint.
    final attached = await store.attachDocumentFile(existing.id, bytes);
    if (context.mounted) {
      _notify(
        context,
        attached
            ? 'Fichier de « ${existing.title} » ajouté à la bibliothèque.'
            : 'Ce PDF est déjà dans la bibliothèque : « ${existing.title} »'
                  '${targetNode != null ? ', rattaché ici' : ''}.',
      );
    }
    return existing;
  }
  final document = await store.importDocument(
    title: title,
    bytes: bytes,
    contentHash: analysis.contentHash,
    fingerprints: analysis.fingerprints,
    nodeIds: [?targetNode],
  );
  if (context.mounted) {
    _notify(
      context,
      '« ${document.title} » importé (${document.pageCount} pages).',
    );
  }
  return document;
}

/// Ajoute une vidéo YouTube (adresse collée), rattachée à [nodeId].
Future<SourceDocument?> addYoutubeVideo(
  BuildContext context, {
  String? nodeId,
}) async {
  final store = AppScope.of(context).store;
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => const _VideoDialog(),
  );
  if (result == null || !context.mounted) return null;
  final (id, title) = result;
  final existing = (await store.allDocuments())
      .where((d) => d.isVideo && d.contentHash == id)
      .firstOrNull;
  if (existing != null) {
    if (nodeId != null) await store.linkResource(existing.id, nodeId);
    if (context.mounted) {
      _notify(context, 'Cette vidéo est déjà dans la bibliothèque.');
    }
    return existing;
  }
  final video = await store.addVideo(
    title: title,
    url: youtubeUrl(id),
    videoId: id,
    nodeIds: [?nodeId],
  );
  if (context.mounted) _notify(context, '« ${video.title} » ajoutée.');
  return video;
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog();

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  String? _id;
  var _fetching = false;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _onUrl(String text) async {
    final id = youtubeId(text);
    setState(() => _id = id);
    if (id == null || _title.text.isNotEmpty) return;
    setState(() => _fetching = true);
    final title = await youtubeTitle(id);
    if (!mounted || _id != id) return;
    setState(() {
      _fetching = false;
      if (title != null && _title.text.isEmpty) _title.text = title;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    return AlertDialog(
      title: const Text('Ajouter une vidéo YouTube'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Adresse de la vidéo',
                hintText: 'https://www.youtube.com/watch?v=…',
                border: const OutlineInputBorder(),
                errorText: _url.text.isNotEmpty && id == null
                    ? 'Adresse YouTube non reconnue'
                    : null,
              ),
              onChanged: _onUrl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'Titre',
                border: const OutlineInputBorder(),
                suffixIcon: _fetching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
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
        ListenableBuilder(
          listenable: _title,
          builder: (context, _) => FilledButton(
            onPressed: id == null
                ? null
                : () => Navigator.pop(context, (
                    id,
                    _title.text.trim().isEmpty
                        ? 'Vidéo $id'
                        : _title.text.trim(),
                  )),
            child: const Text('Ajouter'),
          ),
        ),
      ],
    );
  }
}

/// Rattache [document] à une branche choisie dans l'arbre.
Future<void> linkResourceToNode(
  BuildContext context,
  SourceDocument document,
) async {
  final store = AppScope.of(context).store;
  final node = await pickNode(
    context,
    title: 'Rattacher « ${document.title} » à…',
  );
  if (node == null) return;
  await store.linkResource(document.id, node.id);
  if (context.mounted) {
    _notify(context, '« ${document.title} » rattaché à « ${node.title} ».');
  }
}

/// Choisit un contenu de la bibliothèque (sauf [exclude]).
Future<SourceDocument?> pickResource(
  BuildContext context, {
  required String title,
  Set<String> exclude = const {},
}) async {
  final store = AppScope.of(context).store;
  final documents = [
    for (final d in await store.allDocuments())
      if (!exclude.contains(d.id)) d,
  ];
  if (!context.mounted) return null;
  return showDialog<SourceDocument>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        if (documents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('La bibliothèque est vide.'),
          ),
        for (final d in documents)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, d),
            child: Row(
              children: [
                Icon(resourceIcon(d)),
                const SizedBox(width: 12),
                Expanded(child: Text(d.title)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Ouvre un contenu : visionneuse pour un PDF, navigateur pour une vidéo.
Future<void> openResource(BuildContext context, SourceDocument document) async {
  if (document.isVideo) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPage(documentId: document.id),
      ),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentViewerPage(documentId: document.id),
    ),
  );
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
  const _ImportDialog({required this.initialTitle, this.nodeId});

  final String initialTitle;
  final String? nodeId;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late String? _nodeId = widget.nodeId;
  String? _nodePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nodeId != null && _nodePath == null) _loadPath();
  }

  Future<void> _loadPath() async {
    final nodes = await AppScope.of(context).store.allNodes();
    if (!mounted) return;
    setState(
      () => _nodePath = nodePath({for (final n in nodes) n.id: n}, _nodeId!),
    );
  }

  Future<void> _chooseNode() async {
    final node = await pickNode(
      context,
      title: 'Rattacher à…',
      initialId: _nodeId,
    );
    if (node == null || !mounted) return;
    _nodeId = node.id;
    await _loadPath();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Rattaché à'),
              subtitle: Text(
                _nodeId == null
                    ? 'Aucune branche (bibliothèque seulement)'
                    : _nodePath ?? '…',
              ),
              trailing: TextButton(
                onPressed: _chooseNode,
                child: Text(_nodeId == null ? 'Choisir' : 'Changer'),
              ),
            ),
            Text(
              'Un même contenu peut servir à plusieurs branches.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
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
            if (title.isNotEmpty) Navigator.pop(context, (title, _nodeId));
          },
          child: const Text('Importer'),
        ),
      ],
    );
  }
}
