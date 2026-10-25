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

/// Choisit un fichier PDF ; renvoie son nom (sans extension) et son contenu.
Future<(String, Uint8List)?> pickPdfFile() async {
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

/// Ajoute à la bibliothèque le PDF [bytes] sous le titre [title], rattaché à
/// [nodeId] s'il est donné. Un PDF identique déjà présent est réutilisé
/// (et son fichier joint s'il ne le connaissait que par ses empreintes).
Future<SourceDocument?> savePdf(
  BuildContext context, {
  required Uint8List bytes,
  required String title,
  String? nodeId,
}) async {
  final store = AppScope.of(context).store;
  final analysis = await _analyzeWithProgress(context, bytes);
  if (analysis == null || !context.mounted) return null;
  final existing = (await store.allDocuments())
      .where((d) => d.contentHash == analysis.contentHash)
      .firstOrNull;
  if (existing != null) {
    if (nodeId != null) await store.linkResource(existing.id, nodeId);
    // Connu par ses empreintes seulement (paquet sans le PDF) : le fichier
    // est joint.
    final attached = await store.attachDocumentFile(existing.id, bytes);
    if (context.mounted) {
      _notify(
        context,
        attached
            ? 'Fichier de « ${existing.title} » ajouté à la bibliothèque.'
            : 'Ce PDF est déjà dans la bibliothèque : « ${existing.title} »'
                  '${nodeId != null ? ', rattaché ici' : ''}.',
      );
    }
    return existing;
  }
  final document = await store.importDocument(
    title: title,
    bytes: bytes,
    contentHash: analysis.contentHash,
    fingerprints: analysis.fingerprints,
    nodeIds: [?nodeId],
  );
  if (context.mounted) {
    _notify(
      context,
      '« ${document.title} » importé (${document.pageCount} pages).',
    );
  }
  return document;
}

/// Ajoute la vidéo YouTube [videoId], rattachée à [nodeId] s'il est donné,
/// puis l'ouvre pour en marquer les extraits.
Future<SourceDocument?> saveYoutubeVideo(
  BuildContext context, {
  required String videoId,
  required String title,
  String? nodeId,
}) async {
  final store = AppScope.of(context).store;
  final existing = (await store.allDocuments())
      .where((d) => d.isVideo && d.contentHash == videoId)
      .firstOrNull;
  if (existing != null) {
    if (nodeId != null) await store.linkResource(existing.id, nodeId);
    if (context.mounted) {
      _notify(context, 'Cette vidéo est déjà dans la bibliothèque.');
      await openResource(context, existing);
    }
    return existing;
  }
  final video = await store.addVideo(
    title: title,
    url: youtubeUrl(videoId),
    videoId: videoId,
    nodeIds: [?nodeId],
  );
  // La vidéo s'ouvre aussitôt, pour en marquer les extraits.
  if (context.mounted) await openResource(context, video);
  return video;
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
  final picked = await pickPdfFile();
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
